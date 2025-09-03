import Foundation
import AVFoundation

protocol BeatInstrument {
    // Render a single hit starting at the given offset in samples.
    // Implementations should mix into the buffer in-place and must not
    // write past maxSamples.
    func render(into buffer: AVAudioPCMBuffer,
                at offsetSamples: Int,
                sampleRate: Double,
                maxSamples: Int,
                gain: Double)
}

// MARK: - Kick (primary beat) with extra punch
final class KickInstrument: BeatInstrument {
    var amplitude: Double = 1.2
    var duration: Double = 0.22 // seconds
    var startFreq: Double = 140 // Hz
    var endFreq: Double = 45 // Hz
    var drive: Double = 2.4 // soft saturation amount

    func render(into buffer: AVAudioPCMBuffer, at offsetSamples: Int, sampleRate: Double, maxSamples: Int, gain: Double) {
        let channels = Int(max(1, buffer.format.channelCount))
        let hitSamples = min(max(0, maxSamples - offsetSamples), Int(duration * sampleRate))
        let attackSamples = max(1, Int(0.003 * sampleRate)) // 3ms attack
        let decayTau = duration / 3.5

        // Add a subtle click/transient using a very short noise burst
        let clickSamples = max(1, Int(0.004 * sampleRate)) // tighter 4ms click

        guard let cdata = buffer.floatChannelData else { return }
        for ch in 0..<channels {
            let ptr = cdata[ch]
            var phase: Double = 0
            for i in 0..<hitSamples {
                let t = Double(i) / sampleRate
                let k = t / max(0.0001, duration)
                let freq = startFreq + (endFreq - startFreq) * k
                phase += 2.0 * .pi * freq / sampleRate
                let env = exp(-t / max(0.0001, decayTau))
                let att = i < attackSamples ? Double(i) / Double(attackSamples) : 1.0

                var sample = sin(phase)

                // Stronger sub reinforcement (first 40ms ~45-55Hz)
                if i < Int(0.04 * sampleRate) { // first 40ms
                    sample += 0.9 * sin(2.0 * .pi * 52.0 * t)
                }

                // Click/transient: tiny noise burst at start
                if i < clickSamples {
                    let noise = (Double.random(in: -1...1)) * 0.15 * (1.0 - Double(i) / Double(clickSamples))
                    sample += noise
                }

                // Soft saturation for punch
                sample = tanh(sample * drive)

                // Gentle lowpass tilt by mixing with a slightly delayed sample (poor-man's filter)
                let delayed = i > 0 ? Double(ptr[offsetSamples + i - 1]) : 0
                let lowTilt = 0.85 * sample + 0.15 * delayed
                let out = Float(amplitude * gain * att * env * lowTilt)
                ptr[offsetSamples + i] += out
            }
        }
    }
}

// MARK: - Snare-like instrument (for future overlay)
final class SnareInstrument: BeatInstrument {
    var amplitude: Double = 0.7
    var duration: Double = 0.12 // seconds

    func render(into buffer: AVAudioPCMBuffer, at offsetSamples: Int, sampleRate: Double, maxSamples: Int, gain: Double) {
        let channels = Int(max(1, buffer.format.channelCount))
        let hitSamples = min(max(0, maxSamples - offsetSamples), Int(duration * sampleRate))
        let attackSamples = max(1, Int(0.002 * sampleRate))
        let decayTau = duration / 2.5

        guard let cdata = buffer.floatChannelData else { return }
        for ch in 0..<channels {
            let ptr = cdata[ch]
            for i in 0..<hitSamples {
                let t = Double(i) / sampleRate
                let att = i < attackSamples ? Double(i) / Double(attackSamples) : 1.0
                let env = exp(-t / max(0.0001, decayTau))
                // Bright noise with a hint of tone (~1800Hz)
                let noise = Double.random(in: -1...1)
                let tone = sin(2.0 * .pi * 1800.0 * (Double(i) / sampleRate)) * 0.1
                let s = (0.9 * noise + 0.1 * tone) * att * env * amplitude * gain
                ptr[offsetSamples + i] += Float(s)
            }
        }
    }
}

// MARK: - Hi-hat (closed)
final class HihatInstrument: BeatInstrument {
    var amplitude: Double = 0.25 // ~50% of previous
    var duration: Double = 0.04 // shorter, crisper

    func render(into buffer: AVAudioPCMBuffer, at offsetSamples: Int, sampleRate: Double, maxSamples: Int, gain: Double) {
        let channels = Int(max(1, buffer.format.channelCount))
        let hitSamples = min(max(0, maxSamples - offsetSamples), Int(duration * sampleRate))
        let attackSamples = max(1, Int(0.0005 * sampleRate)) // faster attack
        let decayTau = duration / 2.5 // quicker decay

        guard let cdata = buffer.floatChannelData else { return }
        for ch in 0..<channels {
            let ptr = cdata[ch]
            for i in 0..<hitSamples {
                let t = Double(i) / sampleRate
                let att = i < attackSamples ? Double(i) / Double(attackSamples) : 1.0
                let env = exp(-t / max(0.0001, decayTau))
                // Bright filtered noise ~ high-pass feel
                let noise = Double.random(in: -1...1)
                // Emphasize highs by subtracting a smoothed version (stronger high-pass)
                let prev = i > 0 ? Double(ptr[offsetSamples + i - 1]) : 0.0
                let bright = noise - 0.7 * prev
                let s = bright * att * env * amplitude * gain
                ptr[offsetSamples + i] += Float(s)
            }
        }
    }
}
