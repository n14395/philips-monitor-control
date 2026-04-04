"""Philips MultiView DDC/CI core logic.

Shared constants and DDCUtil wrapper used by CLI, GTK, and other frontends.
Reverse-engineered from Philips SmartControl 7.0.0 .NET assemblies.
"""

import re
import shutil
import subprocess
import sys
import time

# --- VCP Code Constants ---
VCP_WINDOW_SELECT = 0xA5
VCP_SIZE_LOCATION = 0xEC
VCP_INPUT_SOURCE = 0x60
VCP_WINDOW_MASK = 0xA4
VCP_SWAP = 0xF6
VCP_SUPPORT_TYPE = 0xF7

# --- Mode values for VCP 0xA5 ---
MODES = {
    "off":  0x0000,
    "pip":  0x0100,
    "pbp1": 0x0200,
    "pbp2": 0x0400,
    "pbp3": 0x0800,
}
MODE_NAMES = {v: k for k, v in MODES.items()}
MODE_LABELS = {
    "off": "Off", "pip": "PIP", "pbp1": "PBP 1 (L/R)",
    "pbp2": "PBP 2", "pbp3": "PBP 3",
}

# --- PIP Size values (low byte of VCP 0xEC) ---
SIZES = {"small": 1, "medium": 2, "large": 3}
SIZE_NAMES = {v: k for k, v in SIZES.items()}
SIZE_LABELS = {"small": "Small", "medium": "Medium", "large": "Large"}

# --- PIP Location values (high byte of VCP 0xEC) ---
LOCATIONS = {
    "upper-right": 1, "lower-right": 2, "upper-left": 3, "lower-left": 4,
}
LOCATION_NAMES = {1: "upper-right", 2: "lower-right", 3: "upper-left", 4: "lower-left"}
LOCATION_LABELS = {
    "upper-right": "Upper Right", "lower-right": "Lower Right",
    "upper-left": "Upper Left", "lower-left": "Lower Left",
}

# --- Input source values ---
MAIN_SOURCES = {
    "vga1": 0x01, "dsub": 0x02, "dvi": 0x03,
    "dp1": 0x0F, "dp2": 0x10,
    "hdmi1": 0x11, "hdmi2": 0x12, "hdmi3": 0x13,
    "usbc1": 0x15, "usbc2": 0x16,
}
MAIN_SOURCE_NAMES = {v: k for k, v in MAIN_SOURCES.items()}

SECONDARY_SOURCES = {
    "hdmi1": 0x21, "hdmi2": 0x22, "hdmi3": 0x23,
    "dvi": 0x24,
    "dp1": 0x2F, "dp2": 0x30,
    "vga1": 0x31, "vga2": 0x32,
    "usbc1": 0x35, "usbc2": 0x36,
}
SECONDARY_SOURCE_NAMES = {v: k for k, v in SECONDARY_SOURCES.items()}

SOURCE_LABELS = {
    "vga1": "VGA 1", "vga2": "VGA 2", "dsub": "D-Sub", "dvi": "DVI",
    "dp1": "DisplayPort 1", "dp2": "DisplayPort 2",
    "hdmi1": "HDMI 1", "hdmi2": "HDMI 2", "hdmi3": "HDMI 3",
    "usbc1": "USB-C 1", "usbc2": "USB-C 2",
}

SUPPORT_TYPES = {
    2:  "PBP_1 only",
    3:  "PBP_1 + PBP_2",
    4:  "PBP_1 + PBP_2 + PBP_3",
    64: "PIP only",
    66: "PIP + PBP_1",
    67: "PIP + PBP_1 + PBP_2",
    68: "PIP + PBP_1 + PBP_2 + PBP_3",
}

SLEEP_MS = 150

