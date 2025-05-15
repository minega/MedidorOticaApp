//
//  HistoricoView.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/15/25.
//

import SwiftUI

struct HistoricoView: View {
    @ObservedObject var store: MeasurementStore

    var body: some View {
        VStack {
            if store.records.isEmpty {
                Text("Nenhum histórico disponível.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(store.records) { record in
                    HStack(alignment: .center, spacing: 16) {
                        // Miniatura se tiver foto
                        if let imgData = record.imageData, let uiImage = UIImage(data: imgData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                        }
                        VStack(alignment: .leading) {
                            Text(record.name.isEmpty ? "Sem Nome" : record.name)
                            Text("DP: \(String(format: "%.1f mm", record.dp)), DNP(E): \(String(format: "%.1f mm", record.dnpLeft ?? 0)), DNP(D): \(String(format: "%.1f mm", record.dnpRight ?? 0)), Tilt: \(String(format: "%.1f", record.frameTilt ?? 0))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)


                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}
