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
    @State private var measureProgress: Double = 0 // 0..1 visual progress

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

            // Instrument controls
            VStack(alignment: .leading, spacing: 12) {
                InstrumentRow(title: "Kick",
                               isOn: $kickEnabled,
                               color: .kickColor,
                               measureProgress: measureProgress,
                               pattern64: Self.kickPattern64,
                               onToggle: { BeatEngine.shared.setPrimaryEnabled(kickEnabled) })
                InstrumentRow(title: "Snare",
                               isOn: $snareEnabled,
                               color: .snareColor,
                               measureProgress: measureProgress,
                               pattern64: Self.snarePattern64,
                               onToggle: { BeatEngine.shared.setSnareEnabled(snareEnabled) })
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
                        BeatEngine.shared.setBPM(newVal)
                    }
                ), in: 70...100, step: 1)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .onDisappear { if isPlaying { BeatEngine.shared.stop(); isPlaying = false } }
        .onChange(of: kickEnabled) { _ in BeatEngine.shared.setPrimaryEnabled(kickEnabled) }
        .onChange(of: snareEnabled) { _ in BeatEngine.shared.setSnareEnabled(snareEnabled) }
        .onReceive(Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()) { _ in
            guard isPlaying else { measureProgress = 0; return }
            measureProgress = BeatEngine.shared.currentMeasureProgress()
        }
    }

    private func toggle() {
        if isPlaying {
            BeatEngine.shared.stop()
            isPlaying = false
        } else {
            BeatEngine.shared.setBPM(bpm)
            BeatEngine.shared.start()
            isPlaying = true
            measureProgress = 0
        }
    }
}

private struct InstrumentRow: View {
    let title: String
    @Binding var isOn: Bool
    var color: Color
    var measureProgress: Double // 0..1 across 4 beats
    var pattern64: [Bool] // length 64: true when instrument hits at that tick
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                isOn.toggle()
                onToggle()
            }) {
                Circle()
                    .fill(isOn ? color : Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.4))
                    )
                    .accessibilityLabel(Text(isOn ? "Disable \(title)" : "Enable \(title)"))
            }
            .buttonStyle(.plain)

            Text(title).frame(width: 110, alignment: .leading)

            GeometryReader { geo in
                let totalTicks = 64
                let spacing: CGFloat = 1
                let barWidth = (geo.size.width - CGFloat(totalTicks - 1) * spacing) / CGFloat(totalTicks)
                let currentStep = max(0, min(totalTicks - 1, Int(floor(measureProgress * Double(totalTicks)))))
                Canvas { context, size in
                    // Background grid: beat separators every 16 ticks
                    let height: CGFloat = 12
                    for beat in 0..<4 {
                        let x = (CGFloat(beat * 16) * (barWidth + spacing))
                        let path = Path(CGRect(x: x, y: 0, width: max(spacing, 1), height: height))
                        context.fill(path, with: .color(Color.secondary.opacity(0.15)))
                    }

                    // Prefill scheduled hits (desaturated)
                    for idx in 0..<totalTicks {
                        let isHit = isOn && pattern64[idx]
                        if isHit {
                            let x = CGFloat(idx) * (barWidth + spacing)
                            let rect = CGRect(x: x, y: 0, width: barWidth, height: height)
                            context.fill(Path(rect), with: .color(color.opacity(idx == currentStep ? 1.0 : 0.35)))
                        }
                    }

                    // Current cursor line across the row
                    let cursorX = CGFloat(currentStep) * (barWidth + spacing)
                    let cursorRect = CGRect(x: cursorX, y: 0, width: max(2, spacing), height: height)
                    context.fill(Path(cursorRect), with: .color(Color.primary.opacity(0.6)))
                }
            }
            .frame(height: 12)
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
}

private extension Color {
    static var kickColor: Color { Color(red: 0.95, green: 0.25, blue: 0.35) } // red-ish
    static var snareColor: Color { Color(red: 0.70, green: 0.30, blue: 0.90) } // magenta-ish
}

#Preview {
    ContentView()
}
