import SwiftUI
import AVFoundation
import Accelerate

struct TunerView: View {
    @Binding var isStarted: Bool   // <-- still called `isStarted` here,
                                   // but in ContentView you now bind it to `tunerIsStarted`
    
    @State private var engine = AVAudioEngine()
    @State private var detectedFrequency: Double = 0.0
    @State private var detectedNote: String = "-"
    @State private var centsOff: Double = 0.0
    @State private var isListening = false
    @State private var pulse = false
    
    let session = AVAudioSession.sharedInstance()
    
    init(isStarted: Binding<Bool>) {
        self._isStarted = isStarted
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private let notes = [
        ("C", 16.35), ("C#", 17.32), ("D", 18.35), ("D#", 19.45), ("E", 20.60),
        ("F", 21.83), ("F#", 23.12), ("G", 24.50), ("G#", 25.96), ("A", 27.50),
        ("A#", 29.14), ("B", 30.87)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.cyan.opacity(0.8), Color.green.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .overlay(
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .scaleEffect(pulse ? 1.3 : 0.8)
                        .frame(width: geometry.size.width * 1.8, height: geometry.size.width * 1.8)
                        .blur(radius: 100)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)
                )
                
                VStack(spacing: 40) {
                    // Main glowing circle
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.green, .cyan]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 140, height: 140)
                            .shadow(color: .cyan.opacity(0.6), radius: 50, x: 0, y: 10)
                        
                        VStack {
                            Text(detectedNote)
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(.white)
                            Text(String(format: "%.1f Hz", detectedFrequency))
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 18, weight: .medium))
                        }
                    }
                    
                    // Needle indicator
                    ZStack {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: geometry.size.width * 0.7, height: 10)
                        
                        Capsule()
                            .fill(centsOff == 0 ? Color.green :
                                  (centsOff > 0 ? Color.red : Color.blue))
                            .frame(width: 6, height: 50)
                            .offset(x: CGFloat(centsOff / 50) * (geometry.size.width * 0.35))
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: centsOff)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .onAppear {
                pulse = true
            }
            .onChange(of: isStarted) { started in
                if started {
                    requestMicrophonePermission()
                } else {
                    stopListening()
                }
            }
        }
    }
    
    // MARK: Microphone permission & audio engine
    private func requestMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            startListening()
        case .denied:
            print("Microphone access denied")
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if granted {
                    startListening()
                } else {
                    print("Microphone access denied by user")
                }
            }
        @unknown default:
            break
        }
    }

    private func startListening() {
        let input = engine.inputNode
        let bus = 0
        let format = input.inputFormat(forBus: bus)
        
        guard format.channelCount > 0 else {
            print("No microphone available. Cannot start tuner.")
            return
        }
        
        input.installTap(onBus: bus, bufferSize: 2048, format: format) { buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
            detectPitch(from: samples, sampleRate: format.sampleRate)
        }
        
        engine.prepare()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isListening = true
        } catch {
            print("Audio engine error: \(error.localizedDescription)")
        }
    }

    private func stopListening() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isListening = false
    }
    
    // MARK: Pitch detection
    private func detectPitch(from samples: [Float], sampleRate: Double) {
        var real = [Float](samples)
        var imag = [Float](repeating: 0.0, count: samples.count)
        var output = DSPSplitComplex(realp: &real, imagp: &imag)
        
        let log2n = vDSP_Length(log2(Float(samples.count)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2)) else { return }
        
        vDSP_fft_zip(fftSetup, &output, 1, log2n, Int32(FFT_FORWARD))
        
        let magnitudes = (0..<samples.count/2).map { i -> Float in
            let re = real[i]
            let im = imag[i]
            return sqrt(re*re + im*im)
        }
        
        if let maxIndex = magnitudes.firstIndex(of: magnitudes.max() ?? 0) {
            let frequency = Double(maxIndex) * sampleRate / Double(samples.count)
            DispatchQueue.main.async {
                updateNote(for: frequency)
            }
        }
        
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    private func updateNote(for frequency: Double) {
        detectedFrequency = frequency
        
        var closestNote = "-"
        var minDiff = Double.greatestFiniteMagnitude
        var targetFreq = 0.0
        
        for octave in 0...8 {
            for (note, baseFreq) in notes {
                let freq = baseFreq * pow(2.0, Double(octave))
                let diff = abs(freq - frequency)
                if diff < minDiff {
                    minDiff = diff
                    closestNote = note
                    targetFreq = freq
                }
            }
        }
        
        detectedNote = closestNote
        centsOff = 1200 * log2(frequency / targetFreq)
        centsOff = min(max(centsOff, -50), 50)
    }
}

struct TunerView_Previews: PreviewProvider {
    static var previews: some View {
        TunerView(isStarted: .constant(true))
    }
}
