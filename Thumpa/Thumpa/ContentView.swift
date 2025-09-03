//
//  ContentView.swift
//  Thumpa
//
//  Created by Bretton Wade on 8/27/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var isPlaying = false
    @State private var bpm: Double = 90
    @State private var kickEnabled = true
    @State private var snareEnabled = false
    @State private var hihatEnabled = false
    @State private var globalTick: Int = 0 // advancing tick counter

    var body: some View {
        VStack(spacing: 24) {
            Text("Thumpa")
                .font(.largeTitle).bold()
            Text("Kizomba beat • \(Int(bpm)) BPM")
                .foregroundStyle(.secondary)

            Button(action: toggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(isPlaying ? Color.red : Color.green)
                    .frame(width: 56, height: 56)
                    .background((isPlaying ? Color.red.opacity(0.15) : Color.green.opacity(0.15)))
                    .clipShape(Circle())
                    .accessibilityLabel(isPlaying ? Text("Pause") : Text("Play"))
            }
            .buttonStyle(.plain)

            // Instrument table (each row has header + full-width graph below)
            VStack(alignment: .leading, spacing: 24) {
                InstrumentRow(title: "Kick",
                               isOn: $kickEnabled,
                               color: .kickColor,
                               globalTick: globalTick,
                               pattern64: Self.kickPattern64,
                               onToggle: { PatternEngine.shared.setPrimaryEnabled(kickEnabled) })
                InstrumentRow(title: "Snare",
                               isOn: $snareEnabled,
                               color: .snareColor,
                               globalTick: globalTick,
                               pattern64: Self.snarePattern64,
                               onToggle: { PatternEngine.shared.setSnareEnabled(snareEnabled) })
                InstrumentRow(title: "Hi‑Hat",
                               isOn: $hihatEnabled,
                               color: .hihatColor,
                               globalTick: globalTick,
                               pattern64: Self.hihatPattern64,
                               onToggle: { PatternEngine.shared.setHihatEnabled(hihatEnabled) })
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tempo")
                    Spacer()
                    Text("\(Int(bpm)) BPM").monospacedDigit()
                }
                Slider(value: Binding(
                    get: { bpm },
                    set: { newVal in
                        bpm = newVal
                        PatternEngine.shared.setBPM(newVal)
                    }
                ), in: 70...120, step: 1)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .onDisappear { if isPlaying { PatternEngine.shared.stop(); isPlaying = false } }
        .onChange(of: kickEnabled) { _ in PatternEngine.shared.setPrimaryEnabled(kickEnabled) }
        .onChange(of: snareEnabled) { _ in PatternEngine.shared.setSnareEnabled(snareEnabled) }
        .onReceive(Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()) { _ in
            guard isPlaying else { return }
            globalTick = PatternEngine.shared.currentTicks().globalTick
        }
    }

    private func toggle() {
        if isPlaying {
            PatternEngine.shared.stop()
            isPlaying = false
        } else {
            PatternEngine.shared.setBPM(bpm)
            PatternEngine.shared.start()
            isPlaying = true
        }
    }
}

