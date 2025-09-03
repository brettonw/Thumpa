import Foundation
import AVFoundation

final class PatternEngine {
    static let shared = PatternEngine()

    private let engine = AVAudioEngine()
    private let clock = TickClock(bpm: 90)
    private let beatsPerBar = 4
    private let ticksPerBeat = 16
    private var ticksPerBar: Int { beatsPerBar * ticksPerBeat }

    private let kickPlayer = AVAudioPlayerNode()
    private let snarePlayer = AVAudioPlayerNode()
    private let hihatPlayer = AVAudioPlayerNode()

    private enum InstrumentType: String, CaseIterable { case kick = "Kick", snare = "Snare", hihat = "Hi‑Hat" }

    private struct Track {
        var rolling: RollingBar
        let player: AVAudioPlayerNode
        let instrument: BeatInstrument
        let gain: Double
    }

    private var tracks: [InstrumentType: Track] = [:]

    private(set) var isPlaying = false
    private(set) var activeBPM: Double = 90
    private var desiredBPM: Double = 90
    private(set) var globalTick: Int = 0

    private init() {
        setupTracks()
        clock.onTick = { [weak self] in self?.onTick() }
    }

    // Public API
    func start() {
        guard !isPlaying else { return }
        do {
            try configureSession()
            try configureEngineIfNeeded()
            try startEngineIfNeeded()
            activeBPM = desiredBPM
            // Prime current bars to reflect initial enabled state
            for (type, var tr) in tracks {
                tr.rolling.primeCurrentToTemplateIfEnabled()
                tracks[type] = tr
            }
            globalTick = 0
            [kickPlayer, snarePlayer, hihatPlayer].forEach { $0.play() }
            clock.bpm = activeBPM
            clock.start()
            isPlaying = true
        } catch {
            print("PatternEngine start error: \(error)")
        }
    }

    func stop() {
        guard isPlaying else { return }
        [kickPlayer, snarePlayer, hihatPlayer].forEach { $0.stop() }
        clock.stop()
        isPlaying = false
    }

    func setBPM(_ bpm: Double) { desiredBPM = max(20, min(300, bpm)) }
    func setPrimaryEnabled(_ on: Bool) { setDesired(on, for: .kick) }
    func setSnareEnabled(_ on: Bool) { setDesired(on, for: .snare) }
    func setHihatEnabled(_ on: Bool) { setDesired(on, for: .hihat) }
    func toggleNextBarTick(_ name: String, tickInBar: Int) {
        guard let type = InstrumentType(rawValue: name), var tr = tracks[type] else { return }
        // Only meaningful when enabled; mirror original behavior and ignore when disabled
        if tr.rolling.enabled {
            _ = tr.rolling.toggleNextBarTick(tickInBar)
            tracks[type] = tr
        }
    }

    func currentTicks() -> (globalTick: Int, tickInMeasure: Int, measureIndex: Int) {
        let tickInMeasure = globalTick % 64
        let measureIndex = globalTick / 64
        return (globalTick, tickInMeasure, measureIndex)
    }

    // Snapshot window centered at a specific global tick to avoid race
    func windowForInstrument(_ name: String, at snapshotGlobalTick: Int? = nil) -> (ticks: [Bool], center: Int) {
        guard let type = InstrumentType(rawValue: name), let tr = tracks[type] else {
            return (Array(repeating: false, count: ticksPerBar * 2), ticksPerBar)
        }
        // RollingBar maintains its own offset; ignore snapshot for now to avoid tearing
        let window = tr.rolling.getDisplay()
        return (window, ticksPerBar)
    }

