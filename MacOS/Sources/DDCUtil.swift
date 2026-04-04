import Foundation

// MARK: - VCP Code Constants

enum VCP {
    // MultiView
    static let windowSelect: UInt8 = 0xA5
    static let sizeLocation: UInt8 = 0xEC
    static let inputSource: UInt8 = 0x60
    static let windowMask: UInt8 = 0xA4
    static let swap: UInt8 = 0xF6
    static let supportType: UInt8 = 0xF7
    // Picture
    static let brightness: UInt8 = 0x10
    static let contrast: UInt8 = 0x12
    static let colorTemp: UInt8 = 0x14
    static let redGain: UInt8 = 0x16
    static let greenGain: UInt8 = 0x18
    static let blueGain: UInt8 = 0x1A
    static let gamma: UInt8 = 0x72
    static let scaling: UInt8 = 0x86
    static let smartImage: UInt8 = 0xDC
    // Audio
    static let volume: UInt8 = 0x62
    static let audioMute: UInt8 = 0x8D
    // System
    static let powerMode: UInt8 = 0xD6
    static let powerLED: UInt8 = 0xF2
    static let osdLanguage: UInt8 = 0xCC
    static let resolutionNotifier: UInt8 = 0xE9
    static let inputAuto: UInt8 = 0xED
    // Info (read-only)
    static let usageTime: UInt8 = 0xC0
    static let firmware: UInt8 = 0xC9
    // Actions
    static let factoryReset: UInt8 = 0x04
}

// MARK: - MultiView Enums

enum MultiViewMode: UInt16, CaseIterable, Identifiable {
    case off = 0x0000, pip = 0x0100, pbp1 = 0x0200, pbp2 = 0x0400, pbp3 = 0x0800
    var id: UInt16 { rawValue }
    var label: String {
        switch self {
        case .off: return "Off"; case .pip: return "PIP"
        case .pbp1: return "PBP 1 (L/R)"; case .pbp2: return "PBP 2"; case .pbp3: return "PBP 3"
        }
    }
}

enum PIPSize: UInt8, CaseIterable, Identifiable {
    case small = 1, medium = 2, large = 3
    var id: UInt8 { rawValue }
    var label: String {
        switch self { case .small: return "Small"; case .medium: return "Medium"; case .large: return "Large" }
    }
}

enum PIPLocation: UInt8, CaseIterable, Identifiable {
    case upperRight = 1, lowerRight = 2, upperLeft = 3, lowerLeft = 4
    var id: UInt8 { rawValue }
    var label: String {
        switch self {
        case .upperRight: return "Upper Right"; case .lowerRight: return "Lower Right"
        case .upperLeft: return "Upper Left"; case .lowerLeft: return "Lower Left"
        }
    }
}

// MARK: - Input Sources

enum InputSource: Identifiable, Hashable {
    case vga1, dsub, dvi, dp1, dp2, hdmi1, hdmi2, hdmi3, usbc1, usbc2

    var id: String { label }
    var label: String {
        switch self {
        case .vga1: return "VGA 1"; case .dsub: return "D-Sub"; case .dvi: return "DVI"
        case .dp1: return "DP 1"; case .dp2: return "DP 2"
        case .hdmi1: return "HDMI 1"; case .hdmi2: return "HDMI 2"; case .hdmi3: return "HDMI 3"
        case .usbc1: return "USB-C 1"; case .usbc2: return "USB-C 2"
        }
    }
    var mainCode: UInt8 {
        switch self {
        case .vga1: return 0x01; case .dsub: return 0x02; case .dvi: return 0x03
        case .dp1: return 0x0F; case .dp2: return 0x10
        case .hdmi1: return 0x11; case .hdmi2: return 0x12; case .hdmi3: return 0x13
        case .usbc1: return 0x15; case .usbc2: return 0x16
        }
    }
    var secondaryCode: UInt8 {
        switch self {
        case .hdmi1: return 0x21; case .hdmi2: return 0x22; case .hdmi3: return 0x23
        case .dvi: return 0x24; case .dp1: return 0x2F; case .dp2: return 0x30
        case .vga1: return 0x31; case .dsub: return 0x31
        case .usbc1: return 0x35; case .usbc2: return 0x36
        }
    }
    static let allMain: [InputSource] = [.vga1, .dsub, .dvi, .dp1, .dp2, .hdmi1, .hdmi2, .hdmi3, .usbc1, .usbc2]
    static let allSecondary: [InputSource] = [.hdmi1, .hdmi2, .hdmi3, .dvi, .dp1, .dp2, .vga1, .usbc1, .usbc2]

