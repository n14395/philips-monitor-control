import Foundation
import IOKit
import Darwin

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

// MARK: - Native DDC/CI via IOAVService (Apple Silicon)

@_silgen_name("IOAVServiceCreateWithService")
private func _IOAVServiceCreateWithService(
    _ allocator: CFAllocator?, _ service: io_service_t
) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOAVServiceCopyEDID")
private func _IOAVServiceCopyEDID(
    _ service: CFTypeRef, _ edidOut: UnsafeMutablePointer<Unmanaged<CFData>?>
) -> IOReturn

@_silgen_name("IOAVServiceReadI2C")
private func _IOAVServiceReadI2C(
    _ service: CFTypeRef, _ chipAddress: UInt32, _ offset: UInt32,
    _ outputBuffer: UnsafeMutablePointer<UInt8>, _ outputBufferSize: UInt32
) -> IOReturn

@_silgen_name("IOAVServiceWriteI2C")
private func _IOAVServiceWriteI2C(
    _ service: CFTypeRef, _ chipAddress: UInt32, _ dataAddress: UInt32,
    _ inputBuffer: UnsafeMutablePointer<UInt8>, _ inputBufferSize: UInt32
) -> IOReturn

struct DisplayInfo: Identifiable, Hashable {
    let index: Int
    let name: String
    let connectionWarning: String?
    var id: Int { index }
}

final class NativeDDC: @unchecked Sendable {
    /// I2C chip address for DDC/CI destination (monitor)
    private static let chipAddr: UInt32 = 0x37
    /// DDC/CI host (source) address
    private static let hostAddr: UInt8 = 0x51
    /// DDC/CI destination address (chip address << 1)
    private static let destAddr: UInt8 = 0x6E

    var displayIndex: Int {
        didSet { if displayIndex != oldValue { cachedService = nil } }
    }
    var lastError: String?

    private var cachedService: CFTypeRef?

    init(displayIndex: Int = 0) { self.displayIndex = displayIndex }

    /// Enumerate available displays, using EDID to identify and name them.
    /// Displays whose EDID cannot be read (e.g. the built-in display) are excluded.
    static func enumerateDisplays() -> [DisplayInfo] {
        var results: [DisplayInfo] = []
        let builtInHDMIEDIDs = affectedBuiltInHDMIEDIDs()
        var iterator = io_iterator_t()
        guard let matching = IOServiceMatching("DCPAVServiceProxy") else { return results }
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else { return results }
        defer { IOObjectRelease(iterator) }

        var index = 0
        while case let svc = IOIteratorNext(iterator), svc != IO_OBJECT_NULL {
            defer { IOObjectRelease(svc) }
            guard let av = _IOAVServiceCreateWithService(kCFAllocatorDefault, svc) else {
                index += 1; continue
            }
            let avRef = av.takeRetainedValue()

            // Try reading the EDID — built-in displays fail this call
            var edidRef: Unmanaged<CFData>? = nil
            let kr = _IOAVServiceCopyEDID(avRef, &edidRef)
            guard kr == kIOReturnSuccess, let data = edidRef?.takeRetainedValue() as Data? else {
                index += 1; continue
            }

            let name = edidDisplayName([UInt8](data)) ?? "External Display"
            let warning = builtInHDMIEDIDs.contains { edidMatches(data, $0) }
                ? builtInHDMIWarning
                : nil
            results.append(DisplayInfo(index: index, name: name, connectionWarning: warning))
            index += 1
        }
        return results
    }

    private static let builtInHDMIWarning = "DDC/CI is not supported over this Mac's built-in HDMI port. Connect via USB-C/DisplayPort or a USB-C adapter instead."

    private static let affectedBuiltInHDMIModels: Set<String> = [
        "Macmini9,1",    // Mac mini (M1, 2020)
        "Mac13,1",       // Mac Studio (M1 Max, 2022)
        "Mac13,2",       // Mac Studio (M1 Ultra, 2022)
        "Mac14,3",       // Mac mini (M2, 2023)
        "MacBookPro18,1", "MacBookPro18,2", "MacBookPro18,3", "MacBookPro18,4",
    ]

