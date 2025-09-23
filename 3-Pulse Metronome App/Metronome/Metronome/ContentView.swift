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
                // Content area with TabView
                TabView(selection: $selectedView) {
                    MetronomeView(isStarted: $metronomeIsStarted)
                        .tag(SelectedView.metronome)
                    TunerView(isStarted: $tunerIsStarted)
                        .tag(SelectedView.tuner)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Custom tab bar
                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.secondary, lineWidth: 2)
                                .blur(radius: 100)
                        )
                        .glassEffect()
                    
                    HStack {
                        Text("Metronome")
                            .font(.system(size: selectedView == .metronome ? 30 : 20,
                                          weight: selectedView == .metronome ? .bold : .regular))
                            .foregroundColor(selectedView == .metronome ? .primary : .secondary)
                            .padding(.leading, selectedView == .metronome ? 110 : 10)
                            .padding(9)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .onTapGesture {
                                selectedView = .metronome
                            }

                        Text("Tuner")
                            .font(.system(size: selectedView == .tuner ? 30 : 20,
                                          weight: selectedView == .tuner ? .bold : .regular))
                            .foregroundColor(selectedView == .tuner ? .primary : .secondary)
                            .padding(9)
                            .opacity(selectedView == .tuner ? 1 : 0.9)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .onTapGesture {
                                selectedView = .tuner
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
                                    withAnimation(.spring()) {
                                        offset = CGSize(width: maxOffsetX, height: -2)
                                        DispatchQueue.main.asyncAfter(deadline: .now() - 0.4) {
                                            selectedView = .metronome
                                            offset = .zero
                                        }
                                    }
                                } else if value.translation.width < -50 {
                                    withAnimation(.spring()) {
                                        offset = CGSize(width: minOffsetX, height: -2)
                                        DispatchQueue.main.asyncAfter(deadline: .now() - 0.4) {
                                            selectedView = .tuner
                                            offset = .zero
                                        }
                                    }
                                } else {
                                    withAnimation(.spring()) {
                                        offset = .zero
                                    }
                                }
                            }
                    )
                }
                .frame(width: geometry.size.width - 20, height: 50, alignment: .center)
                .padding(.horizontal, 10)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .position(x: geometry.size.width / 2, y: geometry.size.height - 80)

                // Play/Stop button area
                ZStack(alignment: .center) {
                    let isStarted = (selectedView == .metronome) ? metronomeIsStarted : tunerIsStarted
                    
                    RoundedRectangle(cornerRadius: 22)
                        .fill(isStarted ? Color.red : Color.blue)
                        .frame(width: 100, height: 50)
                        .scaleEffect(scale)
                        .glassEffect()
                        .onTapGesture {
                            withAnimation(.easeIn(duration: 0.1)) {
                                scale = 1.2
                            }
                            HapticImpactRigid.impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if selectedView == .metronome {
                                    metronomeIsStarted.toggle()
                                } else {
                                    tunerIsStarted.toggle()
                                }
                                withAnimation(.easeOut(duration: 0.1)) {
                                    scale = 1.0
                                }
                            }
                        }

                    HStack {
                        Image(systemName: isStarted ? "square.fill" : "play.fill")
                            .foregroundColor(.black)
                        Text(isStarted ? "Stop" : "Start")
                            .foregroundColor(.black)
                            .font(.system(size: 22, weight: .bold, design: .default))
                    }
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height + 20)
                .padding(.leading, 5)
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
