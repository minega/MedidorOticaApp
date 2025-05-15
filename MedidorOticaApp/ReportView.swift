//
//  ReportView.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//

import SwiftUI

struct ReportView: View {
    var medidas: Medidas
    var imagem: UIImage
    var body: some View {
        ScrollView {
            Image(uiImage: imagem)
                .resizable().scaledToFit().frame(height: 220).cornerRadius(12)
            VStack(alignment: .leading, spacing: 6) {
                Text("DP: \(String(format: "%.2f", medidas.dp)) mm")
                Text("DNP Esq.: \(String(format: "%.2f", medidas.dnpLeft)) mm")
                Text("DNP Dir.: \(String(format: "%.2f", medidas.dnpRight)) mm")
                Text("ALT Esq.: \(String(format: "%.2f", medidas.altLeft)) mm")
                Text("ALT Dir.: \(String(format: "%.2f", medidas.altRight)) mm")
                Text("Horizontal: \(String(format: "%.2f", medidas.horizontal)) mm")
                Text("Vertical: \(String(format: "%.2f", medidas.vertical)) mm")
                Text("Diagonal: \(String(format: "%.2f", medidas.diagonal)) mm")
                Text("Ponte: \(String(format: "%.2f", medidas.ponte)) mm")
                Text("Alinhamento: \(medidas.alinhada ? "✅" : "❌")")
                Text("Distância rosto-câmera: \(String(format: "%.0f", medidas.distCM)) cm")
            }.font(.title3).padding(.top, 12)
        }.padding()
    }
}