    private static func affectedBuiltInHDMIEDIDs() -> [Data] {
        guard let model = modelIdentifier(), affectedBuiltInHDMIModels.contains(model) else { return [] }

        var results: [Data] = []
        var iterator = io_iterator_t()
        guard let matching = IOServiceMatching("IOPortTransportStateDisplayPort") else { return results }
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else { return results }
        defer { IOObjectRelease(iterator) }

        while case let svc = IOIteratorNext(iterator), svc != IO_OBJECT_NULL {
            defer { IOObjectRelease(svc) }
            guard registryBool(svc, "Active") == true,
                  registryBool(svc, "ParentPortBuiltIn") == true,
                  isBuiltInHDMITransport(svc),
                  let edid = registryData(svc, "EDID") else { continue }
            results.append(edid)
        }
        return results
    }

    private static func isBuiltInHDMITransport(_ service: io_service_t) -> Bool {
        registryString(service, "ParentBuiltInPortTypeDescription") == "HDMI"
            || registryInt(service, "ParentBuiltInPortType") == 6
            || registryInt(service, "ParentPortType") == 6
    }

    private static func modelIdentifier() -> String? {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &value, &size, nil, 0) == 0 else { return nil }
        return String(cString: value)
    }

    private static func registryProperty(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    private static func registryString(_ entry: io_registry_entry_t, _ key: String) -> String? {
        registryProperty(entry, key) as? String
    }

    private static func registryData(_ entry: io_registry_entry_t, _ key: String) -> Data? {
        registryProperty(entry, key) as? Data
    }

    private static func registryBool(_ entry: io_registry_entry_t, _ key: String) -> Bool? {
        switch registryProperty(entry, key) {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        default:
            return nil
        }
    }

    private static func registryInt(_ entry: io_registry_entry_t, _ key: String) -> Int? {
        switch registryProperty(entry, key) {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        default:
            return nil
        }
    }

    private static func edidMatches(_ lhs: Data, _ rhs: Data) -> Bool {
        if lhs == rhs { return true }
        guard lhs.count >= 128, rhs.count >= 128 else { return false }
        return lhs.prefix(128).elementsEqual(rhs.prefix(128))
    }

    /// Extract the monitor name from an EDID blob.
    private static func edidDisplayName(_ edid: [UInt8]) -> String? {
        for base in stride(from: 54, through: 108, by: 18) {
            guard base + 17 < edid.count else { break }
            if edid[base] == 0 && edid[base+1] == 0 && edid[base+2] == 0 && edid[base+3] == 0xFC {
                let nameBytes = edid[(base+5)...(base+17)]
                return String(bytes: nameBytes, encoding: .ascii)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    func getVCP(_ code: UInt8) -> VCPRaw? {
        lastError = nil
        guard let service = service() else { return nil }

        // DDC/CI Get VCP Feature request: [length|0x80, opcode=0x01, vcp_code, checksum]
        var payload: [UInt8] = [0x82, 0x01, code]
        payload.append(Self.checksum(payload))

        guard _IOAVServiceWriteI2C(service, Self.chipAddr, UInt32(Self.hostAddr),
                                   &payload, UInt32(payload.count)) == kIOReturnSuccess else {
            lastError = "DDC write failed for VCP 0x\(String(format: "%02X", code))"; return nil
        }

        usleep(40_000) // 40 ms for the monitor to prepare its reply

        // Read 12 bytes to accommodate both response formats:
        // Without source addr prefix: [0]=length|0x80  [1]=opcode  ...  [9]=cur_lo  [10]=checksum
        // With source addr prefix:    [0]=0x6E  [1]=length|0x80  [2]=opcode  ...  [10]=cur_lo  [11]=checksum
        var resp = [UInt8](repeating: 0, count: 12)
        guard _IOAVServiceReadI2C(service, Self.chipAddr, UInt32(Self.hostAddr),
                                  &resp, UInt32(resp.count)) == kIOReturnSuccess else {
            lastError = "DDC read failed for VCP 0x\(String(format: "%02X", code))"; return nil
        }

        // Determine the start of the DDC reply: some connections prefix with source address (0x6E)
        let off: Int
        if resp[0] == Self.destAddr && resp[2] == 0x02 { off = 1 }
        else if resp[1] == 0x02 { off = 0 }
        else {
            let hex = resp.prefix(4).map { String(format: "%02X", $0) }.joined(separator: " ")
            lastError = "Unexpected DDC reply for VCP 0x\(String(format: "%02X", code)): \(hex)"; return nil
        }

        guard resp[off + 1] == 0x02 else {
            lastError = "Unexpected DDC reply opcode 0x\(String(format: "%02X", resp[off + 1]))"; return nil
        }
        guard resp[off + 2] == 0x00 else {
            lastError = "VCP 0x\(String(format: "%02X", code)) unsupported (result=\(resp[off + 2]))"; return nil
        }

        // Parse max and current values from the end of the data block.
        // The length byte encodes the number of following data bytes (excluding checksum).
        // Current and max are always the last 4 bytes of the data, regardless of type field width.
        let dataLen = Int(resp[off] & 0x7F)
        let dataEnd = off + 1 + dataLen  // index past last data byte (= checksum position)
        guard dataEnd >= off + 5 else {
            lastError = "DDC reply too short for VCP 0x\(String(format: "%02X", code))"; return nil
        }

        return VCPRaw(mh: resp[dataEnd - 4], ml: resp[dataEnd - 3],
                      sh: resp[dataEnd - 2], sl: resp[dataEnd - 1])
    }

    @discardableResult
    func setVCP(_ code: UInt8, value: UInt16) -> Bool {
        lastError = nil
        guard let service = service() else { return false }

        // DDC/CI Set VCP Feature: [length|0x80, opcode=0x03, vcp_code, value_hi, value_lo, checksum]
        var payload: [UInt8] = [0x84, 0x03, code, UInt8(value >> 8), UInt8(value & 0xFF)]
        payload.append(Self.checksum(payload))

        guard _IOAVServiceWriteI2C(service, Self.chipAddr, UInt32(Self.hostAddr),
                                   &payload, UInt32(payload.count)) == kIOReturnSuccess else {
            lastError = "DDC write failed for VCP 0x\(String(format: "%02X", code))"; return false
        }
        return true
    }

    func sleep() { Thread.sleep(forTimeInterval: 0.15) }

    /// Invalidate the cached IOAVService handle (e.g. after a display reconnect).
    func invalidate() { cachedService = nil }

    // MARK: - Private

    private static func checksum(_ payload: [UInt8]) -> UInt8 {
        var xor: UInt8 = destAddr ^ hostAddr
        for b in payload { xor ^= b }
        return xor
    }

    private func service() -> CFTypeRef? {
        if let cached = cachedService { return cached }

        var iterator = io_iterator_t()
        guard let matching = IOServiceMatching("DCPAVServiceProxy") else {
            lastError = "Could not create IOService matching dictionary"; return nil
        }
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == kIOReturnSuccess else {
            lastError = "No displays found (0x\(String(format: "%08X", kr)))"; return nil
        }
        defer { IOObjectRelease(iterator) }

        var index = 0
        while case let svc = IOIteratorNext(iterator), svc != IO_OBJECT_NULL {
            defer { IOObjectRelease(svc) }
            if index == displayIndex {
                guard let av = _IOAVServiceCreateWithService(kCFAllocatorDefault, svc) else {
                    lastError = "Failed to open IOAVService for display \(index)"; return nil
                }
                let ref = av.takeRetainedValue()
                cachedService = ref
                return ref
            }
            index += 1
        }

        lastError = "Display \(displayIndex) not found (\(index) available)"; return nil
    }
}

// MARK: - Controller

final class MultiViewController: @unchecked Sendable {
    let ddc: NativeDDC

    init(ddc: NativeDDC) { self.ddc = ddc }

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