# --- Additional VCP Code Constants ---
VCP_FACTORY_RESET = 0x04
VCP_BRIGHTNESS = 0x10
VCP_CONTRAST = 0x12
VCP_COLOR_TEMP = 0x14
VCP_RED_GAIN = 0x16
VCP_GREEN_GAIN = 0x18
VCP_BLUE_GAIN = 0x1A
VCP_AUTO_SETUP = 0x1E
VCP_VOLUME = 0x62
VCP_GAMMA = 0x72
VCP_SCALING = 0x86
VCP_AUDIO_MUTE = 0x8D
VCP_USAGE_TIME = 0xC0
VCP_FIRMWARE = 0xC9
VCP_OSD_LANGUAGE = 0xCC
VCP_POWER_MODE = 0xD6
VCP_SMARTIMAGE = 0xDC
VCP_RESOLUTION_NOTIF = 0xE9
VCP_INPUT_AUTO = 0xED
VCP_POWER_LED = 0xF2

# --- Settings Registry ---
# Each setting: vcp, type (continuous|enum), and type-specific metadata.

SETTINGS = {
    "brightness": {
        "vcp": VCP_BRIGHTNESS, "type": "continuous",
        "min": 0, "max": 100, "label": "Brightness", "unit": "%",
    },
    "contrast": {
        "vcp": VCP_CONTRAST, "type": "continuous",
        "min": 0, "max": 100, "label": "Contrast", "unit": "%",
    },
    "volume": {
        "vcp": VCP_VOLUME, "type": "continuous",
        "min": 0, "max": 100, "label": "Volume", "unit": "%",
    },
    "red-gain": {
        "vcp": VCP_RED_GAIN, "type": "continuous",
        "min": 0, "max": 100, "label": "Red Gain", "unit": "%",
    },
    "green-gain": {
        "vcp": VCP_GREEN_GAIN, "type": "continuous",
        "min": 0, "max": 100, "label": "Green Gain", "unit": "%",
    },
    "blue-gain": {
        "vcp": VCP_BLUE_GAIN, "type": "continuous",
        "min": 0, "max": 100, "label": "Blue Gain", "unit": "%",
    },
    "power-led": {
        "vcp": VCP_POWER_LED, "type": "continuous",
        "min": 0, "max": 4, "label": "Power LED", "unit": "",
    },
    "color-temp": {
        "vcp": VCP_COLOR_TEMP, "type": "enum", "label": "Color Temp",
        "values": {
            "srgb": 1, "native": 2, "5000k": 4, "6500k": 5,
            "7500k": 6, "8200k": 7, "9300k": 8, "11500k": 10, "user": 11,
        },
    },
    "gamma": {
        "vcp": VCP_GAMMA, "type": "enum", "label": "Gamma",
        "values": {"1.8": 80, "2.0": 100, "2.2": 120, "2.4": 140, "2.6": 160},
    },
    "smartimage": {
        "vcp": VCP_SMARTIMAGE, "type": "enum", "label": "SmartImage",
        "values": {
            "off": 0, "office": 1, "photo": 2, "movie": 3,
            "game": 5, "economy": 8, "lowblue": 11, "easyread": 14,
            "smartuniformity": 31, "dmode": 80,
        },
    },
    "mute": {
        "vcp": VCP_AUDIO_MUTE, "type": "enum", "label": "Audio Mute",
        "values": {"on": 1, "off": 2},
    },
    "power": {
        "vcp": VCP_POWER_MODE, "type": "enum", "label": "Power Mode",
        "values": {"on": 1, "standby": 2, "suspend": 3, "sleep": 4, "off": 5},
    },
    "scaling": {
        "vcp": VCP_SCALING, "type": "enum", "label": "Display Scaling",
        "values": {"1:1": 1, "wide": 2, "4:3": 5, "movie1": 33, "movie2": 34},
    },
    "language": {
        "vcp": VCP_OSD_LANGUAGE, "type": "enum", "label": "OSD Language",
        "values": {
            "chinese-traditional": 1, "english": 2, "french": 3, "german": 4,
            "italian": 5, "japanese": 6, "korean": 7, "portuguese": 8,
            "russian": 9, "spanish": 10, "swedish": 11, "turkish": 12,
            "chinese-simplified": 13, "portuguese-br": 14, "arabic": 15,
            "bulgarian": 16, "croatian": 17, "czech": 18, "danish": 19,
            "dutch": 20, "estonian": 21, "finnish": 22, "greek": 23,
            "hebrew": 24, "hindi": 25, "hungarian": 26, "latvian": 27,
            "lithuanian": 28, "norwegian": 29, "polish": 30, "romanian": 31,
            "serbian": 32, "slovak": 33, "slovenian": 34, "thai": 35,
            "ukrainian": 36, "vietnamese": 37, "indonesian": 239,
        },
    },
    "resolution-notifier": {
        "vcp": VCP_RESOLUTION_NOTIF, "type": "enum", "label": "Resolution Notifier",
        "values": {"off": 0, "on": 2},
    },
    "input-auto": {
        "vcp": VCP_INPUT_AUTO, "type": "enum", "label": "Input Auto",
        "values": {"off": 0, "on": 1},
    },
}

