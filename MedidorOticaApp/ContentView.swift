//
//  ContentView.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//
import SwiftUI

struct ContentView: View {
    @State private var autoCap: Bool = false
    @State private var useFront: Bool = true
    @State private var historico: [ (Medidas, UIImage) ] = []
    @State private var mostrarCamera = false
    @State private var mensagemErro: String?
    @State private var progresso: Int = 0
    @State private var dica: String = ""
    @State private var seta: String? = nil

    @StateObject private var arCoord = ARCoordinator()

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Medidor de Óculos Óptica")
                    .font(.largeTitle)
                    .bold()
                    .padding()
                Button("Tirar Medidas") { mostrarCamera = true }
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 55)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal, 40)
                Button("Ver Histórico") {}
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .sheet(isPresented: $mostrarCamera) {
                MedicaoView(
                    autoCap: $autoCap,
                    useFront: $useFront,
                    historico: $historico
                )
            }
        }
    }
}
