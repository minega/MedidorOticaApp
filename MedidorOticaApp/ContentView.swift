//
//  ContentView.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//
import SwiftUI

struct ContentView: View {
    @StateObject private var arCoordinator = ARCoordinator()       // Shared AR coordinator
    @StateObject private var store = MeasurementStore()           // Shared data store for history
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Ótica Manzolli")
                    .font(.largeTitle).bold()
                    .padding(.top, 20)
                Spacer()
                // Main button to start measurement
                NavigationLink(destination: MedicaoView().environmentObject(arCoordinator).environmentObject(store)) {
                    Text("Tirar Medidas")
                        .font(.headline).padding(.horizontal, 40).padding(.vertical, 15)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Spacer()
                // Bottom button to view history of saved measurements
                NavigationLink(destination: HistoricoView(store: store).environmentObject(store)) {
                    Text("Ver Histórico")
                        .font(.subheadline)
                        .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

