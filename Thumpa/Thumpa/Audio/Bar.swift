import Foundation

// Bar represents a fixed number of ticks. By default it behaves as an
// "empty" bar (all ticks false). Subclasses like PlayableBar override
// getTick(_:) to provide data.
class Bar: Sequence {
  let beatsPerBar: Int
  let ticksPerBeat: Int

  var totalTicks: Int { beatsPerBar * ticksPerBeat }

  init(beatsPerBar: Int, ticksPerBeat: Int) {
    precondition(beatsPerBar > 0 && ticksPerBeat > 0, "Bar parameters must be positive")
    self.beatsPerBar = beatsPerBar
    self.ticksPerBeat = ticksPerBeat
  }

  // Default implementation: empty bar (all false). Subclasses override.
  func getTick(_ index: Int) -> Bool {
    precondition(index >= 0 && index < totalTicks, "Tick index out of range")
    return false
  }

  // Iterator over ticks from 0..<totalTicks
  func makeIterator() -> BarIterator {
    BarIterator(bar: self)
  }

  // Convenience snapshot of all ticks.
  func allTicks() -> [Bool] {
    var result: [Bool] = []
    result.reserveCapacity(totalTicks)
    for i in 0..<totalTicks { result.append(getTick(i)) }
    return result
  }

  // Copy a contiguous range of ticks [start, start+count).
  func copyRange(start: Int, count: Int) -> [Bool] {
    precondition(start >= 0 && count >= 0 && start + count <= totalTicks, "Range out of bounds")
    var out: [Bool] = []
    out.reserveCapacity(count)
    if count == 0 { return out }
    for i in start..<(start + count) { out.append(getTick(i)) }
    return out
  }

  // Copy from an index to the end of the bar.
  func copyFrom(_ start: Int) -> [Bool] {
    precondition(start >= 0 && start <= totalTicks, "Start out of bounds")
    return copyRange(start: start, count: totalTicks - start)
  }

  // Copy the first 'count' ticks from the beginning of the bar.
  func copyPrefix(_ count: Int) -> [Bool] {
    precondition(count >= 0 && count <= totalTicks, "Count out of bounds")
    return copyRange(start: 0, count: count)
  }
}

// Iterator that walks a Bar's ticks and indicates completion via nil.
struct BarIterator: IteratorProtocol {
  private let bar: Bar
  private var index: Int = 0

  init(bar: Bar) { self.bar = bar }

  var isFinished: Bool { index >= bar.totalTicks }

  mutating func next() -> Bool? {
    guard index < bar.totalTicks else { return nil }
    let value = bar.getTick(index)
    index += 1
    return value
  }
}

// PlayableBar stores tick data and returns it by index.
final class PlayableBar: Bar {
  private let ticks: [Bool]

  init(beatsPerBar: Int, ticksPerBeat: Int, ticks: [Bool]) {
    let expected = beatsPerBar * ticksPerBeat
    precondition(ticks.count == expected, "ticks must have exactly beatsPerBar * ticksPerBeat elements")
    self.ticks = ticks
    super.init(beatsPerBar: beatsPerBar, ticksPerBeat: ticksPerBeat)
  }

  override func getTick(_ index: Int) -> Bool {
    precondition(index >= 0 && index < totalTicks, "Tick index out of range")
    return ticks[index]
  }

  override func allTicks() -> [Bool] { ticks }
}
