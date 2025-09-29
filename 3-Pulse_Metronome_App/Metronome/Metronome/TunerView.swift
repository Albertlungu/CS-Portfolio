import SwiftUI
import AVFoundation
import Accelerate

struct TunerView: View {
    @Binding var isStarted: Bool
    
    // MARK: - State
    @State private var scale: CGFloat = 1.0
    @State private var note: String = "A4"
    @State private var frequency: Float = 440.0
    
    // Smoothing factor for frequency to reduce jitter
    private let smoothingFactor: Float = 0.2
    
    // MARK: - Audio
    let audioEngine = AVAudioEngine()
    var inputNode: AVAudioInputNode { audioEngine.inputNode }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Orb
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.green, .mint]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 150 * scale, height: 150 * scale)
                        .shadow(color: .cyan.opacity(0.5), radius: 50.0)
                        .glassEffect()
                    
                    VStack {
                        Text(note)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(String(format: "%.1f Hz", frequency))
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                    }
                }
                
                // Pitch bar
                Rectangle()
                    .fill(barColor())
                    .frame(width: barWidth(geometry: geometry), height: 10)
                    .cornerRadius(22)
                    .glassEffect()
                    .padding(.top, 30)
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 80)
        }
        .onAppear {
            requestMicrophonePermission()
        }
    }
    
    // MARK: - Bar visuals
    private func barWidth(geometry: GeometryProxy) -> CGFloat {
        let maxWidth: CGFloat = 250
        let accuracy = pitchAccuracy()
        return maxWidth * CGFloat(accuracy)
    }
    
    private func barColor() -> Color {
        let accuracy = pitchAccuracy()
        return Color(red: Double(1 - accuracy),
                     green: Double(accuracy),
                     blue: 0)
    }
    
    // MARK: - Pitch accuracy (0–1)
    private func pitchAccuracy() -> Float {
        let targetFreq = noteFrequency(note: note)
        guard targetFreq > 0 else { return 0 }
        let diff = abs(frequency - targetFreq)
        let maxDiff: Float = 20 // ±20 Hz tolerance
        let clamped = max(0, 1 - diff / maxDiff)
        scale = CGFloat(1 + clamped * 0.5) // orb grows up to 1.5x
        return clamped
    }
    
    // Convert note name to frequency
    private func noteFrequency(note: String) -> Float {
        let noteNames = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let pattern = "([A-G]#?)(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let matches = regex.matches(in: note, range: NSRange(note.startIndex..., in: note))
        guard let match = matches.first,
              let noteRange = Range(match.range(at: 1), in: note),
              let octaveRange = Range(match.range(at: 2), in: note) else { return 0 }
        
        let name = String(note[noteRange])
        let octave = Int(note[octaveRange]) ?? 4
        guard let index = noteNames.firstIndex(of: name) else { return 0 }
        return 440 * pow(2, Float(index - 9)/12 + Float(octave - 4))
    }
    
    // MARK: - Microphone Permission
    func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                if granted { setupAudioSession() } else { print("Microphone denied") }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if granted { setupAudioSession() } else { print("Microphone denied") }
            }
        }
    }
    
    // MARK: - Audio Session
    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try session.setActive(true)
            startAudioEngine()
        } catch {
            print("Failed to set up audio session:", error)
        }
    }
    
    // MARK: - Start Audio Engine
    func startAudioEngine() {
        let bufferSize: AVAudioFrameCount = 4096
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
            guard let samples = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            let detectedFrequency = performPitchDetection(samples: samples, frameCount: frameCount, sampleRate: Float(format.sampleRate))
            
            DispatchQueue.main.async {
                // Smooth the frequency to reduce jitter
                self.frequency = self.frequency * (1 - smoothingFactor) + detectedFrequency * smoothingFactor
                self.note = calculateNote(from: self.frequency)
            }
        }
        
        do {
            try audioEngine.prepare()
            try audioEngine.start()
            print("Started Audio Engine succesfully")
        } catch {
            print("Error starting Audio Engine", error)
        }
    }
    
    // MARK: - FFT Pitch Detection with Hanning Window
    func performPitchDetection(samples: UnsafePointer<Float>, frameCount: Int, sampleRate: Float) -> Float {
        let log2n = vDSP_Length(log2(Float(frameCount)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return 0 }
        
        // Window
        var window = [Float](repeating: 0, count: frameCount)
        vDSP_hann_window(&window, vDSP_Length(frameCount), Int32(vDSP_HANN_NORM))
        
        var windowedSamples = [Float](repeating: 0, count: frameCount)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(frameCount))
        
        var realp = [Float](repeating: 0, count: frameCount/2)
        var imagp = [Float](repeating: 0, count: frameCount/2)
        var detectedFrequency: Float = 0
        
        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var complexBuffer = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowedSamples.withUnsafeBufferPointer { samplesPtr in
                    samplesPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: frameCount) { typeConvertedSamples in
                        vDSP_ctoz(typeConvertedSamples, 2, &complexBuffer, 1, vDSP_Length(frameCount/2))
                    }
                }
                
                vDSP_fft_zrip(fftSetup, &complexBuffer, 1, log2n, FFTDirection(FFT_FORWARD))
                
                var magnitudes = [Float](repeating: 0, count: frameCount/2)
                vDSP_zvmags(&complexBuffer, 1, &magnitudes, 1, vDSP_Length(frameCount/2))
                
                var maxIndex: vDSP_Length = 0
                var maxValue: Float = 0
                vDSP_maxvi(magnitudes, 1, &maxValue, &maxIndex, vDSP_Length(frameCount/2))
                
                detectedFrequency = Float(maxIndex) * sampleRate / Float(frameCount)
            }
        }
        
        vDSP_destroy_fftsetup(fftSetup)
        return detectedFrequency
    }
    
    // MARK: - Calculate Note from Frequency
    func calculateNote(from frequency: Float) -> String {
        guard frequency > 0 else { return "-" }
        let midiNote = Int(round(12 * log2(Double(frequency) / 440.0) + 69))
        let noteNames = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let noteName = noteNames[midiNote % 12]
        let octave = midiNote / 12 - 1
        return "\(noteName)\(octave)"
    }
}

#Preview {
    TunerView(isStarted: .constant(false))
}