    // MARK: - Internals
    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true, options: [])
    }

    private func configureEngineIfNeeded() throws {
        guard engine.attachedNodes.isEmpty else { return }
        [kickPlayer, snarePlayer, hihatPlayer].forEach { engine.attach($0) }
        let format = engine.outputNode.outputFormat(forBus: 0)
        [kickPlayer, snarePlayer, hihatPlayer].forEach { engine.connect($0, to: engine.mainMixerNode, format: format) }
    }

    private func startEngineIfNeeded() throws {
        if !engine.isRunning { try engine.start() }
    }

    private func setupTracks() {
        func defaultPattern(for type: InstrumentType) -> [Bool] {
            var arr = Array(repeating: false, count: ticksPerBar)
            switch type {
            case .kick:
                for i in [0,16,32,48] { if i < arr.count { arr[i] = true } }
            case .snare:
                for i in [32,40,48] { if i < arr.count { arr[i] = true } }
            case .hihat:
                for i in stride(from: 0, to: ticksPerBar, by: 8) { arr[i] = true }
            }
            return arr
        }
        let kickBar = PlayableBar(beatsPerBar: beatsPerBar, ticksPerBeat: ticksPerBeat, ticks: defaultPattern(for: .kick))
        let snareBar = PlayableBar(beatsPerBar: beatsPerBar, ticksPerBeat: ticksPerBeat, ticks: defaultPattern(for: .snare))
        let hihatBar = PlayableBar(beatsPerBar: beatsPerBar, ticksPerBeat: ticksPerBeat, ticks: defaultPattern(for: .hihat))

        tracks[.kick] = Track(rolling: RollingBar(beatsPerBar: beatsPerBar, ticksPerBeat: ticksPerBeat, templateBar: kickBar, enabled: true), player: kickPlayer, instrument: KickInstrument(), gain: 1.0)
        tracks[.snare] = Track(rolling: RollingBar(beatsPerBar: beatsPerBar, ticksPerBeat: ticksPerBeat, templateBar: snareBar, enabled: false), player: snarePlayer, instrument: SnareInstrument(), gain: 0.9)
        tracks[.hihat] = Track(rolling: RollingBar(beatsPerBar: beatsPerBar, ticksPerBeat: ticksPerBeat, templateBar: hihatBar, enabled: false), player: hihatPlayer, instrument: HihatInstrument(), gain: 0.4)
    }

    private func generateBar(for type: InstrumentType, enabled: Bool) -> [Bool] {
        guard enabled else { return Array(repeating: false, count: ticksPerBar) }
        switch type {
        case .kick:
            var arr = Array(repeating: false, count: ticksPerBar)
            for i in [0,16,32,48] { if i < arr.count { arr[i] = true } }
            return arr
        case .snare:
            var arr = Array(repeating: false, count: ticksPerBar)
            for i in [32,40,48] { if i < arr.count { arr[i] = true } }
            return arr
        case .hihat:
            var arr = Array(repeating: false, count: ticksPerBar)
            for i in stride(from: 0, to: ticksPerBar, by: 8) { arr[i] = true }
            return arr
        }
    }

    private func onTick() {
        for (_, tr) in tracks {
            if tr.rolling.getNextTick() { playHit(track: tr) }
        }
        let n = ticksPerBar
        globalTick &+= 1
        if globalTick % n == 0 {
            if activeBPM != desiredBPM { activeBPM = desiredBPM; clock.bpm = activeBPM }
        }
    }

    private func playHit(track: Track) {
        let format = engine.outputNode.outputFormat(forBus: 0)
        let sr = format.sampleRate > 0 ? format.sampleRate : 44_100
        let frames = AVAudioFrameCount(sr * 0.25)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        if let cdata = buffer.floatChannelData {
            let channels = Int(format.channelCount == 0 ? 2 : format.channelCount)
            for c in 0..<channels { memset(cdata[c], 0, Int(frames) * MemoryLayout<Float>.size) }
        }
        track.instrument.render(into: buffer, at: 0, sampleRate: sr, maxSamples: Int(frames), gain: track.gain)
        track.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    // MARK: - Desired toggles affect ONLY the next bar region
    private func setDesired(_ on: Bool, for type: InstrumentType) {
        guard var tr = tracks[type] else { return }
        if on { tr.rolling.enable() } else { tr.rolling.disable() }
        tracks[type] = tr
    }
}
