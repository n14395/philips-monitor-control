import SwiftUI

@main
struct PhilipsMultiViewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 480, minHeight: 640)
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - ViewModel

@MainActor
final class ViewModel: ObservableObject, @unchecked Sendable {
    // MultiView
    @Published var mode: MultiViewMode = .off
    @Published var pipSize: PIPSize = .small
    @Published var pipLocation: PIPLocation = .upperRight
    @Published var mainSource: InputSource = .hdmi1
    @Published var secondarySource: InputSource = .dp1
    // Picture
    @Published var brightness: Double = 50
    @Published var contrast: Double = 50
    @Published var colorTemp: ColorTemp = .k6500
    @Published var gamma: GammaPreset = .g22
    @Published var smartImage: SmartImagePreset = .off
    @Published var scaling: DisplayScaling = .wide
    @Published var redGain: Double = 50
    @Published var greenGain: Double = 50
    @Published var blueGain: Double = 50
    // Audio
    @Published var volume: Double = 50
    @Published var mute: AudioMuteState = .unmuted
    // System
    @Published var power: PowerMode = .on
    @Published var powerLED: Double = 2
    // Status display
    @Published var statusMode: String = "--"
    @Published var statusMain: String = "--"
    @Published var statusSecondary: String = "--"
    @Published var statusSupported: String = "--"
    @Published var firmwareVersion: String = "--"
    @Published var usageTime: String = "--"
    // UI state
    @Published var statusMessage: String = "Ready"
    @Published var isBusy: Bool = false
    @Published var displays: [DisplayInfo] = []
    @Published var selectedDisplayIndex: Int = 0
    private var suppressOnChange: Bool = false

    nonisolated(unsafe) private var ddc: NativeDDC
    nonisolated(unsafe) private var ctrl: MultiViewController

    init() {
        let d = NativeDDC(); self.ddc = d; self.ctrl = MultiViewController(ddc: d)
        let found = NativeDDC.enumerateDisplays()
        self.displays = found
        // Default to the first external display
        if let ext = found.first(where: { !$0.isBuiltIn }) {
            self.selectedDisplayIndex = ext.index
        } else if let last = found.last {
            self.selectedDisplayIndex = last.index
        }
    }

    private func updateDisplay() { ddc.displayIndex = selectedDisplayIndex }

    // MARK: Refresh

    func refresh() {
        guard !isBusy else { return }
        isBusy = true; statusMessage = "Refreshing..."

        Task.detached { [weak self] in
            guard let self else { return }
            await MainActor.run { self.updateDisplay() }
            let status = self.ctrl.getFullStatus()
            await MainActor.run {
                self.applyStatus(status)
                self.statusMessage = "Refreshed"
                self.isBusy = false
            }
        }
    }

    private func applyStatus(_ s: MonitorStatus) {
        suppressOnChange = true
        defer { suppressOnChange = false }
        // MultiView
        if let m = s.mode { statusMode = m.label; mode = m }
        else if let raw = s.modeRaw { statusMode = String(format: "0x%04x", raw) }
        if let src = s.mainSource { statusMain = src.label; mainSource = src }
        if let src = s.secondarySource { statusSecondary = src.label; secondarySource = src }
        if let sz = s.size { pipSize = sz }
        if let loc = s.location { pipLocation = loc }
        statusSupported = s.supportDesc ?? "--"
        // Picture
        if let v = s.brightness { brightness = Double(v) }
        if let v = s.contrast { contrast = Double(v) }
        if let v = s.colorTemp { colorTemp = v }
        if let v = s.gamma { gamma = v }
        if let v = s.smartImage { smartImage = v }
        if let v = s.scaling { scaling = v }
        if let v = s.redGain { redGain = Double(v) }
        if let v = s.greenGain { greenGain = Double(v) }
        if let v = s.blueGain { blueGain = Double(v) }
        // Audio
        if let v = s.volume { volume = Double(v) }
        if let v = s.mute { mute = v }
        // System
        if let v = s.power { power = v }
        if let v = s.powerLED { powerLED = Double(v) }
        firmwareVersion = s.firmwareVersion ?? "--"
        usageTime = s.usageTime.map { "\($0) hours" } ?? "--"
    }

    // MARK: Apply actions

    /// Send a single VCP value without a full status refresh.
    func sendContinuous(_ code: UInt8, _ value: Int) {
        guard !suppressOnChange else { return }
        sendSingle("Setting \(code)...") { [self] in ctrl.setContinuous(code, value) }
    }

