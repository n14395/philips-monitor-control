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
    @Published var busText: String = ""

    nonisolated(unsafe) private var ddc: DDCUtilWrapper
    nonisolated(unsafe) private var ctrl: MultiViewController

    init() {
        let d = DDCUtilWrapper(); self.ddc = d; self.ctrl = MultiViewController(ddc: d)
    }

    private func updateBus() { ddc.bus = Int(busText) }

    // MARK: Refresh

    func refresh() {
        guard !isBusy else { return }
        isBusy = true; statusMessage = "Refreshing..."

        Task.detached { [weak self] in
            guard let self else { return }
            await MainActor.run { self.updateBus() }
            let status = self.ctrl.getFullStatus()
            await MainActor.run {
                self.applyStatus(status)
                self.statusMessage = "Refreshed"
                self.isBusy = false
            }
        }
    }

    private func applyStatus(_ s: MonitorStatus) {
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

    func applyPicture() {
        runAsync("Applying picture...") { [self] in
            ctrl.setContinuous(VCP.brightness, Int(await get(\.brightness)))
            ctrl.setContinuous(VCP.contrast, Int(await get(\.contrast)))
            ctrl.setEnum(VCP.colorTemp, await get(\.colorTemp).rawValue)
            ctrl.setEnum(VCP.gamma, await get(\.gamma).rawValue)
            ctrl.setEnum(VCP.smartImage, await get(\.smartImage).rawValue)
            ctrl.setEnum(VCP.scaling, await get(\.scaling).rawValue)
            ctrl.setContinuous(VCP.redGain, Int(await get(\.redGain)))
            ctrl.setContinuous(VCP.greenGain, Int(await get(\.greenGain)))
            ctrl.setContinuous(VCP.blueGain, Int(await get(\.blueGain)))
        }
    }

    func applyAudio() {
        runAsync("Applying audio...") { [self] in
            ctrl.setContinuous(VCP.volume, Int(await get(\.volume)))
            ctrl.setEnum(VCP.audioMute, await get(\.mute).rawValue)
        }
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

    private func runAsync(_ msg: String, _ work: @Sendable @escaping () async -> Void) {
        guard !isBusy else { return }
        isBusy = true; statusMessage = msg
        Task.detached { [weak self] in
            guard let self else { return }
            await MainActor.run { self.updateBus() }
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
                TextField("Bus", text: $vm.busText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .help("I2C bus number (blank = auto)")
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
                SliderRow(label: "Brightness", value: $vm.brightness, range: 0...100)
                SliderRow(label: "Contrast", value: $vm.contrast, range: 0...100)
            }
            Section("Color") {
                Picker("Color Temperature", selection: $vm.colorTemp) {
                    ForEach(ColorTemp.allCases) { t in Text(t.label).tag(t) }
                }
                Picker("Gamma", selection: $vm.gamma) {
                    ForEach(GammaPreset.allCases) { g in Text(g.label).tag(g) }
                }
                Picker("SmartImage", selection: $vm.smartImage) {
                    ForEach(SmartImagePreset.allCases) { s in Text(s.label).tag(s) }
                }
                Picker("Scaling", selection: $vm.scaling) {
                    ForEach(DisplayScaling.allCases) { s in Text(s.label).tag(s) }
                }
            }
            Section("RGB Gains") {
                SliderRow(label: "Red", value: $vm.redGain, range: 0...100, tint: .red)
                SliderRow(label: "Green", value: $vm.greenGain, range: 0...100, tint: .green)
                SliderRow(label: "Blue", value: $vm.blueGain, range: 0...100, tint: .blue)
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Apply Picture") { vm.applyPicture() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
            .padding()
        }
    }
}

// MARK: - Audio Tab

struct AudioTab: View {
    @ObservedObject var vm: ViewModel

    var body: some View {
        Form {
            Section("Audio") {
                SliderRow(label: "Volume", value: $vm.volume, range: 0...100)
                Picker("Mute", selection: $vm.mute) {
                    ForEach(AudioMuteState.allCases) { m in Text(m.label).tag(m) }
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Apply Audio") { vm.applyAudio() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
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

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            Slider(value: $value, in: range, step: step)
                .tint(tint)
            Text("\(Int(value))")
                .frame(width: 30, alignment: .trailing)
                .monospacedDigit()
        }
    }
}
