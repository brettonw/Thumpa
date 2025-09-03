import Foundation
import Testing
@testable import Thumpa

struct RollingBarTests {

  private func templateBar(beats: Int, tpb: Int) -> Bar {
    let n = beats * tpb
    var ticks = Array(repeating: false, count: n)
    for i in stride(from: 0, to: n, by: tpb) { ticks[i] = true }
    return PlayableBar(beatsPerBar: beats, ticksPerBeat: tpb, ticks: ticks)
  }

  @Test
  func rollsFromEmptyToTemplateWhenEnabled() throws {
    let beats = 4, tpb = 4, n = beats * tpb
    let tpl = templateBar(beats: beats, tpb: tpb)
    let rb = RollingBar(beatsPerBar: beats, ticksPerBeat: tpb, templateBar: tpl, enabled: true)

    // First bar is empty
    var first: [Bool] = []
    for _ in 0..<n { first.append(rb.getNextTick()) }
    #expect(first.allSatisfy { $0 == false })

    // Second bar should be the template
    var second: [Bool] = []
    for _ in 0..<n { second.append(rb.getNextTick()) }
    #expect(second == tpl.allTicks())
  }

  @Test
  func enableDisableAffectsNextBarOnly() throws {
    let beats = 4, tpb = 4, n = beats * tpb
    let tpl = templateBar(beats: beats, tpb: tpb)
    let rb = RollingBar(beatsPerBar: beats, ticksPerBeat: tpb, templateBar: tpl, enabled: false)

    // Mid-bar enable: does not affect current bar; affects the next bar
    var currentBarTicks: [Bool] = []
    currentBarTicks.append(rb.getNextTick()) // start current (empty) bar
    rb.enable() // toggle mid-bar
    for _ in 1..<n { currentBarTicks.append(rb.getNextTick()) }
    #expect(currentBarTicks.allSatisfy { $0 == false })

    // Next bar should now be template
    let enabledBar: [Bool] = (0..<n).map { _ in rb.getNextTick() }
    #expect(enabledBar == tpl.allTicks())

    // Mid-bar disable: does not affect current (template) bar; next bar becomes empty
    var afterDisableCurrent: [Bool] = []
    afterDisableCurrent.append(rb.getNextTick()) // start next (template) bar
    rb.disable()
    for _ in 1..<n { afterDisableCurrent.append(rb.getNextTick()) }
    #expect(afterDisableCurrent == tpl.allTicks())

    let disabledBar: [Bool] = (0..<n).map { _ in rb.getNextTick() }
    #expect(disabledBar.allSatisfy { $0 == false })
  }

  @Test
  func getDisplayShowsPrevAndNext() throws {
    let beats = 4, tpb = 4, n = beats * tpb
    let tpl = templateBar(beats: beats, tpb: tpb)
    let rb = RollingBar(beatsPerBar: beats, ticksPerBeat: tpb, templateBar: tpl, enabled: true)

    // Initially: prev empty, future is current (empty), not template yet
    let initial = rb.getDisplay()
    #expect(initial.count == 2 * n)
    #expect(Array(initial[0..<n]).allSatisfy { $0 == false })
    #expect(Array(initial[n..<(2*n)]).allSatisfy { $0 == false })

    // Advance half a bar; future should now be half current remainder + half next (template)
    let half = n / 2
    _ = (0..<half).map { _ in rb.getNextTick() }
    let mid = rb.getDisplay()
    let expectedFuture = Array(repeating: false, count: n - half) + Array(tpl.allTicks().prefix(half))
    #expect(Array(mid[n..<(2*n)]) == expectedFuture)

    // Consume the rest of the empty current bar; now future should equal template fully
    _ = (half..<n).map { _ in rb.getNextTick() }
    let afterOne = rb.getDisplay()
    #expect(Array(afterOne[0..<n]).allSatisfy { $0 == false }) // past = empty previous
    #expect(Array(afterOne[n..<(2*n)]) == tpl.allTicks())
  }

  @Test
  func emptyBarIsSingletonPerParameters() throws {
    let beats = 4, tpb = 4
    let tpl1 = templateBar(beats: beats, tpb: tpb)
    let tpl2 = templateBar(beats: beats, tpb: tpb)
    let rb1 = RollingBar(beatsPerBar: beats, ticksPerBeat: tpb, templateBar: tpl1, enabled: false)
    let rb2 = RollingBar(beatsPerBar: beats, ticksPerBeat: tpb, templateBar: tpl2, enabled: true)
    // Same identity for the cached empty bar with same parameters
    #expect((rb1.emptyBar as AnyObject) === (rb2.emptyBar as AnyObject))
  }
}