    func sendEnum(_ code: UInt8, _ value: UInt8) {
        guard !suppressOnChange else { return }
        sendSingle("Setting \(code)...") { [self] in ctrl.setEnum(code, value) }
    }

    func applyInput() {
        runAsync("Applying input...") { [self] in
            ctrl.setMainSource(await get(\.mainSource))
            ctrl.setSecondarySource(await get(\.secondarySource))
        }
    }

    func applyMultiView() {
        runAsync("Applying MultiView...") { [self] in
            let m = await get(\.mode)
            switch m {
            case .off: ctrl.setModeOff()
            case .pip: ctrl.setPIP(secondary: await get(\.secondarySource),
                                    size: await get(\.pipSize), location: await get(\.pipLocation))
            default: ctrl.setPBP(mode: m, secondary: await get(\.secondarySource))
            }
        }
    }

    func swapSources() {
        runAsync("Swapping...") { [self] in _ = ctrl.swapSources() }
    }

    func turnOff() {
        runAsync("Turning off...") { [self] in ctrl.setModeOff() }
    }

    func applySystem() {
        runAsync("Applying system...") { [self] in
            ctrl.setEnum(VCP.powerMode, await get(\.power).rawValue)
            ctrl.setContinuous(VCP.powerLED, Int(await get(\.powerLED)))
        }
    }

    // MARK: Helpers

    private func get<T: Sendable>(_ kp: KeyPath<ViewModel, T>) async -> T {
        await MainActor.run { self[keyPath: kp] }
    }

    private func sendSingle(_ msg: String, _ work: @Sendable @escaping () -> Void) {
        Task.detached { [weak self] in
            guard let self else { return }
            await MainActor.run { self.updateDisplay() }
            work()
        }
    }

