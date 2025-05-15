//
//  ARViewContainer.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//

import SwiftUI
import ARKit

struct ARViewContainer: UIViewRepresentable {
    @Binding var autoCap: Bool
    @Binding var useFront: Bool
    var coordinator: ARCoordinator

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        coordinator.configurarCena(view)
        return view
    }
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        coordinator.useFront = useFront
        coordinator.autoCap = autoCap
        coordinator.configurarCena(uiView)
    }
}