    static func fromMainCode(_ code: UInt8) -> InputSource? { allMain.first { $0.mainCode == code } }
    static func fromSecondaryCode(_ code: UInt8) -> InputSource? { allSecondary.first { $0.secondaryCode == code } }
}

// MARK: - Enum Settings

enum ColorTemp: UInt8, CaseIterable, Identifiable {
    case sRGB = 1, native = 2, k5000 = 4, k6500 = 5, k7500 = 6, k8200 = 7, k9300 = 8, k11500 = 10, user = 11
    var id: UInt8 { rawValue }
    var label: String {
        switch self {
        case .sRGB: return "sRGB"; case .native: return "Native"
        case .k5000: return "5000K"; case .k6500: return "6500K"; case .k7500: return "7500K"
        case .k8200: return "8200K"; case .k9300: return "9300K"; case .k11500: return "11500K"
        case .user: return "User"
        }
    }
}

enum GammaPreset: UInt8, CaseIterable, Identifiable {
    case g18 = 80, g20 = 100, g22 = 120, g24 = 140, g26 = 160
    var id: UInt8 { rawValue }
    var label: String {
        switch self {
        case .g18: return "1.8"; case .g20: return "2.0"; case .g22: return "2.2"
        case .g24: return "2.4"; case .g26: return "2.6"
        }
    }
}

enum SmartImagePreset: UInt8, CaseIterable, Identifiable {
    case off = 0, office = 1, photo = 2, movie = 3, game = 5
    case economy = 8, lowBlue = 11, easyRead = 14, smartUniformity = 31
    var id: UInt8 { rawValue }
    var label: String {
        switch self {
        case .off: return "Off"; case .office: return "Office"; case .photo: return "Photo"
        case .movie: return "Movie"; case .game: return "Game"; case .economy: return "Economy"
        case .lowBlue: return "Low Blue"; case .easyRead: return "EasyRead"
        case .smartUniformity: return "SmartUniformity"
        }
    }
}

enum DisplayScaling: UInt8, CaseIterable, Identifiable {
    case oneToOne = 1, wide = 2, fourThree = 5, movie1 = 33, movie2 = 34
    var id: UInt8 { rawValue }
    var label: String {
        switch self {
        case .oneToOne: return "1:1"; case .wide: return "Wide"; case .fourThree: return "4:3"
        case .movie1: return "Movie 1"; case .movie2: return "Movie 2"
        }
    }
}

enum AudioMuteState: UInt8, CaseIterable, Identifiable {
    case muted = 1, unmuted = 2
    var id: UInt8 { rawValue }
    var label: String { self == .muted ? "Muted" : "Unmuted" }
}

enum PowerMode: UInt8, CaseIterable, Identifiable {
    case on = 1, standby = 2, suspend = 3, sleep = 4, off = 5
    var id: UInt8 { rawValue }
    var label: String {
        switch self {
        case .on: return "On"; case .standby: return "Standby"; case .suspend: return "Suspend"
        case .sleep: return "Sleep"; case .off: return "Off"
        }
    }
}

// MARK: - VCP Raw Result

struct VCPRaw {
    let mh: UInt8, ml: UInt8, sh: UInt8, sl: UInt8
    var currentValue: UInt16 { UInt16(sh) << 8 | UInt16(sl) }
    var maxValue: UInt16 { UInt16(mh) << 8 | UInt16(ml) }
}

// MARK: - Monitor Status

struct MonitorStatus {
    var mode: MultiViewMode?; var modeRaw: UInt16?
    var size: PIPSize?; var location: PIPLocation?
    var mainSource: InputSource?; var secondarySource: InputSource?
    var mainSourceRaw: UInt8?; var secondarySourceRaw: UInt8?
    var supportType: UInt8?; var supportDesc: String?
    // Settings
    var brightness: Int?; var brightnessMax: Int?
    var contrast: Int?; var contrastMax: Int?
    var volume: Int?; var volumeMax: Int?
    var redGain: Int?; var greenGain: Int?; var blueGain: Int?
    var colorTemp: ColorTemp?
    var gamma: GammaPreset?
    var smartImage: SmartImagePreset?
    var scaling: DisplayScaling?
    var mute: AudioMuteState?
    var power: PowerMode?
    var powerLED: Int?; var powerLEDMax: Int?
    // Info
    var firmwareVersion: String?; var usageTime: String?
}

// MARK: - DDCUtil Wrapper

