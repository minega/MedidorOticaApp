//
//  ReportView.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//

import SwiftUI

struct ReportView: View {
    let clientName: String
    let dp, alt, vertical, horizontal, diagonal, ponte: Float

    var body: some View {
        VStack(spacing: 12) {
            Text("Relatório de Medidas")
                .font(.title).bold()

            Text("Ótica Manzolli")
                .font(.subheadline)

            Divider()
                .padding(.vertical)

            Text("Cliente: \(clientName)")
                .font(.headline)

            Group {
                Text("DP: \(String(format: "%.2f", dp)) mm")
                Text("ALT: \(String(format: "%.2f", alt)) mm")
                Text("Altura: \(String(format: "%.2f", vertical)) mm")
                Text("Largura: \(String(format: "%.2f", horizontal)) mm")
                Text("Diagonal: \(String(format: "%.2f", diagonal)) mm")
                Text("Ponte: \(String(format: "%.2f", ponte)) mm")
            }
            .font(.body)

            Spacer()

            ShareLink(item: reportText()) {
                Label("Compartilhar Relatório", systemImage: "square.and.arrow.up")
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
    }

    private func reportText() -> String {
        let lines = [
            "Ótica Manzolli – Relatório de Medidas",
            "",
            "Cliente: \(clientName)",
            String(format: "DP: %.2f mm", dp),
            String(format: "ALT: %.2f mm", alt),
            String(format: "Altura: %.2f mm", vertical),
            String(format: "Largura: %.2f mm", horizontal),
            String(format: "Diagonal: %.2f mm", diagonal),
            String(format: "Ponte: %.2f mm", ponte)
        ]
        return lines.joined(separator: "\n")
    }
}
