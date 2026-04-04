#!/usr/bin/env python3
"""Control Philips monitor settings via DDC/CI - CLI interface.

Reverse-engineered from Philips SmartControl 7.0.0 .NET assemblies.
Uses ddcutil to send VCP commands over I2C.
"""

import argparse
import sys

from multiview_ddc import (
    DDCUtil, MultiViewController,
    MODES, MODE_NAMES, SIZE_NAMES, LOCATION_NAMES,
    MAIN_SOURCE_NAMES, SECONDARY_SOURCE_NAMES, SECONDARY_SOURCES,
    SIZES, LOCATIONS, MAIN_SOURCES, SUPPORT_TYPES,
    SETTINGS, ACTIONS, READONLY_INFO, SETTING_VALUE_NAMES, STATUS_SETTINGS,
    SOURCE_LABELS, MODE_LABELS, SIZE_LABELS, LOCATION_LABELS,
)


def cmd_status(ctrl, ddc, args):
    status = ctrl.get_extended_status()

    # MultiView section
    if status["mode"] is not None:
        print(f"Mode:        {status['mode']} (0x{status['mode_val']:04x})")
    else:
        print("Mode:        (could not read)")

    if status["size"] is not None:
        print(f"PIP Size:    {status['size']}")
        print(f"PIP Loc:     {status['location']}")
    else:
        print("PIP Size:    (could not read)")
        print("PIP Loc:     (could not read)")

    if status["main_source"] is not None:
        print(f"Main input:  {status['main_source']} (0x{status['main_source_val']:02x})")
        print(f"Sub input:   {status['secondary_source']} (0x{status['secondary_source_val']:02x})")
    else:
        print("Input:       (could not read)")

    if status["support_desc"] is not None:
        print(f"Supported:   {status['support_desc']} (type {status['support_type']})")
    else:
        print("Supported:   (could not read)")

    # Settings section
    print()
    for sname in STATUS_SETTINGS:
        spec = SETTINGS[sname]
        val = status.get(sname)
        if val is None:
            print(f"{spec['label']:13s}(could not read)")
            continue
        if spec["type"] == "continuous":
            mx = status.get(f"{sname}_max", spec["max"])
            unit = spec.get("unit", "")
            print(f"{spec['label']:13s}{val}/{mx}{unit}")
        else:
            print(f"{spec['label']:13s}{val}")

    if args.full:
        print()
        # Read all remaining settings not in STATUS_SETTINGS
        for sname, spec in SETTINGS.items():
            if sname in STATUS_SETTINGS:
                continue
            result = ctrl.get_setting(sname)
            if result is None:
                print(f"{spec['label']:20s}(could not read)")
                continue
            if spec["type"] == "continuous":
                unit = spec.get("unit", "")
                print(f"{spec['label']:20s}{result['value']}/{result['max']}{unit}")
            else:
                print(f"{spec['label']:20s}{result['name']}")

        # Read-only info
        print()
        for iname, ispec in READONLY_INFO.items():
            val = ctrl.get_info(iname)
            if val is not None:
                print(f"{ispec['label']:20s}{val}")
            else:
                print(f"{ispec['label']:20s}(could not read)")


def cmd_mode(ctrl, ddc, args):
    if args.mode == "off":
        print("Setting mode to OFF...")
        ctrl.set_mode_off()
    elif args.mode == "pip":
        print("Use the 'pip' subcommand for PIP mode.")
        return
    else:
        print(f"Setting mode to {args.mode}...")
        ctrl.set_pbp(args.mode, args.source)
    print("Done.")


def cmd_pip(ctrl, ddc, args):
    print(f"Enabling PIP: source={args.source}, size={args.size}, location={args.location}")
    ctrl.set_pip(args.source, args.size, args.location)
    print("Done.")


def cmd_swap(ctrl, ddc, args):
    print("Swapping PIP/PBP sources...")
    if ctrl.swap():
        print("Done.")
    else:
        print("Swap may not be supported on this monitor.", file=sys.stderr)


def cmd_source(ctrl, ddc, args):
    if args.main:
        ctrl.set_main_source(args.main)
    if args.secondary:
        ctrl.set_secondary_source(args.secondary)
    print("Done.")


def cmd_detect(ctrl, ddc, args):
    print("Probing MultiView support...")
    status = ctrl.get_status()
    sl = status.get("support_type")
    if sl is not None:
        print(f"Support type: {status['support_desc']} (type {sl})")
        print("\nAvailable modes:")
        print("  off  - Disable MultiView")
        if sl >= 64:
            print("  pip  - Picture-in-Picture")
        if sl in (2, 3, 4, 66, 67, 68):
            print("  pbp1 - Picture-by-Picture (left/right)")
        if sl in (3, 4, 67, 68):
            print("  pbp2 - Picture-by-Picture mode 2")
        if sl in (4, 68):
            print("  pbp3 - Picture-by-Picture mode 3")
    else:
        print("Could not read VCP 0xF7 - MultiView may not be supported.", file=sys.stderr)


