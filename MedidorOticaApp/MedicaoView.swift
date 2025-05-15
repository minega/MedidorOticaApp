//
//  MedicaoView.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/15/25.
//

import SwiftUI

struct MedicaoView: View {
    @Binding var autoCap: Bool
    @Binding var useFront: Bool
    @Binding var historico: [ (Medidas, UIImage) ]
    @Environment(\.presentationMode) var presentationMode
    @State private var mensagem: String?
    @State private var seta: String?
    @State private var progresso: Int = 0
    @StateObject private var arCoord = ARCoordinator()
    @State private var cameraDelegate: CameraDelegate? // Mantém o delegate vivo

    var body: some View {
        VStack {
            ZStack {
                ARViewContainer(autoCap: $autoCap, useFront: $useFront, coordinator: arCoord)
                    .edgesIgnoringSafeArea(.all)
                FaceOvalOverlay()
            }
            .frame(height: 420)

            VStack(alignment: .leading, spacing: 8) {
                Label("Distância OK", systemImage: progresso >= 1 ? "checkmark.circle" : "circle")
                Label("Cabeça Alinhada", systemImage: progresso >= 2 ? "checkmark.circle" : "circle")
                Label("Centralização", systemImage: progresso >= 4 ? "checkmark.circle" : "circle")
                Label("Armação OK", systemImage: progresso >= 6 ? "checkmark.circle" : "circle")
                Label("Pronto!", systemImage: progresso >= 8 ? "checkmark.circle.fill" : "circle")
            }
            .padding(10)
            .background(Color.black.opacity(0.15))
            .cornerRadius(8)

            if let mensagem = mensagem {
                HStack {
                    if let seta = seta, !seta.isEmpty {
                        Text(seta).font(.system(size: 32))
                    }
                    Text(mensagem)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            HStack {
                Button("Captura Forçada") {
                    arCoord.capturarManual()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear {
            let delegate = CameraDelegate(
                progresso: $progresso,
                mensagem: $mensagem,
                seta: $seta,
                historico: $historico,
                dismiss: { presentationMode.wrappedValue.dismiss() }
            )
            arCoord.delegate = delegate
            cameraDelegate = delegate // Mantém o delegate forte (vivo)
        }
    }
}