    private func runAsync(_ msg: String, _ work: @Sendable @escaping () async -> Void) {
        guard !isBusy else { return }
        isBusy = true; statusMessage = msg
        Task.detached { [weak self] in
            guard let self else { return }
            await MainActor.run { self.updateDisplay() }
            await work()
            Thread.sleep(forTimeInterval: 0.2)
            let status = self.ctrl.getFullStatus()
            await MainActor.run {
                self.applyStatus(status)
                self.statusMessage = "Done"
                self.isBusy = false
            }
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var vm = ViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                TabView {
                    PictureTab(vm: vm).tabItem { Label("Picture", systemImage: "sun.max") }
                    AudioTab(vm: vm).tabItem { Label("Audio", systemImage: "speaker.wave.2") }
                    InputTab(vm: vm).tabItem { Label("Input", systemImage: "rectangle.on.rectangle") }
                    MultiViewTab(vm: vm).tabItem { Label("MultiView", systemImage: "rectangle.split.2x1") }
                    SystemTab(vm: vm).tabItem { Label("System", systemImage: "gearshape") }
                }
                .disabled(vm.isBusy)
                .opacity(vm.isBusy ? 0.3 : 1.0)

                if vm.isBusy {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(vm.statusMessage)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: vm.isBusy)

            Divider()

            // Bottom bar
            HStack(spacing: 12) {
                Button("Refresh") { vm.refresh() }
                    .keyboardShortcut("r")
                    .disabled(vm.isBusy)
                Text(vm.statusMessage).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Picker("Display", selection: $vm.selectedDisplayIndex) {
                    ForEach(vm.displays) { d in
                        Text("\(d.name) (\(d.index))").tag(d.index)
                    }
                }
                .frame(maxWidth: 200)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .onAppear { vm.refresh() }
    }
}

// MARK: - Picture Tab

struct PictureTab: View {
    @ObservedObject var vm: ViewModel

    var body: some View {
        Form {
            Section("Display") {
                SliderRow(label: "Brightness", value: $vm.brightness, range: 0...100,
                          onCommit: { vm.sendContinuous(VCP.brightness, Int(vm.brightness)) })
                SliderRow(label: "Contrast", value: $vm.contrast, range: 0...100,
                          onCommit: { vm.sendContinuous(VCP.contrast, Int(vm.contrast)) })
            }
            Section("Color") {
                Picker("Color Temperature", selection: $vm.colorTemp) {
                    ForEach(ColorTemp.allCases) { t in Text(t.label).tag(t) }
                }
                .onChange(of: vm.colorTemp) { vm.sendEnum(VCP.colorTemp, $1.rawValue) }
                Picker("Gamma", selection: $vm.gamma) {
                    ForEach(GammaPreset.allCases) { g in Text(g.label).tag(g) }
                }
                .onChange(of: vm.gamma) { vm.sendEnum(VCP.gamma, $1.rawValue) }
                Picker("SmartImage", selection: $vm.smartImage) {
                    ForEach(SmartImagePreset.allCases) { s in Text(s.label).tag(s) }
                }
                .onChange(of: vm.smartImage) { vm.sendEnum(VCP.smartImage, $1.rawValue) }
                Picker("Scaling", selection: $vm.scaling) {
                    ForEach(DisplayScaling.allCases) { s in Text(s.label).tag(s) }
                }
                .onChange(of: vm.scaling) { vm.sendEnum(VCP.scaling, $1.rawValue) }
            }
            Section("RGB Gains") {
                SliderRow(label: "Red", value: $vm.redGain, range: 0...100, tint: .red,
                          onCommit: { vm.sendContinuous(VCP.redGain, Int(vm.redGain)) })
                SliderRow(label: "Green", value: $vm.greenGain, range: 0...100, tint: .green,
                          onCommit: { vm.sendContinuous(VCP.greenGain, Int(vm.greenGain)) })
                SliderRow(label: "Blue", value: $vm.blueGain, range: 0...100, tint: .blue,
                          onCommit: { vm.sendContinuous(VCP.blueGain, Int(vm.blueGain)) })
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Audio Tab

struct AudioTab: View {
    @ObservedObject var vm: ViewModel

    var body: some View {
        Form {
            Section("Audio") {
                SliderRow(label: "Volume", value: $vm.volume, range: 0...100,
                          onCommit: { vm.sendContinuous(VCP.volume, Int(vm.volume)) })
                Picker("Mute", selection: $vm.mute) {
                    ForEach(AudioMuteState.allCases) { m in Text(m.label).tag(m) }
                }
                .onChange(of: vm.mute) { vm.sendEnum(VCP.audioMute, $1.rawValue) }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Input Tab

struct InputTab: View {
    @ObservedObject var vm: ViewModel

    var body: some View {
        Form {
            Section("Input Sources") {
                Picker("Main", selection: $vm.mainSource) {
                    ForEach(InputSource.allMain) { s in Text(s.label).tag(s) }
                }
                Picker("Secondary", selection: $vm.secondarySource) {
                    ForEach(InputSource.allSecondary) { s in Text(s.label).tag(s) }
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Spacer()
                Button("Swap") { vm.swapSources() }
                Button("Apply Input") { vm.applyInput() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

// MARK: - MultiView Tab

struct MultiViewTab: View {
    @ObservedObject var vm: ViewModel

    var body: some View {
        Form {
            Section("Current State") {
                StatusRow(label: "Mode", value: vm.statusMode)
                StatusRow(label: "Main Input", value: vm.statusMain)
                StatusRow(label: "Secondary Input", value: vm.statusSecondary)
                StatusRow(label: "Supported", value: vm.statusSupported)
            }
            Section("Mode") {
                Picker("Mode", selection: $vm.mode) {
                    ForEach(MultiViewMode.allCases) { m in Text(m.label).tag(m) }
                }
                .pickerStyle(.segmented)
            }
            if vm.mode == .pip {
                Section("PIP Settings") {
                    Picker("Size", selection: $vm.pipSize) {
                        ForEach(PIPSize.allCases) { s in Text(s.label).tag(s) }
                    }
                    Picker("Position", selection: $vm.pipLocation) {
                        ForEach(PIPLocation.allCases) { l in Text(l.label).tag(l) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button("Turn Off") { vm.turnOff() }
                Spacer()
                Button("Apply MultiView") { vm.applyMultiView() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
            .padding()
        }
    }
}

// MARK: - System Tab

struct SystemTab: View {
    @ObservedObject var vm: ViewModel

    var body: some View {
        Form {
            Section("Power") {
                Picker("Power Mode", selection: $vm.power) {
                    ForEach(PowerMode.allCases) { p in Text(p.label).tag(p) }
                }
                SliderRow(label: "Power LED", value: $vm.powerLED, range: 0...4, step: 1)
            }
            Section("Info") {
                StatusRow(label: "Firmware", value: vm.firmwareVersion)
                StatusRow(label: "Usage Time", value: vm.usageTime)
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Apply System") { vm.applySystem() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

// MARK: - Reusable Components

struct StatusRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    var step: Double = 1
    var tint: Color? = nil
    var onCommit: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            Slider(value: $value, in: range, step: step) { editing in
                if !editing { onCommit?() }
            }
            .tint(tint)
            Text("\(Int(value))")
                .frame(width: 30, alignment: .trailing)
                .monospacedDigit()
        }
    }
}