final class DDCUtilWrapper: @unchecked Sendable {
    var bus: Int?
    var lastError: String?

    init(bus: Int? = nil) { self.bus = bus }

    private func baseArgs() -> [String] {
        var args = ["ddcutil"]
        if let bus = bus { args += ["--bus", String(bus)] }
        return args
    }

    static func isAvailable() -> Bool {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["which", "ddcutil"]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try? p.run(); p.waitUntilExit()
        return p.terminationStatus == 0
    }

    func getVCP(_ code: UInt8) -> VCPRaw? {
        lastError = nil
        let args = baseArgs() + ["getvcp", String(format: "0x%02x", code), "--verbose"]
        let (stdout, stderr, status) = runProcess(args)
        guard status == 0 else { lastError = stderr; return nil }

        let output = stdout + stderr
        let pattern = #"mh=0x([0-9a-fA-F]{2}),\s*ml=0x([0-9a-fA-F]{2}),\s*sh=0x([0-9a-fA-F]{2}),\s*sl=0x([0-9a-fA-F]{2})"#
        if let match = output.range(of: pattern, options: .regularExpression) {
            let sub = String(output[match])
            let hexValues = sub.components(separatedBy: CharacterSet(charactersIn: "=, "))
                .filter { $0.hasPrefix("0x") }
                .compactMap { UInt8($0.dropFirst(2), radix: 16) }
            if hexValues.count == 4 {
                return VCPRaw(mh: hexValues[0], ml: hexValues[1], sh: hexValues[2], sl: hexValues[3])
            }
        }

        let fallback = #"current value\s*=\s*(\d+),\s*max value\s*=\s*(\d+)"#
        if let match = output.range(of: fallback, options: .regularExpression) {
            let sub = String(output[match])
            let nums = sub.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { UInt16($0) }
            if nums.count >= 2 {
                return VCPRaw(mh: UInt8((nums[1] >> 8) & 0xFF), ml: UInt8(nums[1] & 0xFF),
                              sh: UInt8((nums[0] >> 8) & 0xFF), sl: UInt8(nums[0] & 0xFF))
            }
        }
        lastError = "Could not parse getvcp output"; return nil
    }

    @discardableResult
    func setVCP(_ code: UInt8, value: UInt16) -> Bool {
        lastError = nil
        let args = baseArgs() + ["setvcp", String(format: "0x%02x", code), String(format: "0x%04x", value), "--noverify"]
        let (_, stderr, status) = runProcess(args)
        if status != 0 { lastError = stderr; return false }
        return true
    }

    func sleep() { Thread.sleep(forTimeInterval: 0.15) }

    private func runProcess(_ arguments: [String]) -> (String, String, Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        let stdoutPipe = Pipe(); let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe; process.standardError = stderrPipe
        do { try process.run() }
        catch { return ("", error.localizedDescription, 1) }
        // Read pipes before waitUntilExit to avoid deadlock when output exceeds pipe buffer
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        return (stdout, stderr, process.terminationStatus)
    }
}

// MARK: - Controller

final class MultiViewController: @unchecked Sendable {
    let ddc: DDCUtilWrapper

    init(ddc: DDCUtilWrapper) { self.ddc = ddc }

