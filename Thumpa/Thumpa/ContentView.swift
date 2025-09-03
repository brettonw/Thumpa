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
                ), in: 70...100, step: 1)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .onDisappear { if isPlaying { PatternEngine.shared.stop(); isPlaying = false } }
        .onChange(of: kickEnabled) { _ in PatternEngine.shared.setPrimaryEnabled(kickEnabled) }
        .onChange(of: snareEnabled) { _ in PatternEngine.shared.setSnareEnabled(snareEnabled) }
        .onReceive(Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()) { _ in
            guard isPlaying else { globalTick = 0; return }
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
                let totalTicks = 128 // 2 bars window
                let spacing: CGFloat = 1
                let rawWidth = (geo.size.width - CGFloat(totalTicks - 1) * spacing) / CGFloat(totalTicks)
                let barWidth = max(4.0, rawWidth) // one more pixel wider
                // Current global tick and center offset from engine
                let currentGlobalTick = globalTick
                let windowStartTick = currentGlobalTick - (totalTicks / 2)
                Canvas { context, size in
                    // Heights: ticks slightly shorter than row; NOW line spans full row height
                    let rowHeight: CGFloat = size.height
                    let barHeight: CGFloat = max(14, rowHeight - 4)
                    let yOffset: CGFloat = (rowHeight - barHeight) / 2
                    // Center mapping for exact alignment
                    let centerX: CGFloat = size.width / 2
                    let strideX: CGFloat = barWidth + spacing
                    // Background grid: beat separators every 16 ticks, bar separators every 64
                    for i in 0..<totalTicks {
                        let globalTick = windowStartTick + i
                        let x = centerX + (CGFloat(i) - CGFloat(totalTicks)/2) * strideX
                        if globalTick % 64 == 0 {
                            let path = Path(CGRect(x: x, y: 0, width: max(spacing, 1), height: rowHeight))
                            context.fill(path, with: .color(Color.secondary.opacity(0.25)))
                        } else if globalTick % 16 == 0 { // beat lines only inside bar
                            let path = Path(CGRect(x: x, y: 0, width: max(spacing, 1), height: rowHeight))
                            context.fill(path, with: .color(Color.secondary.opacity(0.12)))
                        }
                    }

                    // Beat stubs (underlay): low-priority gray bars at each beat
                    for column in 0..<totalTicks {
                        let globalTick = windowStartTick + column
                        guard globalTick % 16 == 0 else { continue }
                        let dist = currentGlobalTick - globalTick // past positive, future negative
                        let half = Double(totalTicks / 2)
                        let alpha: Double = {
                            if dist > 0 { return max(0.0, 0.4 - Double(dist)/half * 0.4) }
                            if dist == 0 { return 0.6 }
                            let t = min(1.0, Double(-dist)/half)
                            return 0.25 * (1.0 - t)
                        }()
                        let x = centerX + (CGFloat(column) - CGFloat(totalTicks)/2) * strideX - barWidth/2
                        let rect = CGRect(x: x, y: yOffset, width: barWidth, height: barHeight)
                        context.fill(Path(rect), with: .color(Color.secondary.opacity(alpha)))
                    }

                    // Instrument hits (overlay): render from the tick window centered on the same snapshot tick
                    let window = PatternEngine.shared.windowForInstrument(title, at: currentGlobalTick)
                    let centerIdx = window.center // 64
                    let ticks = window.ticks // 128 columns
                    for i in 0..<totalTicks {
                        guard ticks.indices.contains(i), ticks[i] else { continue }
                        let dist = centerIdx - i // past positive, future negative
                        let half = Double(totalTicks / 2)
                        let alpha: Double = {
                            if dist > 0 { return max(0.0, 1.0 - Double(dist)/half) }
                            if dist == 0 { return 1.0 }
                            let t = min(1.0, Double(-dist)/half)
                            return 0.2 + 0.5 * (1.0 - t)
                        }()
                        let x = centerX + (CGFloat(i) - CGFloat(totalTicks)/2) * strideX - barWidth/2
                        let rect = CGRect(x: x, y: yOffset, width: barWidth, height: barHeight)
                        context.fill(Path(rect), with: .color(color.opacity(alpha)))
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
                    let strideX = barWidth + spacing
                    let localX = value.location.x
                    // Map tap x to column i (0..127)
                    let iFloat = ((localX + barWidth / 2 - centerX) / strideX) + CGFloat(totalTicks) / 2
                    let i = max(0, min(totalTicks - 1, Int(round(iFloat))))
                    // Only allow editing future (right half)
                    guard i >= totalTicks / 2 else { return }
                    let absTick = windowStartTick + i
                    let tickInBar = ((absTick % 64) + 64) % 64
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

#Preview {
    ContentView()
}
