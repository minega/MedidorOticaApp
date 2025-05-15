//
//  ARViewContainer.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//

import SwiftUI
import ARKit

struct ARViewContainer: UIViewRepresentable {
    @EnvironmentObject var arCoordinator: ARCoordinator
    
    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = UIColor.black
        // Set the coordinator as the delegate for AR session and scene
        sceneView.session.delegate = arCoordinator
        sceneView.delegate = arCoordinator
        // Keep a reference to the ARSCNView in our coordinator
        arCoordinator.sceneView = sceneView
        // Start AR session with current camera selection
        arCoordinator.startSession()
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Nothing to update continuously from SwiftUI side
    }
}