def cmd_get(ctrl, ddc, args):
    name = args.setting
    result = ctrl.get_setting(name)
    if result is None:
        print(f"{name}: could not read (unsupported or communication error)", file=sys.stderr)
        sys.exit(1)
    spec = SETTINGS[name]
    if spec["type"] == "continuous":
        unit = spec.get("unit", "")
        print(f"{result['label']}: {result['value']}/{result['max']}{unit}")
    else:
        print(f"{result['label']}: {result['name']} (value={result['value']})")


def cmd_set(ctrl, ddc, args):
    name = args.setting
    values = args.value

    # Special case: rgb shorthand
    if name == "rgb":
        if len(values) != 3:
            print("Usage: set rgb <red> <green> <blue> (each 0-100)", file=sys.stderr)
            sys.exit(1)
        for color_val, gain_name in zip(values, ["red-gain", "green-gain", "blue-gain"]):
            try:
                ctrl.set_setting(gain_name, int(color_val))
                print(f"  {SETTINGS[gain_name]['label']}: {color_val}")
            except ValueError as e:
                print(f"Error: {e}", file=sys.stderr)
                sys.exit(1)
        print("Done.")
        return

    if len(values) != 1:
        print(f"Expected exactly one value for '{name}'", file=sys.stderr)
        sys.exit(1)

    try:
        ctrl.set_setting(name, values[0])
        print(f"{SETTINGS[name]['label']}: set to {values[0]}")
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def cmd_factory_reset(ctrl, ddc, args):
    if not args.yes:
        answer = input("This will reset ALL monitor settings to factory defaults. Type 'yes' to confirm: ")
        if answer.strip().lower() != "yes":
            print("Aborted.")
            return
    print("Resetting to factory defaults...")
    if ctrl.trigger_action("factory-reset"):
        print("Done.")
    else:
        print("Factory reset failed.", file=sys.stderr)


def cmd_auto_setup(ctrl, ddc, args):
    print("Running auto setup (VGA)...")
    if ctrl.trigger_action("auto-setup"):
        print("Done.")
    else:
        print("Auto setup failed.", file=sys.stderr)


def cmd_info(ctrl, ddc, args):
    for iname, ispec in READONLY_INFO.items():
        val = ctrl.get_info(iname)
        if val is not None:
            print(f"{ispec['label']}: {val}")
        else:
            print(f"{ispec['label']}: (could not read)")


HELP_TEXT = """\
philips-multiview - Control Philips monitor via DDC/CI
Reverse-engineered from Philips SmartControl 7.0.0

USAGE
  philips-multiview.py [OPTIONS] COMMAND [ARGS...]

OPTIONS
  --bus, -b BUS        I2C bus number (default: auto-detect)
  --display, -d NUM    ddcutil display number
  --verbose, -v        Show raw ddcutil commands
  --dry-run, -n        Print commands without executing

COMMANDS

  Status & Info
  ─────────────────────────────────────────────────────────────────
  status               Show current monitor state (mode, inputs,
                       brightness, contrast, volume, etc.)
  status --full        Show ALL settings including color, language,
                       firmware version, and usage time
  detect               Probe which MultiView modes are supported
  info                 Show firmware version and display usage time

  Input Switching
  ─────────────────────────────────────────────────────────────────
  source --main NAME          Set the main input source
  source --secondary NAME     Set the secondary input (for PIP/PBP)

    Input names: hdmi1, hdmi2, hdmi3, dp1, dp2, dvi, vga1,
                 dsub, usbc1, usbc2

  MultiView (PIP / PBP)
  ─────────────────────────────────────────────────────────────────
  mode off                    Turn off MultiView
  mode pbp1 [--source NAME]   Side-by-side split (left/right)
  mode pbp2 [--source NAME]   PBP mode 2
  mode pbp3 [--source NAME]   PBP mode 3
  pip --source NAME --size SIZE --location LOC
                              Enable Picture-in-Picture
  swap                        Swap PIP/PBP primary and secondary

    Sizes:     small, medium, large
    Locations: upper-right, lower-right, upper-left, lower-left

  Read / Write Settings
  ─────────────────────────────────────────────────────────────────
  get SETTING                 Read current value of a setting
  set SETTING VALUE           Write a new value

    Continuous settings (numeric range):
      brightness  0-100       set brightness 75
      contrast    0-100       set contrast 50
      volume      0-100       set volume 30
      red-gain    0-100       set red-gain 80
      green-gain  0-100       set green-gain 90
      blue-gain   0-100       set blue-gain 100
      power-led   0-4         set power-led 2

    Shorthand for all three RGB gains at once:
      rgb         R G B       set rgb 80 90 100

    Enum settings (named values):
      color-temp              srgb, native, 5000k, 6500k, 7500k,
                              8200k, 9300k, 11500k, user
      gamma                   1.8, 2.0, 2.2, 2.4, 2.6
      smartimage              off, office, photo, movie, game,
                              economy, lowblue, easyread,
                              smartuniformity, dmode
      mute                    on, off
      power                   on, standby, suspend, sleep, off
      scaling                 1:1, wide, 4:3, movie1, movie2
      language                english, french, german, spanish, ...
                              (37 languages supported)
      resolution-notifier     on, off
      input-auto              on, off

  Actions
  ─────────────────────────────────────────────────────────────────
  factory-reset [--yes]       Reset ALL monitor settings to defaults
  auto-setup                  Auto-adjust VGA signal

EXAMPLES
  philips-multiview.py status
  philips-multiview.py source --main hdmi1
  philips-multiview.py pip --source dp1 --size small --location upper-right
  philips-multiview.py mode pbp1 --source hdmi2
  philips-multiview.py set brightness 75
  philips-multiview.py set color-temp 6500k
  philips-multiview.py set rgb 80 90 100
  philips-multiview.py get gamma
  philips-multiview.py set smartimage game
  philips-multiview.py set mute on
  philips-multiview.py set power standby
  philips-multiview.py info
  philips-multiview.py factory-reset --yes
  philips-multiview.py --bus 7 set volume 50
"""