# Reverse-lookup: value -> name for each enum setting
SETTING_VALUE_NAMES = {}
for _name, _spec in SETTINGS.items():
    if _spec["type"] == "enum":
        SETTING_VALUE_NAMES[_name] = {v: k for k, v in _spec["values"].items()}

ACTIONS = {
    "factory-reset": {
        "vcp": VCP_FACTORY_RESET, "trigger_value": 1,
        "label": "Factory Reset", "confirm": True,
    },
    "auto-setup": {
        "vcp": VCP_AUTO_SETUP, "trigger_value": 1,
        "label": "Auto Setup (VGA)", "confirm": False,
    },
}

READONLY_INFO = {
    "usage-time": {"vcp": VCP_USAGE_TIME, "label": "Display Usage Time"},
    "firmware": {"vcp": VCP_FIRMWARE, "label": "Firmware Version"},
}

# Settings included in the quick status display
STATUS_SETTINGS = ["brightness", "contrast", "volume", "color-temp", "smartimage", "mute", "power-led"]


class DDCUtil:
    """Wrapper around ddcutil for reading/writing VCP codes."""

    def __init__(self, bus=None, display=None, verbose=False, dry_run=False):
        self.bus = bus
        self.display = display
        self.verbose = verbose
        self.dry_run = dry_run
        self.last_error = None

    def _base_args(self):
        args = ["ddcutil"]
        if self.bus is not None:
            args += ["--bus", str(self.bus)]
        elif self.display is not None:
            args += ["--display", str(self.display)]
        return args

    def getvcp_raw(self, code):
        """Read a VCP code and return (mh, ml, sh, sl) or None."""
        self.last_error = None
        args = self._base_args() + ["getvcp", f"0x{code:02x}", "--verbose"]
        if self.verbose:
            print(f"  > {' '.join(args)}", file=sys.stderr)
        if self.dry_run:
            return None

        result = subprocess.run(args, capture_output=True, text=True)
        if result.returncode != 0:
            self.last_error = result.stderr.strip()
            return None

        output = result.stdout + result.stderr
        match = re.search(
            r"mh=0x([0-9a-fA-F]{2}),\s*ml=0x([0-9a-fA-F]{2}),\s*"
            r"sh=0x([0-9a-fA-F]{2}),\s*sl=0x([0-9a-fA-F]{2})",
            output,
        )
        if match:
            return tuple(int(match.group(i), 16) for i in range(1, 5))

        match = re.search(r"current value\s*=\s*(\d+),\s*max value\s*=\s*(\d+)", output)
        if match:
            cur, mx = int(match.group(1)), int(match.group(2))
            return ((mx >> 8) & 0xFF, mx & 0xFF, (cur >> 8) & 0xFF, cur & 0xFF)

        self.last_error = f"Could not parse getvcp 0x{code:02x} output"
        return None

    def getvcp_value(self, code):
        """Read a VCP code and return the 16-bit current value."""
        raw = self.getvcp_raw(code)
        if raw is None:
            return None
        mh, ml, sh, sl = raw
        return (sh << 8) | sl

    def setvcp(self, code, value):
        """Write a VCP code. Returns True on success."""
        self.last_error = None
        args = self._base_args() + ["setvcp", f"0x{code:02x}", f"0x{value:04x}", "--noverify"]
        if self.verbose:
            print(f"  > {' '.join(args)}", file=sys.stderr)
        if self.dry_run:
            return True

        result = subprocess.run(args, capture_output=True, text=True)
        if result.returncode != 0:
            self.last_error = result.stderr.strip()
            return False
        return True

    def sleep(self):
        time.sleep(SLEEP_MS / 1000.0)

    @staticmethod
    def available():
        return shutil.which("ddcutil") is not None