private struct InstrumentRow: View {
    let title: String
    @Binding var isOn: Bool
    var color: Color
    var globalTick: Int // absolute tick position
    var pattern64: [Bool] // length 64: true when instrument hits at that tick
    var onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button(action: {
                    isOn.toggle()
                    onToggle()
                }) {
                    Circle()
                        .fill(isOn ? color : Color.gray.opacity(0.3))
                        .frame(width: 17, height: 17)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.secondary.opacity(0.4))
                        )
                        .accessibilityLabel(Text(isOn ? "Disable \(title)" : "Enable \(title)"))
                }
                .buttonStyle(.plain)

                Text(title)
                    .font(.subheadline)
                    .frame(alignment: .leading)
            }
            GeometryReader { geo in
                let beats = PatternEngine.shared.beatsPerBarCount
                let tpb = PatternEngine.shared.ticksPerBeatCount
                let ticksPerBar = beats * tpb
                let totalTicks = ticksPerBar * 2 // 2-bar window
                let colSpacing: CGFloat = 2
                let strideX: CGFloat = max(3, (geo.size.width - CGFloat(totalTicks - 1) * colSpacing) / CGFloat(totalTicks)) + colSpacing
                // Current global tick
                let currentGlobalTick = globalTick
                Canvas { context, size in
                    // Layout
                    let rowHeight: CGFloat = size.height
                    let centerX: CGFloat = size.width / 2
                    let half = CGFloat(ticksPerBar)
                    // Snapshot the engine window once so grid and hits align, even when paused
                    let window = PatternEngine.shared.windowForInstrument(title, at: currentGlobalTick)
                    let centerIdx = window.center // ticksPerBar
                    let ticks = window.ticks // 2 * ticksPerBar

                    // Beat stubs (underlay): opacity fades with distance from center
                    for column in 0..<totalTicks {
                        let rel = column - centerIdx
                        guard rel % tpb == 0 else { continue }
                        // Normalize distance per side so edges fade to 0 exactly
                        let dist = abs(column - centerIdx)
                        let denom: CGFloat = column <= centerIdx ? CGFloat(ticksPerBar) : CGFloat(ticksPerBar - 1)
                        let nd = min(1.0, CGFloat(dist) / denom) // 0 at center, 1 at far edge
                        let alpha = max(0.0, 1.0 - Double(nd)) * 0.6 // cap stubs at 60% max
                        let x = centerX + (CGFloat(column) - CGFloat(totalTicks)/2) * strideX
                        let path = Path(CGRect(x: x, y: 0, width: 1, height: rowHeight))
                        context.fill(path, with: .color(Color.secondary.opacity(alpha)))
                    }

                    // Instrument hits (overlay): render from the tick window centered on the same snapshot tick
                    // Size behavior: base size on the right (future). On the left (past), scale up
                    // to a peak at the center (now), then fall back toward base with the same curve as alpha.
                    // Peak (at now) matches previous visual; base is ~1/3 of peak.
                    let baseProposed = max(3, min(rowHeight * 0.9, strideX * 1.05))
                    let doubledBase = min(rowHeight * 0.95, baseProposed * 2)
                    let peakDiameterRaw = min(rowHeight * 0.98, doubledBase * 2)
                    let baseDiameterRaw = max(3, peakDiameterRaw / 3)
                    let centerY = rowHeight / 2
                    for i in 0..<min(totalTicks, ticks.count) {
                        guard ticks[i] else { continue }
                        // Normalize distance per side so edges fade to 0 exactly
                        let dist = abs(i - centerIdx)
                        let denom: CGFloat = i <= centerIdx ? CGFloat(ticksPerBar) : CGFloat(ticksPerBar - 1)
                        let nd = min(1.0, CGFloat(dist) / denom) // 0..1
                        let alpha = max(0.0, 1.0 - Double(nd))
                        let isFuture = i > centerIdx
                        // Unscaled on the right side (future): always base.
                        // On the left (past + now): interpolate from base at the far left to peak at center.
                        var diameter: CGFloat
                        if isFuture {
                            diameter = baseDiameterRaw
                        } else {
                            let t = 1.0 - CGFloat(nd) // 1 at center, 0 at far left
                            diameter = baseDiameterRaw + (peakDiameterRaw - baseDiameterRaw) * (t * t * t)
                        }
                        diameter = min(diameter, rowHeight * 0.98)
                        var intD = max(3, Int(diameter.rounded()))
                        if intD % 2 == 0 { intD += 1 } // ensure odd so center aligns on grid
                        let circleDiameter = CGFloat(intD)
                        let circleRadius = circleDiameter / 2
                        let xCenter = centerX + (CGFloat(i) - CGFloat(totalTicks)/2) * strideX
                        let rect = CGRect(x: xCenter - circleRadius, y: centerY - circleRadius, width: circleDiameter, height: circleDiameter)
                        // Future ticks desaturated more strongly
                        let baseColor = color
                        let drawColor = isFuture ? baseColor.desaturated(0.80) : baseColor
                        context.fill(Path(ellipseIn: rect), with: .color(drawColor.opacity(alpha)))
                    }

                    // NOW line per row: thinner than ticks, full row height
                    let cursorX = centerX
                    let cursorRect = CGRect(x: cursorX, y: 0, width: 1, height: rowHeight)
                    context.fill(Path(cursorRect), with: .color(Color.primary))
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                    let width = geo.size.width
                    let centerX = width / 2
                    let localX = value.location.x
                    // Map tap x to column i (0..127)
                    let iFloat = ((localX - centerX) / strideX) + CGFloat(totalTicks) / 2
                    let i = max(0, min(totalTicks - 1, Int(round(iFloat))))
                    // Only allow editing future (right half)
                    guard i >= totalTicks / 2 else { return }
                    let relFromCenter = i - ticksPerBar
                    let tickInBar = ((relFromCenter % ticksPerBar) + ticksPerBar) % ticksPerBar
                    PatternEngine.shared.toggleNextBarTick(title, tickInBar: tickInBar)
                })
            }
            .frame(height: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension ContentView {
    // 64 ticks per measure (16 ticks per beat)
    static var kickPattern64: [Bool] {
        var arr = Array(repeating: false, count: 64)
        for idx in [0,16,32,48] { arr[idx] = true }
        return arr
    }
    static var snarePattern64: [Bool] {
        var arr = Array(repeating: false, count: 64)
        for idx in [32,40,48] { arr[idx] = true }
        return arr
    }
    static var hihatPattern64: [Bool] {
        var arr = Array(repeating: false, count: 64)
        for idx in stride(from: 0, to: 64, by: 8) { arr[idx] = true }
        return arr
    }
}

private extension Color {
    static var kickColor: Color { Color(red: 0.95, green: 0.25, blue: 0.35) } // red-ish
    static var snareColor: Color { Color(red: 0.70, green: 0.30, blue: 0.90) } // magenta-ish
    static var hihatColor: Color { Color(red: 0.25, green: 0.55, blue: 0.95) } // blue-ish
}

// MARK: - Color utilities
import UIKit
private extension Color {
    func desaturated(_ factor: CGFloat) -> Color {
        let clampFactor = max(0, min(1, factor))
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            // Fall back by blending toward gray
            let grayBlend: CGFloat = clampFactor
            let comps = ui.cgColor.components ?? [0,0,0,1]
            let r = comps[0] * (1 - grayBlend) + 0.5 * grayBlend
            let g = (comps.count > 1 ? comps[1] : comps[0]) * (1 - grayBlend) + 0.5 * grayBlend
            let bl = (comps.count > 2 ? comps[2] : comps[0]) * (1 - grayBlend) + 0.5 * grayBlend
            return Color(UIColor(red: r, green: g, blue: bl, alpha: a))
        }
        let newS = s * (1 - clampFactor)
        return Color(UIColor(hue: h, saturation: newS, brightness: b, alpha: a))
    }
}

#Preview {
    ContentView()
}
