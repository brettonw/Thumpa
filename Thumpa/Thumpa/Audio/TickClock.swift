import Foundation

final class TickClock {
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "clock.tick.queue", qos: .userInteractive)

    var bpm: Double { didSet { updateTimer() } }
    var ticksPerBeat: Int = 16 { didSet { updateTimer() } }

    var onTick: (() -> Void)?

    init(bpm: Double) {
        self.bpm = bpm
    }

    func start() {
        stop()
        createTimer()
        timer?.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func createTimer() {
        let interval = tickInterval()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in self?.onTick?() }
        timer = t
    }

    private func updateTimer() {
        guard let timer else { return }
        let interval = tickInterval()
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(1))
    }

    private func tickInterval() -> DispatchTimeInterval {
        // 16 ticks per beat => ticks per second = bpm/60 * 16
        let tickSeconds = (60.0 / max(1.0, bpm)) / Double(max(1, ticksPerBeat))
        return .nanoseconds(Int(tickSeconds * 1_000_000_000))
    }
}

