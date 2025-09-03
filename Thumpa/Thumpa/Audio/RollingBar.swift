import Foundation

// Rolling bar for an instrument: keeps previous, current, next bars and
// produces a continuous stream of ticks by iterating current and rolling
// pointers at bar boundaries.
final class RollingBar {
  let beatsPerBar: Int
  let ticksPerBeat: Int

  private(set) var previousBar: Bar
  private(set) var currentBar: Bar
  private(set) var nextBar: Bar

  private var currentIterator: BarIterator
  private var currentOffset: Int = 0 // number of ticks consumed in currentBar

  private(set) var enabled: Bool

  let templateBar: Bar
  let emptyBar: Bar // singleton instance for these parameters

  // Cache single EmptyBar per (beatsPerBar, ticksPerBeat)
  private static var emptyCache = [String: Bar]()
  private static func key(b: Int, t: Int) -> String { "\(b)x\(t)" }
  private static func sharedEmptyBar(beatsPerBar: Int, ticksPerBeat: Int) -> Bar {
    let k = key(b: beatsPerBar, t: ticksPerBeat)
    if let e = emptyCache[k] { return e }
    let e = Bar(beatsPerBar: beatsPerBar, ticksPerBeat: ticksPerBeat)
    emptyCache[k] = e
    return e
  }

  init(beatsPerBar: Int, ticksPerBeat: Int, templateBar: Bar, enabled: Bool) {
    precondition(templateBar.beatsPerBar == beatsPerBar && templateBar.ticksPerBeat == ticksPerBeat,
                 "Template bar parameters must match")
    self.beatsPerBar = beatsPerBar
    self.ticksPerBeat = ticksPerBeat
    self.templateBar = templateBar
    self.enabled = enabled
    self.emptyBar = RollingBar.sharedEmptyBar(beatsPerBar: beatsPerBar, ticksPerBeat: ticksPerBeat)

    // Start with current as empty, next as enabled ? template : empty
    self.previousBar = self.emptyBar
    self.currentBar = self.emptyBar
    self.nextBar = enabled ? templateBar : self.emptyBar
    self.currentIterator = self.currentBar.makeIterator()
    self.currentOffset = 0
  }

  // Returns the next tick from current bar, rolling bars at the boundary.
  func getNextTick() -> Bool {
    if let v = currentIterator.next() {
      currentOffset += 1
      return v
    }
    rollBars()
    // After rolling, start of a new current bar.
    if let v = currentIterator.next() {
      currentOffset = 1
      return v
    }
    return false
  }

  // Enable: ensure next bar is the template.
  func enable() {
    enabled = true
    nextBar = templateBar
  }

  // Disable: ensure next bar is empty.
  func disable() {
    enabled = false
    nextBar = emptyBar
  }

  // Prime the current bar to reflect the enabled state immediately (used at start).
  func primeCurrentToTemplateIfEnabled() {
    currentBar = enabled ? templateBar : emptyBar
    currentIterator = currentBar.makeIterator()
    currentOffset = 0
  }

  // Toggle a tick in the next bar only (one-shot edit).
  // Returns true if the toggle was applied, false if the index was out of range.
  @discardableResult
  func toggleNextBarTick(_ index: Int) -> Bool {
    let n = beatsPerBar * ticksPerBeat
    guard (0..<n).contains(index) else { return false }
    var nextTicks = nextBar.allTicks()
    if nextTicks.count != n { nextTicks = Array(repeating: false, count: n) }
    nextTicks[index].toggle()
    nextBar = PlayableBar(beatsPerBar: beatsPerBar, ticksPerBeat: ticksPerBeat, ticks: nextTicks)
    return true
  }

  // Returns the last N ticks (previous bar) concatenated with the next N ticks (next bar),
  // where N = beatsPerBar * ticksPerBeat.
  func getDisplay() -> [Bool] {
    // Return a 2-bar window: the last N ticks before the current position
    // and the next N ticks starting from the current position.
    let n = beatsPerBar * ticksPerBeat

    // Past N ticks: tail of previousBar (N - currentOffset) + head of currentBar (currentOffset)
    let pastFromPrevCount = max(0, n - currentOffset)
    let pastFromCurrCount = min(currentOffset, n)
    let pastPrev = pastFromPrevCount > 0 ? previousBar.copyFrom(n - pastFromPrevCount) : []
    let pastCurr = pastFromCurrCount > 0 ? currentBar.copyPrefix(pastFromCurrCount) : []

    // Next N ticks: remainder of currentBar (n - currentOffset) + head of nextBar (currentOffset)
    let futureFromCurrCount = max(0, n - currentOffset)
    let futureFromNextCount = min(currentOffset, n)
    let futureCurr = futureFromCurrCount > 0 ? currentBar.copyFrom(currentOffset) : []
    let futureNext = futureFromNextCount > 0 ? nextBar.copyPrefix(futureFromNextCount) : []

    return pastPrev + pastCurr + futureCurr + futureNext
  }

  // Advance bar pointers when current finishes.
  private func rollBars() {
    previousBar = currentBar
    currentBar = nextBar
    nextBar = enabled ? templateBar : emptyBar
    currentIterator = currentBar.makeIterator()
    currentOffset = 0
  }
}