    func getFullStatus() -> MonitorStatus {
        var s = MonitorStatus()

        // MultiView
        if let raw = ddc.getVCP(VCP.windowSelect) {
            s.modeRaw = raw.currentValue; s.mode = MultiViewMode(rawValue: raw.currentValue)
        }
        if let raw = ddc.getVCP(VCP.sizeLocation) {
            s.size = PIPSize(rawValue: raw.sl); s.location = PIPLocation(rawValue: raw.sh)
        }
        if let raw = ddc.getVCP(VCP.inputSource) {
            s.mainSourceRaw = raw.sl; s.secondarySourceRaw = raw.sh
            s.mainSource = InputSource.fromMainCode(raw.sl)
            s.secondarySource = InputSource.fromSecondaryCode(raw.sh)
        }
        if let raw = ddc.getVCP(VCP.supportType) {
            s.supportType = raw.sl
            let types: [UInt8: String] = [2:"PBP_1",3:"PBP_1+2",4:"PBP_1+2+3",64:"PIP",66:"PIP+PBP_1",67:"PIP+PBP_1+2",68:"PIP+PBP_1+2+3"]
            s.supportDesc = types[raw.sl] ?? "Unknown (\(raw.sl))"
        }

        // Picture
        if let raw = ddc.getVCP(VCP.brightness) { s.brightness = Int(raw.sl); s.brightnessMax = Int(raw.ml) }
        if let raw = ddc.getVCP(VCP.contrast) { s.contrast = Int(raw.sl); s.contrastMax = Int(raw.ml) }
        if let raw = ddc.getVCP(VCP.colorTemp) { s.colorTemp = ColorTemp(rawValue: raw.sl) }
        if let raw = ddc.getVCP(VCP.gamma) { s.gamma = GammaPreset(rawValue: raw.sl) }
        if let raw = ddc.getVCP(VCP.smartImage) { s.smartImage = SmartImagePreset(rawValue: raw.sl) }
        if let raw = ddc.getVCP(VCP.scaling) { s.scaling = DisplayScaling(rawValue: raw.sl) }
        if let raw = ddc.getVCP(VCP.redGain) { s.redGain = Int(raw.sl) }
        if let raw = ddc.getVCP(VCP.greenGain) { s.greenGain = Int(raw.sl) }
        if let raw = ddc.getVCP(VCP.blueGain) { s.blueGain = Int(raw.sl) }

        // Audio
        if let raw = ddc.getVCP(VCP.volume) { s.volume = Int(raw.sl); s.volumeMax = Int(raw.ml) }
        if let raw = ddc.getVCP(VCP.audioMute) { s.mute = AudioMuteState(rawValue: raw.sl) }

        // System
        if let raw = ddc.getVCP(VCP.powerMode) { s.power = PowerMode(rawValue: raw.sl) }
        if let raw = ddc.getVCP(VCP.powerLED) { s.powerLED = Int(raw.sl); s.powerLEDMax = Int(raw.ml) }

        // Info
        if let raw = ddc.getVCP(VCP.firmware) { s.firmwareVersion = "\(raw.sh).\(raw.sl)" }
        if let raw = ddc.getVCP(VCP.usageTime) { s.usageTime = "\(raw.currentValue)" }

        return s
    }

    // MultiView operations
    func setModeOff() {
        ddc.setVCP(VCP.windowSelect, value: MultiViewMode.off.rawValue); ddc.sleep()
        if let raw = ddc.getVCP(VCP.sizeLocation) { ddc.setVCP(VCP.sizeLocation, value: raw.currentValue); ddc.sleep() }
        if let raw = ddc.getVCP(VCP.inputSource) { ddc.setVCP(VCP.inputSource, value: raw.currentValue); ddc.sleep() }
        ddc.setVCP(VCP.windowMask, value: 0xFFFF)
    }
    func setPIP(secondary: InputSource, size: PIPSize, location: PIPLocation) {
        ddc.setVCP(VCP.windowSelect, value: MultiViewMode.pip.rawValue); ddc.sleep()
        ddc.setVCP(VCP.sizeLocation, value: UInt16(size.rawValue) | (UInt16(location.rawValue) << 8)); ddc.sleep()
        setSecondarySource(secondary)
    }
    func setPBP(mode: MultiViewMode, secondary: InputSource?) {
        ddc.setVCP(VCP.windowSelect, value: mode.rawValue); ddc.sleep()
        if let raw = ddc.getVCP(VCP.sizeLocation) { ddc.setVCP(VCP.sizeLocation, value: raw.currentValue); ddc.sleep() }
        if let sec = secondary { setSecondarySource(sec) }
        else if let raw = ddc.getVCP(VCP.inputSource) { ddc.setVCP(VCP.inputSource, value: raw.currentValue) }
    }
    func swapSources() -> Bool { ddc.setVCP(VCP.swap, value: 0x0001) }

    // Input
    func setMainSource(_ source: InputSource) {
        if let raw = ddc.getVCP(VCP.inputSource) { ddc.setVCP(VCP.inputSource, value: UInt16(source.mainCode) | (UInt16(raw.sh) << 8)) }
        else { ddc.setVCP(VCP.inputSource, value: UInt16(source.mainCode)) }
    }
    func setSecondarySource(_ source: InputSource) {
        if let raw = ddc.getVCP(VCP.inputSource) { ddc.setVCP(VCP.inputSource, value: UInt16(raw.sl) | (UInt16(source.secondaryCode) << 8)) }
        else { ddc.setVCP(VCP.inputSource, value: UInt16(source.secondaryCode) << 8) }
    }

    // Simple set helpers
    func setContinuous(_ code: UInt8, _ value: Int) { ddc.setVCP(code, value: UInt16(value)) }
    func setEnum(_ code: UInt8, _ value: UInt8) { ddc.setVCP(code, value: UInt16(value)) }
}