def main():
    all_setting_names = list(SETTINGS.keys()) + ["rgb"]

    # Show help when run with no arguments
    if len(sys.argv) == 1:
        print(HELP_TEXT)
        sys.exit(0)

    parser = argparse.ArgumentParser(
        description="Control Philips monitor via DDC/CI (reverse-engineered from SmartControl)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=HELP_TEXT,
    )
    parser.add_argument("--bus", "-b", type=int, help="ddcutil I2C bus number")
    parser.add_argument("--display", "-d", type=int, help="ddcutil display number")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show ddcutil commands")
    parser.add_argument("--dry-run", "-n", action="store_true", help="Print commands without executing")

    sub = parser.add_subparsers(dest="command", required=True)

    status_p = sub.add_parser("status", help="Show current monitor state")
    status_p.add_argument("--full", "-f", action="store_true", help="Show all settings (slower)")

    sub.add_parser("detect", help="Detect MultiView capabilities")
    sub.add_parser("swap", help="Swap PIP/PBP input sources")
    sub.add_parser("info", help="Show firmware version and usage time")
    sub.add_parser("auto-setup", help="Auto-adjust VGA signal")

    reset_p = sub.add_parser("factory-reset", help="Reset monitor to factory defaults")
    reset_p.add_argument("--yes", "-y", action="store_true", help="Skip confirmation prompt")

    mode_p = sub.add_parser("mode", help="Set MultiView mode")
    mode_p.add_argument("mode", choices=list(MODES.keys()))
    mode_p.add_argument("--source", "-s", choices=list(SECONDARY_SOURCES.keys()),
                        help="Secondary input source (for PBP modes)")

    pip_p = sub.add_parser("pip", help="Enable PIP with full configuration")
    pip_p.add_argument("--source", "-s", required=True, choices=list(SECONDARY_SOURCES.keys()),
                       help="Secondary input source")
    pip_p.add_argument("--size", required=True, choices=list(SIZES.keys()),
                       help="PIP window size")
    pip_p.add_argument("--location", "-l", required=True,
                       choices=list(LOCATIONS.keys()),
                       help="PIP window position")

    src_p = sub.add_parser("source", help="Change input source")
    src_p.add_argument("--main", "-m", choices=list(MAIN_SOURCES.keys()),
                       help="Main input source")
    src_p.add_argument("--secondary", "-s", choices=list(SECONDARY_SOURCES.keys()),
                       help="Secondary input source (PIP/PBP)")

    get_p = sub.add_parser("get", help="Read a monitor setting")
    get_p.add_argument("setting", choices=list(SETTINGS.keys()),
                       metavar="SETTING", help=f"one of: {', '.join(SETTINGS.keys())}")

    set_p = sub.add_parser("set", help="Write a monitor setting")
    set_p.add_argument("setting", choices=all_setting_names,
                       metavar="SETTING", help=f"one of: {', '.join(all_setting_names)}")
    set_p.add_argument("value", nargs="+", help="Value to set (use 'rgb R G B' for RGB gains)")

    args = parser.parse_args()

    if not DDCUtil.available():
        print("Error: ddcutil not found. Install it with your package manager.", file=sys.stderr)
        sys.exit(1)

    ddc = DDCUtil(bus=args.bus, display=args.display, verbose=args.verbose, dry_run=args.dry_run)
    ctrl = MultiViewController(ddc)

    commands = {
        "status": cmd_status, "detect": cmd_detect, "mode": cmd_mode,
        "pip": cmd_pip, "swap": cmd_swap, "source": cmd_source,
        "get": cmd_get, "set": cmd_set,
        "factory-reset": cmd_factory_reset, "auto-setup": cmd_auto_setup,
        "info": cmd_info,
    }
    commands[args.command](ctrl, ddc, args)


if __name__ == "__main__":
    main()
