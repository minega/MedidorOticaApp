//
//  MedicaoView.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/15/25.
//

import SwiftUI
import SceneKit  // For SCNNode to compute Euler angles

struct MedicaoView: View {
    @EnvironmentObject var arCoordinator: ARCoordinator
    @EnvironmentObject var store: MeasurementStore
    
    var body: some View {
        ZStack {
            // AR camera view filling the entire screen
            ARViewContainer().environmentObject(arCoordinator)
                .edgesIgnoringSafeArea(.all)
            
            // Top control bar (close, switch camera, flash, auto-capture)
            HStack {
                // Close button (X) to exit measurement view
                Button(action: {
                    arCoordinator.endSession()    // stop camera
                    // Pop back to previous view
                    // In SwiftUI, using presentationMode to dismiss
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let root = windowScene.windows.first?.rootViewController {
                        root.dismiss(animated: true, completion: nil)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.title2).padding(10)
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .padding(.leading, 10)
                
                Spacer()
                
                // Toggle front/back camera
                Button(action: {
                    arCoordinator.switchCamera()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title2).padding(10)
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                
                // Flash toggle (only visible if using rear camera)
                if !arCoordinator.useFront {
                    Button(action: {
                        arCoordinator.toggleFlash()
                    }) {
                        Image(systemName: arCoordinator.flashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title2).padding(10)
                            .background(Color.black.opacity( arCoordinator.flashOn ? 0.7 : 0.5))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                
                // Auto-capture toggle
                Button(action: {
                    arCoordinator.autoCapture.toggle()
                }) {
                    Image(systemName: arCoordinator.autoCapture ? "checkmark.circle.fill" : "circle")
                        .font(.title2).padding(10)
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .padding(.trailing, 10)
            }
            .padding(.top, 50)
            
            // Oval overlay with progress ring and instructions
            VStack {
                Spacer()
                // Instruction text (arrow + message) above the oval
                if let msg = arCoordinator.message {
                    HStack {
                        if let arrow = arCoordinator.arrow {
                            Text(arrow)
                                .font(.system(size: 32))
                        }
                        Text(msg)
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    .padding(.bottom, 5)
                }
                // Draw the oval shape with dynamic progress outline
                ZStack {
                    // Gray oval outline
                    Ellipse()
                        .stroke(Color.white.opacity(0.5), lineWidth: 4)
                        .frame(width: 250, height: 320)
                    // Green progress overlay (trim the ellipse stroke based on validations)
                    Ellipse()
                        .trim(from: 0.0, to: CGFloat(min(Double(arCoordinator.progress) / 5.0, 1.0)))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 250, height: 320)
                        .rotationEffect(.degrees(-90))   // start from top
                        .animation(.easeOut, value: arCoordinator.progress)
                }
                .padding(.bottom, 30)
                Spacer()
            }
            
            // Validation checklist in top-right corner (discreet indicators)
            VStack(alignment: .leading, spacing: 8) {
                Label("Distância OK", systemImage: arCoordinator.progress >= 1 ? "checkmark.circle" : "circle")
                Label("Cabeça Alinhada", systemImage: arCoordinator.progress >= 2 ? "checkmark.circle" : "circle")
                Label("Queixo Alinhado", systemImage: arCoordinator.progress >= 3 ? "checkmark.circle" : "circle")
                Label("Olhos Centralizados", systemImage: arCoordinator.progress >= 4 ? "checkmark.circle" : "circle")
                Label("Armação OK", systemImage: arCoordinator.progress >= 5 ? "checkmark.circle" : "circle")
            }
            .font(.caption)
            .foregroundColor(.white)
            .padding(8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
            .padding(.top, 60)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Bottom capture controls
            VStack {
                Spacer()
                HStack(spacing: 40) {
                    // Forced capture button (always enabled)
                    Button("Captura Forçada") {
                        arCoordinator.captureNow()   // capture immediately regardless of validations
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.7))
                    .foregroundColor(.black)
                    .cornerRadius(5)
                    
                    // Main capture button (enabled only when validations criteria met)
                    Button(action: {
                        arCoordinator.captureNow()
                    }) {
                        Circle()
                            .fill(arCoordinator.canCapture ? Color.blue : Color.gray)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.white)
                                    .font(.largeTitle)
                            )
                    }
                    .disabled(!arCoordinator.canCapture)
                }
                .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
        // Navigate to ResultView when capture is done
        .background(
            NavigationLink(destination: ResultView(record: arCoordinator.capturedRecord ?? MeasurementData()).environmentObject(store).environmentObject(arCoordinator),
                           isActive: $arCoordinator.didCapture) {
                EmptyView()
            }
        )
    }
}
