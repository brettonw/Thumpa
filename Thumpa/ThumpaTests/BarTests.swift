import Foundation
import Testing
@testable import Thumpa

struct BarTests {

  @Test
  func emptyBar_iteratesFalseAndFinishes() throws {
    let bar = Bar(beatsPerBar: 4, ticksPerBeat: 4) // 16 ticks
    var it = bar.makeIterator()
    var values: [Bool] = []
    while let v = it.next() { values.append(v) }
    #expect(values.count == 16)
    #expect(values.allSatisfy { $0 == false })
    #expect(it.isFinished == true)
  }

  @Test
  func playableBar_returnsStoredPattern() throws {
    let beats = 4, tpb = 4, n = beats * tpb
    var ticks = Array(repeating: false, count: n)
    for i in stride(from: 0, to: n, by: tpb) { ticks[i] = true }
    let bar = PlayableBar(beatsPerBar: beats, ticksPerBeat: tpb, ticks: ticks)

    // Direct indexing
    for i in 0..<n {
      #expect(bar.getTick(i) == ticks[i])
    }

    // Iterator order
    var it = bar.makeIterator()
    var iterVals: [Bool] = []
    while let v = it.next() { iterVals.append(v) }
    #expect(iterVals == ticks)
    #expect(it.isFinished == true)
  }
}