class MultiViewController:
    """High-level monitor control operations."""

    def __init__(self, ddc):
        self.ddc = ddc

    def get_status(self):
        """Return dict with current mode, size, location, main_source, secondary_source, support."""
        status = {}

        mode_val = self.ddc.getvcp_value(VCP_WINDOW_SELECT)
        status["mode_val"] = mode_val
        status["mode"] = MODE_NAMES.get(mode_val, "unknown") if mode_val is not None else None

        raw = self.ddc.getvcp_raw(VCP_SIZE_LOCATION)
        if raw:
            mh, ml, sh, sl = raw
            status["size"] = SIZE_NAMES.get(sl, "unknown")
            status["size_val"] = sl
            status["location"] = LOCATION_NAMES.get(sh, "unknown")
            status["location_val"] = sh
        else:
            status["size"] = status["location"] = None
            status["size_val"] = status["location_val"] = 0

        raw = self.ddc.getvcp_raw(VCP_INPUT_SOURCE)
        if raw:
            mh, ml, sh, sl = raw
            status["main_source"] = MAIN_SOURCE_NAMES.get(sl, f"0x{sl:02x}")
            status["main_source_val"] = sl
            status["secondary_source"] = SECONDARY_SOURCE_NAMES.get(sh, f"0x{sh:02x}")
            status["secondary_source_val"] = sh
        else:
            status["main_source"] = status["secondary_source"] = None
            status["main_source_val"] = status["secondary_source_val"] = 0

        support_val = self.ddc.getvcp_value(VCP_SUPPORT_TYPE)
        if support_val is not None:
            sl = support_val & 0xFF
            status["support_type"] = sl
            status["support_desc"] = SUPPORT_TYPES.get(sl, f"unknown ({sl})")
        else:
            status["support_type"] = None
            status["support_desc"] = None

        return status

    def set_mode_off(self):
        """Turn off MultiView."""
        self.ddc.setvcp(VCP_WINDOW_SELECT, MODES["off"])
        self.ddc.sleep()
        cur_ec = self.ddc.getvcp_value(VCP_SIZE_LOCATION)
        if cur_ec is not None:
            self.ddc.setvcp(VCP_SIZE_LOCATION, cur_ec)
            self.ddc.sleep()
        cur_60 = self.ddc.getvcp_value(VCP_INPUT_SOURCE)
        if cur_60 is not None:
            self.ddc.setvcp(VCP_INPUT_SOURCE, cur_60)
            self.ddc.sleep()
        self.ddc.setvcp(VCP_WINDOW_MASK, 0xFFFF)

    def set_pip(self, secondary_source, size, location):
        """Enable PIP with full configuration."""
        size_val = SIZES[size]
        loc_val = LOCATIONS[location]
        ec_val = size_val | (loc_val << 8)

        self.ddc.setvcp(VCP_WINDOW_SELECT, MODES["pip"])
        self.ddc.sleep()
        self.ddc.setvcp(VCP_SIZE_LOCATION, ec_val)
        self.ddc.sleep()
        self._set_secondary_source(secondary_source)

    def set_pbp(self, mode_key, secondary_source=None):
        """Enable a PBP mode, optionally setting secondary source."""
        self.ddc.setvcp(VCP_WINDOW_SELECT, MODES[mode_key])
        self.ddc.sleep()
        cur_ec = self.ddc.getvcp_value(VCP_SIZE_LOCATION)
        if cur_ec is not None:
            self.ddc.setvcp(VCP_SIZE_LOCATION, cur_ec)
            self.ddc.sleep()
        if secondary_source:
            self._set_secondary_source(secondary_source)
        else:
            cur_60 = self.ddc.getvcp_value(VCP_INPUT_SOURCE)
            if cur_60 is not None:
                self.ddc.setvcp(VCP_INPUT_SOURCE, cur_60)

    def swap(self):
        return self.ddc.setvcp(VCP_SWAP, 0x0001)

    def set_main_source(self, source_name):
        main_val = MAIN_SOURCES[source_name]
        raw = self.ddc.getvcp_raw(VCP_INPUT_SOURCE)
        if raw is None:
            self.ddc.setvcp(VCP_INPUT_SOURCE, main_val)
            return
        mh, ml, sh, sl = raw
        self.ddc.setvcp(VCP_INPUT_SOURCE, main_val | (sh << 8))

    def set_secondary_source(self, source_name):
        self._set_secondary_source(source_name)

    def _set_secondary_source(self, source_name):
        sec_val = SECONDARY_SOURCES[source_name]
        raw = self.ddc.getvcp_raw(VCP_INPUT_SOURCE)
        if raw is None:
            self.ddc.setvcp(VCP_INPUT_SOURCE, sec_val << 8)
            return
        mh, ml, sh, sl = raw
        self.ddc.setvcp(VCP_INPUT_SOURCE, sl | (sec_val << 8))

    # --- Generic setting get/set ---

    def get_setting(self, name):
        """Read a setting by registry name.

        Returns dict with 'value', 'max', 'name' (for enums), 'label', 'raw'.
        Returns None if the setting could not be read.
        """
        spec = SETTINGS[name]
        raw = self.ddc.getvcp_raw(spec["vcp"])
        if raw is None:
            return None
        mh, ml, sh, sl = raw
        cur = (sh << 8) | sl
        mx = (mh << 8) | ml
        result = {"value": cur, "max": mx, "raw": raw, "label": spec["label"]}
        if spec["type"] == "enum":
            value_names = SETTING_VALUE_NAMES.get(name, {})
            result["name"] = value_names.get(cur, value_names.get(sl, f"0x{cur:04x}"))
            result["value"] = sl if sl in value_names else cur
        return result

    def set_setting(self, name, value):
        """Write a setting by registry name.

        For continuous: value is an int.
        For enum: value is a string name from the enum.
        Returns True on success.
        """
        spec = SETTINGS[name]
        if spec["type"] == "continuous":
            int_val = int(value)
            if not (spec["min"] <= int_val <= spec["max"]):
                raise ValueError(f"{name}: {int_val} not in range {spec['min']}-{spec['max']}")
            return self.ddc.setvcp(spec["vcp"], int_val)
        elif spec["type"] == "enum":
            str_val = str(value)
            if str_val not in spec["values"]:
                valid = ", ".join(spec["values"].keys())
                raise ValueError(f"{name}: '{str_val}' not valid. Choose from: {valid}")
            return self.ddc.setvcp(spec["vcp"], spec["values"][str_val])
        return False

    def trigger_action(self, name):
        """Execute a write-only action."""
        spec = ACTIONS[name]
        return self.ddc.setvcp(spec["vcp"], spec["trigger_value"])

    def get_info(self, name):
        """Read a read-only info register. Returns formatted string or None."""
        spec = READONLY_INFO[name]
        raw = self.ddc.getvcp_raw(spec["vcp"])
        if raw is None:
            return None
        mh, ml, sh, sl = raw
        if name == "firmware":
            return f"{sh}.{sl}"
        # Default: return the 16-bit current value
        return str((sh << 8) | sl)

    def get_extended_status(self):
        """Return get_status() dict extended with quick-read settings."""
        status = self.get_status()
        for sname in STATUS_SETTINGS:
            result = self.get_setting(sname)
            if result is not None:
                spec = SETTINGS[sname]
                if spec["type"] == "enum":
                    status[sname] = result["name"]
                else:
                    status[sname] = result["value"]
                status[f"{sname}_max"] = result["max"]
            else:
                status[sname] = None
        return status
