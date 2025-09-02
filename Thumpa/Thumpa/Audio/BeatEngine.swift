import Foundation
import QuartzCore
import AVFoundation

final class BeatEngine {
    static let shared = BeatEngine()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isConfigured = false

    // Public state
    private(set) var isPlaying: Bool = false
    private(set) var bpm: Double = 90 // Default Kizomba tempo
    private let beatsPerMeasure = 4
    private var primaryEnabled = true
    private var snareEnabled = false
    private var instruments: [BeatInstrument] = [KickInstrument()] // index 0: primary
    private var pendingRebuild = false
    private var measureBuffer: AVAudioPCMBuffer?
    private var measureStartTime: CFTimeInterval?

    private init() {}

    func start() {
        guard !isPlaying else { return }
        do {
            try configureSession()
            try configureEngineIfNeeded()
            try startEngineIfNeeded()

            rebuildMeasureBuffer()
            // Queue one measure; the completion schedules the next just-in-time
            scheduleCurrentMeasure()
            player.play()
            isPlaying = true
        } catch {
            print("BeatEngine start error: \(error)")
        }
    }

    func stop() {
        guard isPlaying else { return }
        player.stop()
        // Don't stop the engine to allow fast resume; just unschedule.
        isPlaying = false
        measureStartTime = nil
    }

    func setBPM(_ newValue: Double) {
        let clamped = max(20, min(300, newValue))
        guard clamped != bpm else { return }
        bpm = clamped
        pendingRebuild = true
    }

    func setPrimaryInstrument(_ instrument: BeatInstrument) {
        if instruments.isEmpty {
            instruments = [instrument]
        } else {
            instruments[0] = instrument
        }
        instruments[0] = instrument
        pendingRebuild = true
    }

    func setOverlayInstruments(_ overlays: [BeatInstrument]) {
        instruments = [instruments.first ?? KickInstrument()] + overlays
        pendingRebuild = true
    }

    func setPrimaryEnabled(_ enabled: Bool) {
        primaryEnabled = enabled
        pendingRebuild = true
    }

    func setSnareEnabled(_ enabled: Bool) {
        snareEnabled = enabled
        pendingRebuild = true
    }

    // MARK: - Private

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true, options: [])
    }

    private func configureEngineIfNeeded() throws {
        guard !isConfigured else { return }
        engine.attach(player)
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)
        isConfigured = true
    }

    private func startEngineIfNeeded() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }

    private func scheduleLoopingBeat() {
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44_100.0
        let channels = Int(outputFormat.channelCount == 0 ? 2 : outputFormat.channelCount)

        let secondsPerBeat = 60.0 / max(1.0, bpm)
        let samplesPerBeat = Int(round(sampleRate * secondsPerBeat))
        let measureSamples = samplesPerBeat * beatsPerMeasure

        let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(measureSamples))!
        buffer.frameLength = AVAudioFrameCount(measureSamples)

        if let channelData = buffer.floatChannelData {
            for c in 0..<channels { memset(channelData[c], 0, measureSamples * MemoryLayout<Float>.size) }
        }

        // Primary kick pattern: hits on 1-2-3-4 with heavier downbeat
        if primaryEnabled, let kick = instruments.first as? KickInstrument {
            let gains: [Double] = [1.0, 0.85, 0.85, 0.95]
            for beat in 0..<beatsPerMeasure {
                let offset = beat * samplesPerBeat
                kick.render(into: buffer, at: offset, sampleRate: sampleRate, maxSamples: measureSamples, gain: gains[beat])
            }
        }

        // Optional snare overlay: beats 3, 3.5, and 4 (1-based). In 0-based: 2.0, 2.5, 3.0
        if snareEnabled {
            let snare = SnareInstrument()
            let positions: [Double] = [2.0, 2.5, 3.0]
            for pos in positions {
                let offsetSamples = Int(round(pos * Double(samplesPerBeat)))
                let clamped = min(max(0, offsetSamples), measureSamples - 1)
                snare.render(into: buffer, at: clamped, sampleRate: sampleRate, maxSamples: measureSamples, gain: 0.9)
            }
        }

        measureBuffer = buffer
    }

    private func rebuildMeasureBuffer() {
        scheduleLoopingBeat()
    }

    private func scheduleCurrentMeasure() {
        guard let buffer = measureBuffer else { return }
        measureStartTime = CACurrentMediaTime()
        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            guard let self else { return }
            if self.pendingRebuild {
                self.rebuildMeasureBuffer()
                self.pendingRebuild = false
            }
            // Keep queue primed by scheduling the next measure
            self.scheduleCurrentMeasure()
        }
    }

    // MARK: - Timeline
    var secondsPerMeasure: Double {
        (60.0 / max(1.0, bpm)) * Double(beatsPerMeasure)
    }

    func currentMeasureProgress() -> Double {
        guard let start = measureStartTime else { return 0 }
        let now = CACurrentMediaTime()
        let progress = (now - start) / max(0.0001, secondsPerMeasure)
        // Clamp to 0..1; since we reschedule per measure, progress should stay within [0,1)
        return max(0.0, min(1.0, progress))
    }
}
