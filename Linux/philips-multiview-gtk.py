#!/usr/bin/env python3
"""Philips Monitor Control GTK4 GUI - All settings via DDC/CI."""

import sys
import threading

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib, Gio

from multiview_ddc import (
    DDCUtil, MultiViewController,
    MODES, MODE_LABELS,
    SIZES, SIZE_LABELS,
    LOCATIONS, LOCATION_LABELS,
    MAIN_SOURCES, SECONDARY_SOURCES, SOURCE_LABELS,
    SETTINGS, SETTING_VALUE_NAMES, READONLY_INFO,
)


class MonitorWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Philips Monitor Control")
        self.set_default_size(720, 700)

        self.ddc = DDCUtil(verbose=True)
        self.ctrl = MultiViewController(self.ddc)
        self._busy = False
        self._updating_ui = False  # prevent feedback loops on slider/combo changes

        # --- Root layout ---
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(root)

        # Header bar with view switcher
        header = Adw.HeaderBar()
        self.view_stack = Adw.ViewStack()
        switcher = Adw.ViewSwitcher(stack=self.view_stack, policy=Adw.ViewSwitcherPolicy.WIDE)
        header.set_title_widget(switcher)
        root.append(header)

        self.spinner = Gtk.Spinner()
        header.pack_end(self.spinner)
        refresh_btn = Gtk.Button(icon_name="view-refresh-symbolic", tooltip_text="Refresh")
        refresh_btn.connect("clicked", self._on_refresh)
        header.pack_end(refresh_btn)

        # Overlay container: holds view_stack + loading overlay
        self.overlay = Gtk.Overlay()
        self.overlay.set_child(self.view_stack)
        root.append(self.overlay)

        # Loading overlay (centered spinner + label, shown during refresh)
        self.loading_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12,
                                    halign=Gtk.Align.CENTER, valign=Gtk.Align.CENTER)
        self.loading_spinner = Gtk.Spinner(width_request=32, height_request=32)
        self.loading_label = Gtk.Label(label="Reading monitor settings...",
                                        css_classes=["dim-label"])
        self.loading_box.append(self.loading_spinner)
        self.loading_box.append(self.loading_label)
        self.overlay.add_overlay(self.loading_box)
        self.loading_box.set_visible(False)

        # Status bar at bottom
        self.status_bar = Gtk.Label(label="", css_classes=["dim-label"],
                                     margin_start=16, margin_end=16,
                                     margin_top=4, margin_bottom=8)
        root.append(self.status_bar)

        # --- Build pages ---
        self._build_picture_page()
        self._build_audio_page()
        self._build_input_page()
        self._build_multiview_page()
        self._build_system_page()

        # Initial load
        self._on_refresh(None)

    # ── Page builders ────────────────────────────────────────────────

    def _build_picture_page(self):
        page = self._make_scroll_page()

        grp = Adw.PreferencesGroup(title="Display")
        page.append(grp)

        self.brightness_row = self._add_slider_row(grp, "Brightness", 0, 100, "brightness")
        self.contrast_row = self._add_slider_row(grp, "Contrast", 0, 100, "contrast")

        grp2 = Adw.PreferencesGroup(title="Color")
        page.append(grp2)

        self.color_temp_row = self._add_combo_row(grp2, "Color Temperature", "color-temp", live=True)
        self.gamma_row = self._add_combo_row(grp2, "Gamma", "gamma", live=True)
        self.smartimage_row = self._add_combo_row(grp2, "SmartImage", "smartimage", live=True)
        self.scaling_row = self._add_combo_row(grp2, "Display Scaling", "scaling", live=True)

        grp3 = Adw.PreferencesGroup(title="RGB Gains")
        page.append(grp3)

        self.red_row = self._add_slider_row(grp3, "Red", 0, 100, "red-gain")
        self.green_row = self._add_slider_row(grp3, "Green", 0, 100, "green-gain")
        self.blue_row = self._add_slider_row(grp3, "Blue", 0, 100, "blue-gain")

        self.view_stack.add_titled_with_icon(
            self._wrap_in_scroll(page), "picture", "Picture", "preferences-color-symbolic")

    def _build_audio_page(self):
        page = self._make_scroll_page()

        grp = Adw.PreferencesGroup(title="Audio")
        page.append(grp)

        self.volume_row = self._add_slider_row(grp, "Volume", 0, 100, "volume")
        self.mute_row = self._add_combo_row(grp, "Mute", "mute", live=True)

        self.view_stack.add_titled_with_icon(
            self._wrap_in_scroll(page), "audio", "Audio", "audio-speakers-symbolic")

    def _build_input_page(self):
        page = self._make_scroll_page()

        grp = Adw.PreferencesGroup(title="Input Sources")
        page.append(grp)

        self.main_source_row = Adw.ComboRow(title="Main Input")
        main_list = Gtk.StringList()
        self._main_keys = list(MAIN_SOURCES.keys())
        for key in self._main_keys:
            main_list.append(SOURCE_LABELS.get(key, key))
        self.main_source_row.set_model(main_list)
        grp.add(self.main_source_row)

        self.secondary_source_row = Adw.ComboRow(title="Secondary Input")
        sec_list = Gtk.StringList()
        self._sec_keys = list(SECONDARY_SOURCES.keys())
        for key in self._sec_keys:
            sec_list.append(SOURCE_LABELS.get(key, key))
        self.secondary_source_row.set_model(sec_list)
        grp.add(self.secondary_source_row)

        self.input_auto_row = self._add_combo_row(grp, "Input Auto-Detect", "input-auto")

        grp2 = Adw.PreferencesGroup()
        page.append(grp2)
        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8,
                          halign=Gtk.Align.CENTER, margin_top=8, margin_bottom=8)
        btn_row = Adw.ActionRow()
        btn_row.set_child(btn_box)
        grp2.add(btn_row)

        apply_src_btn = Gtk.Button(label="Apply Input", css_classes=["suggested-action"])
        apply_src_btn.connect("clicked", self._on_apply_source)
        btn_box.append(apply_src_btn)

        swap_btn = Gtk.Button(label="Swap Sources")
        swap_btn.connect("clicked", self._on_swap)
        btn_box.append(swap_btn)

        self.view_stack.add_titled_with_icon(
            self._wrap_in_scroll(page), "input", "Input", "video-display-symbolic")

    def _build_multiview_page(self):
        page = self._make_scroll_page()

        # Status
        status_grp = Adw.PreferencesGroup(title="Current State")
        page.append(status_grp)
        self.lbl_mode = Adw.ActionRow(title="Mode", subtitle="--")
        self.lbl_main = Adw.ActionRow(title="Main Input", subtitle="--")
        self.lbl_secondary = Adw.ActionRow(title="Secondary Input", subtitle="--")
        self.lbl_support = Adw.ActionRow(title="Supported Modes", subtitle="--")
        for row in [self.lbl_mode, self.lbl_main, self.lbl_secondary, self.lbl_support]:
            status_grp.add(row)

        # Mode
        mode_grp = Adw.PreferencesGroup(title="MultiView Mode")
        page.append(mode_grp)

        self.mode_row = Adw.ComboRow(title="Mode")
        mode_list = Gtk.StringList()
        self._mode_keys = ["off", "pip", "pbp1", "pbp2", "pbp3"]
        for key in self._mode_keys:
            mode_list.append(MODE_LABELS[key])
        self.mode_row.set_model(mode_list)
        mode_grp.add(self.mode_row)

        # PIP settings
        pip_grp = Adw.PreferencesGroup(title="PIP Settings")
        page.append(pip_grp)

        self.size_row = Adw.ComboRow(title="Size")
        size_list = Gtk.StringList()
        self._size_keys = list(SIZES.keys())
        for key in self._size_keys:
            size_list.append(SIZE_LABELS[key])
        self.size_row.set_model(size_list)
        pip_grp.add(self.size_row)

        self.location_row = Adw.ComboRow(title="Position")
        loc_list = Gtk.StringList()
        self._loc_keys = list(LOCATIONS.keys())
        for key in self._loc_keys:
            loc_list.append(LOCATION_LABELS[key])
        self.location_row.set_model(loc_list)
        pip_grp.add(self.location_row)

        # Buttons
        btn_grp = Adw.PreferencesGroup()
        page.append(btn_grp)
        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8,
                          halign=Gtk.Align.CENTER, margin_top=8, margin_bottom=8)
        btn_row = Adw.ActionRow()
        btn_row.set_child(btn_box)
        btn_grp.add(btn_row)

        self.apply_mv_btn = Gtk.Button(label="Apply MultiView", css_classes=["suggested-action"])
        self.apply_mv_btn.connect("clicked", self._on_apply_multiview)
        btn_box.append(self.apply_mv_btn)

        self.off_btn = Gtk.Button(label="Turn Off", css_classes=["destructive-action"])
        self.off_btn.connect("clicked", self._on_off)
        btn_box.append(self.off_btn)

        self.view_stack.add_titled_with_icon(
            self._wrap_in_scroll(page), "multiview", "MultiView", "view-dual-symbolic")

    def _build_system_page(self):
        page = self._make_scroll_page()

        grp = Adw.PreferencesGroup(title="Power")
        page.append(grp)
        self.power_row = self._add_combo_row(grp, "Power Mode", "power")
        self.power_led_row = self._add_slider_row(grp, "Power LED", 0, 4)

        grp2 = Adw.PreferencesGroup(title="OSD")
        page.append(grp2)
        self.language_row = self._add_combo_row(grp2, "Language", "language")
        self.res_notif_row = self._add_combo_row(grp2, "Resolution Notifier", "resolution-notifier")

        grp3 = Adw.PreferencesGroup(title="Connection")
        page.append(grp3)
        self.bus_row = Adw.EntryRow(title="I2C Bus (blank = auto)")
        grp3.add(self.bus_row)

        grp4 = Adw.PreferencesGroup(title="Info")
        page.append(grp4)
        self.lbl_firmware = Adw.ActionRow(title="Firmware", subtitle="--")
        self.lbl_usage = Adw.ActionRow(title="Usage Time", subtitle="--")
        grp4.add(self.lbl_firmware)
        grp4.add(self.lbl_usage)

        btn_grp = Adw.PreferencesGroup()
        page.append(btn_grp)
        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8,
                          halign=Gtk.Align.CENTER, margin_top=8, margin_bottom=8)
        btn_row = Adw.ActionRow()
        btn_row.set_child(btn_box)
        btn_grp.add(btn_row)
        apply_sys_btn = Gtk.Button(label="Apply System", css_classes=["suggested-action"])
        apply_sys_btn.connect("clicked", self._on_apply_system)
        btn_box.append(apply_sys_btn)

        self.view_stack.add_titled_with_icon(
            self._wrap_in_scroll(page), "system", "System", "emblem-system-symbolic")

    # ── Widget helpers ───────────────────────────────────────────────

    def _make_scroll_page(self):
        return Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12,
                       margin_top=16, margin_bottom=16, margin_start=16, margin_end=16)

    def _wrap_in_scroll(self, content):
        scroll = Gtk.ScrolledWindow(vexpand=True)
        scroll.set_child(content)
        return scroll

    def _add_slider_row(self, group, label, min_val, max_val, setting_name=None):
        """Create an ActionRow with a Scale widget. Returns (row, scale).

        If setting_name is provided, the slider sends the value to the monitor
        immediately on change (live apply).
        """
        row = Adw.ActionRow(title=label)
        scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, min_val, max_val, 1)
        scale.set_draw_value(True)
        scale.set_hexpand(True)
        scale.set_valign(Gtk.Align.CENTER)
        scale.set_size_request(200, -1)
        if setting_name:
            scale.connect("value-changed", self._on_live_slider_changed, setting_name)
        row.add_suffix(scale)
        group.add(row)
        return (row, scale)

    def _add_combo_row(self, group, label, setting_name, live=False):
        """Create a ComboRow from a SETTINGS enum. Returns (combo_row, keys_list).

        If live=True, the combo sends the value to the monitor immediately on change.
        """
        spec = SETTINGS[setting_name]
        combo = Adw.ComboRow(title=label)
        str_list = Gtk.StringList()
        keys = list(spec["values"].keys())
        for k in keys:
            str_list.append(k.replace("-", " ").title() if len(k) > 3 else k.upper() if k.endswith("k") else k.capitalize())
        combo.set_model(str_list)
        if live:
            combo.connect("notify::selected", self._on_live_combo_changed, setting_name, keys)
        group.add(combo)
        return (combo, keys)

    # ── Async / DDC helpers ──────────────────────────────────────────

    def _get_ddc(self):
        bus_text = self.bus_row.get_text().strip()
        self.ddc.bus = int(bus_text) if bus_text.isdigit() else None
        return self.ddc

    def _set_busy(self, busy):
        self._busy = busy
        GLib.idle_add(self._update_busy_ui, busy)

    def _update_busy_ui(self, busy):
        if busy:
            self.spinner.start()
            self.loading_spinner.start()
            self.loading_box.set_visible(True)
            self.view_stack.set_sensitive(False)
        else:
            self.spinner.stop()
            self.loading_spinner.stop()
            self.loading_box.set_visible(False)
            self.view_stack.set_sensitive(True)
        return False

    def _set_status_text(self, text):
        GLib.idle_add(self.status_bar.set_label, text)

    def _set_loading_text(self, text):
        GLib.idle_add(self.loading_label.set_label, text)

    def _send_setting(self, setting_name, value):
        """Send a single setting in a background thread (no full loading overlay)."""
        if self._busy:
            return

        def worker():
            self._get_ddc()
            self.spinner.start()
            try:
                self.ctrl.set_setting(setting_name, value)
                self._set_status_text(f"{SETTINGS[setting_name]['label']}: {value}")
            except Exception as e:
                self._set_status_text(f"Error: {e}")
            finally:
                GLib.idle_add(self.spinner.stop)

        threading.Thread(target=worker, daemon=True).start()

    def _on_live_slider_changed(self, scale, setting_name):
        if self._updating_ui:
            return
        self._send_setting(setting_name, int(scale.get_value()))

    def _on_live_combo_changed(self, combo, pspec, setting_name, keys):
        if self._updating_ui:
            return
        self._send_setting(setting_name, keys[combo.get_selected()])

    def _run_async(self, func, done_msg="Done.", refresh_after=None):
        """Run func in background with loading overlay.

        refresh_after: optional callable to run after func completes
        (e.g. a targeted re-read). Runs in the same background thread.
        """
        if self._busy:
            return

        def worker():
            self._set_loading_text("Applying settings...")
            self._set_busy(True)
            self._get_ddc()
            try:
                func()
                if refresh_after:
                    self._set_loading_text("Reading back...")
                    refresh_after()
                self._set_status_text(done_msg)
            except Exception as e:
                self._set_status_text(f"Error: {e}")
            finally:
                self._set_busy(False)

        threading.Thread(target=worker, daemon=True).start()

    # ── Refresh ──────────────────────────────────────────────────────

    def _on_refresh(self, btn):
        if self._busy:
            return

        def worker():
            self._set_loading_text("Reading monitor settings...")
            self._set_busy(True)
            self._get_ddc()
            try:
                data = self._read_all()
                GLib.idle_add(self._update_all_ui, data)
                self._set_status_text("Refreshed.")
            except Exception as e:
                self._set_status_text(f"Error: {e}")
            finally:
                self._set_busy(False)

        threading.Thread(target=worker, daemon=True).start()

    def _read_all(self):
        """Read all settings from the monitor. Returns a dict."""
        data = {}
        # MultiView status
        data["mv"] = self.ctrl.get_status()
        # Settings
        for name in SETTINGS:
            data[name] = self.ctrl.get_setting(name)
        # Info
        for name in READONLY_INFO:
            data[name] = self.ctrl.get_info(name)
        return data

    def _update_all_ui(self, data):
        self._updating_ui = True
        try:
            self._update_multiview_status(data.get("mv", {}))
            self._sync_slider(self.brightness_row, data.get("brightness"))
            self._sync_slider(self.contrast_row, data.get("contrast"))
            self._sync_slider(self.volume_row, data.get("volume"))
            self._sync_slider(self.red_row, data.get("red-gain"))
            self._sync_slider(self.green_row, data.get("green-gain"))
            self._sync_slider(self.blue_row, data.get("blue-gain"))
            self._sync_slider(self.power_led_row, data.get("power-led"))
            self._sync_combo(self.color_temp_row, data.get("color-temp"))
            self._sync_combo(self.gamma_row, data.get("gamma"))
            self._sync_combo(self.smartimage_row, data.get("smartimage"))
            self._sync_combo(self.scaling_row, data.get("scaling"))
            self._sync_combo(self.mute_row, data.get("mute"))
            self._sync_combo(self.power_row, data.get("power"))
            self._sync_combo(self.language_row, data.get("language"))
            self._sync_combo(self.res_notif_row, data.get("resolution-notifier"))
            self._sync_combo(self.input_auto_row, data.get("input-auto"))
            # Info
            fw = data.get("firmware")
            self.lbl_firmware.set_subtitle(fw if fw else "--")
            usage = data.get("usage-time")
            self.lbl_usage.set_subtitle(f"{usage} hours" if usage else "--")
        finally:
            self._updating_ui = False
        return False

    def _update_multiview_status(self, mv):
        mode = mv.get("mode")
        self.lbl_mode.set_subtitle(
            MODE_LABELS.get(mode, mode or "--") +
            (f"  (0x{mv['mode_val']:04x})" if mv.get("mode_val") is not None else "")
        )
        main_src = mv.get("main_source")
        self.lbl_main.set_subtitle(SOURCE_LABELS.get(main_src, main_src or "--"))
        sec_src = mv.get("secondary_source")
        self.lbl_secondary.set_subtitle(SOURCE_LABELS.get(sec_src, sec_src or "--"))
        self.lbl_support.set_subtitle(mv.get("support_desc") or "--")

        # Sync dropdowns
        if mode in self._mode_keys:
            self.mode_row.set_selected(self._mode_keys.index(mode))
        size = mv.get("size")
        if size in self._size_keys:
            self.size_row.set_selected(self._size_keys.index(size))
        loc = mv.get("location")
        if loc in self._loc_keys:
            self.location_row.set_selected(self._loc_keys.index(loc))
        if main_src in self._main_keys:
            self.main_source_row.set_selected(self._main_keys.index(main_src))
        if sec_src in self._sec_keys:
            self.secondary_source_row.set_selected(self._sec_keys.index(sec_src))

    def _sync_slider(self, row_tuple, result):
        """Sync a slider row (row, scale) to a get_setting result."""
        row, scale = row_tuple
        if result and result.get("value") is not None:
            scale.set_value(result["value"])

    def _sync_combo(self, combo_tuple, result):
        """Sync a combo row to a get_setting result."""
        combo, keys = combo_tuple
        if result and result.get("name") is not None:
            name = result["name"]
            if name in keys:
                combo.set_selected(keys.index(name))

    # ── Actions ──────────────────────────────────────────────────────

    def _refresh_multiview_status(self):
        """Re-read just the MultiView state and update the UI."""
        mv = self.ctrl.get_status()
        GLib.idle_add(self._update_multiview_status, mv)

    def _on_apply_source(self, btn):
        main_key = self._main_keys[self.main_source_row.get_selected()]
        sec_key = self._sec_keys[self.secondary_source_row.get_selected()]
        ia_combo, ia_keys = self.input_auto_row
        ia_key = ia_keys[ia_combo.get_selected()]

        def do_apply():
            self.ctrl.set_main_source(main_key)
            self.ctrl.set_secondary_source(sec_key)
            self.ctrl.set_setting("input-auto", ia_key)

        self._run_async(do_apply, "Input sources applied.",
                        refresh_after=self._refresh_multiview_status)

    def _on_swap(self, btn):
        self._run_async(lambda: self.ctrl.swap(), "Sources swapped.",
                        refresh_after=self._refresh_multiview_status)

    def _on_apply_multiview(self, btn):
        mode_key = self._mode_keys[self.mode_row.get_selected()]
        size_key = self._size_keys[self.size_row.get_selected()]
        loc_key = self._loc_keys[self.location_row.get_selected()]
        sec_key = self._sec_keys[self.secondary_source_row.get_selected()]

        def do_apply():
            if mode_key == "off":
                self.ctrl.set_mode_off()
            elif mode_key == "pip":
                self.ctrl.set_pip(sec_key, size_key, loc_key)
            else:
                self.ctrl.set_pbp(mode_key, sec_key)

        self._run_async(do_apply, f"MultiView: {MODE_LABELS[mode_key]}",
                        refresh_after=self._refresh_multiview_status)

    def _on_off(self, btn):
        self._run_async(lambda: self.ctrl.set_mode_off(), "MultiView off.",
                        refresh_after=self._refresh_multiview_status)

    def _on_apply_system(self, btn):
        pw_combo, pw_keys = self.power_row
        _, led_scale = self.power_led_row
        lang_combo, lang_keys = self.language_row
        rn_combo, rn_keys = self.res_notif_row

        pw_key = pw_keys[pw_combo.get_selected()]
        led_val = int(led_scale.get_value())
        lang_key = lang_keys[lang_combo.get_selected()]
        rn_key = rn_keys[rn_combo.get_selected()]

        def do_apply():
            self.ctrl.set_setting("power", pw_key)
            self.ctrl.set_setting("power-led", led_val)
            self.ctrl.set_setting("language", lang_key)
            self.ctrl.set_setting("resolution-notifier", rn_key)

        self._run_async(do_apply, "System settings applied.")


class MonitorApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="com.n14395.monitorcontrol",
                         flags=Gio.ApplicationFlags.FLAGS_NONE)

    def do_activate(self):
        win = MonitorWindow(self)
        win.present()


def main():
    if not DDCUtil.available():
        print("Error: ddcutil not found. Install it with your package manager.", file=sys.stderr)
        sys.exit(1)

    app = MonitorApp()
    app.run(sys.argv)


if __name__ == "__main__":
    main()
