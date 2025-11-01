import SwiftUI
import Foundation
import UIKit

enum SelectedView {
    case metronome, tuner
}

struct ContentView: View {
    @State private var selectedView: SelectedView = .metronome
    @State public var metronomeIsStarted = false
    @State public var tunerIsStarted = false
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @Environment(\.colorScheme) private var colorScheme
    
    // AI-powered practice tracking
    @State private var sessionStartTime: Date?
    @State private var totalPracticeTime: TimeInterval = 0
    @State private var sessionMetrics: SessionMetrics = SessionMetrics()

    let HapticImpactRigid = UIImpactFeedbackGenerator(style: .rigid)
    let HapticImpactSoft = UIImpactFeedbackGenerator(style: .soft)
    let HapticImpactMedium = UIImpactFeedbackGenerator(style: .medium)
    let HapticImpactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    let HapticImpactLight = UIImpactFeedbackGenerator(style: .light)

    private let minOffsetX: CGFloat = -135 // max offset for tuner
    private let maxOffsetX: CGFloat = 120  // max offset for metronome

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.15),
                        Color(red: 0.15, green: 0.15, blue: 0.2)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
                
                // Content area with instant view switching
                ZStack {
                    MetronomeView(isStarted: $metronomeIsStarted, sessionMetrics: $sessionMetrics)
                        .opacity(selectedView == .metronome ? 1 : 0)
                        .zIndex(selectedView == .metronome ? 1 : 0)
                    
                    TunerView(isStarted: $tunerIsStarted, sessionMetrics: $sessionMetrics)
                        .opacity(selectedView == .tuner ? 1 : 0)
                        .zIndex(selectedView == .tuner ? 1 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.1), value: selectedView)

                // Custom tab bar with liquid glass effect
                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.5),
                                            Color.white.opacity(0.2),
                                            Color.clear
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .frame(height: 50)
                        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 5)
                    
                    HStack {
                        Text("Metronome")
                            .font(.system(size: selectedView == .metronome ? 30 : 20,
                                          weight: selectedView == .metronome ? .bold : .regular))
                            .foregroundColor(Color.white)
                            .opacity(selectedView == .metronome ? 1.0 : 0.6)
                            .padding(.leading, selectedView == .metronome ? 110 : 10)
                            .padding(9)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .scaleEffect(selectedView == .metronome ? 1.0 : 0.95)
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.1)) {
                                    selectedView = .metronome
                                }
                                HapticImpactLight.impactOccurred()
                            }

                        Text("Tuner")
                            .font(.system(size: selectedView == .tuner ? 30 : 20,
                                          weight: selectedView == .tuner ? .bold : .regular))
                            .foregroundColor(Color.white)
                            .opacity(selectedView == .tuner ? 1.0 : 0.6)
                            .padding(9)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .scaleEffect(selectedView == .tuner ? 1.0 : 0.95)
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.1)) {
                                    selectedView = .tuner
                                }
                                HapticImpactLight.impactOccurred()
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 20)
                    .offset(x: offset.width, y: 0)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newOffset = value.translation.width
                                if newOffset < minOffsetX {
                                    offset.width = minOffsetX + (newOffset - minOffsetX) / 6
                                } else if newOffset > maxOffsetX {
                                    offset.width = maxOffsetX + (newOffset - maxOffsetX) / 6
                                } else {
                                    offset.width = newOffset
                                }
                            }
                            .onEnded { value in
                                if value.translation.width > 50 {
                                    withAnimation(.easeOut(duration: 0.1)) {
                                        selectedView = .metronome
                                    }
                                    HapticImpactMedium.impactOccurred()
                                } else if value.translation.width < -50 {
                                    withAnimation(.easeOut(duration: 0.1)) {
                                        selectedView = .tuner
                                    }
                                    HapticImpactMedium.impactOccurred()
                                }
                                withAnimation(.easeOut(duration: 0.15)) {
                                    offset = .zero
                                }
                            }
                    )
                }
                .frame(width: max(0, geometry.size.width - 20), height: 50, alignment: .center)
                .clipped() // Clip entire tab bar content
                .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .position(x: geometry.size.width / 2, y: geometry.size.height - 110)

                // Play/Stop button with liquid glass effect
                ZStack(alignment: .center) {
                    let isStarted = (selectedView == .metronome) ? metronomeIsStarted : tunerIsStarted
                    
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: isStarted ? 
                                            [.red.opacity(0.8), .red.opacity(0.6)] : 
                                            [.blue.opacity(0.8), .blue.opacity(0.6)]
                                        ),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.2)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .frame(width: 100, height: 50)
                        .scaleEffect(scale)
                        .shadow(color: isStarted ? .red.opacity(0.5) : .blue.opacity(0.5), radius: scale > 1 ? 20 : 15)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isStarted)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                                scale = 1.15
                            }
                            HapticImpactRigid.impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if selectedView == .metronome {
                                    metronomeIsStarted.toggle()
                                } else {
                                    tunerIsStarted.toggle()
                                }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    scale = 1.0
                                }
                            }
                        }

                    HStack {
                        Image(systemName: isStarted ? "square.fill" : "play.fill")
                            .foregroundStyle(colorScheme == .dark ? Color.white : Color.white)
                        Text(isStarted ? "Stop" : "Start")
                            .foregroundStyle(colorScheme == .dark ? Color.white : Color.white)
                            .font(.system(size: 22, weight: .bold, design: .default))
                    }
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height - 25)
                .padding(.leading, 5)
            }
            .tint(colorScheme == .dark ? .white : .blue)
            .edgesIgnoringSafeArea(.all)
        }
    }
}

// MARK: - AI Session Metrics
struct SessionMetrics {
    var metronomeTotalTime: TimeInterval = 0
    var tunerTotalTime: TimeInterval = 0
    var tempoChanges: [Int] = []
    var tuningAccuracyHistory: [Float] = []
    var lastSessionDate: Date?
    
    mutating func recordTempo(_ bpm: Int) {
        if tempoChanges.isEmpty || tempoChanges.last != bpm {
            tempoChanges.append(bpm)
            if tempoChanges.count > 50 { tempoChanges.removeFirst() }
        }
    }
    
    mutating func recordTuningAccuracy(_ accuracy: Float) {
        tuningAccuracyHistory.append(accuracy)
        if tuningAccuracyHistory.count > 100 { tuningAccuracyHistory.removeFirst() }
    }
    
    func averageTuningAccuracy() -> Float {
        guard !tuningAccuracyHistory.isEmpty else { return 0 }
        return tuningAccuracyHistory.reduce(0, +) / Float(tuningAccuracyHistory.count)
    }
    
    func tempoTrend() -> String {
        guard tempoChanges.count >= 3 else { return "Building data..." }
        let recent = Array(tempoChanges.suffix(5))
        let isIncreasing = zip(recent, recent.dropFirst()).allSatisfy { $0 <= $1 }
        let isDecreasing = zip(recent, recent.dropFirst()).allSatisfy { $0 >= $1 }
        
        if isIncreasing { return "Tempo increasing - great progress!" }
        if isDecreasing { return "Tempo decreasing - take your time" }
        return "Exploring different tempos"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
