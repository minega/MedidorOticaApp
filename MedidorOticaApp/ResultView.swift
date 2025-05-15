//
//  ResultView.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/15/25.
//

import SwiftUI

struct ResultView: View {
    var record: MeasurementData

    var body: some View {
        VStack {
            Text("Verificação de Medidas")
                .font(.title).bold().padding()

            // Thumbnail/captura se disponível
            if let imgData = record.imageData, let uiImage = UIImage(data: imgData) {
                GeometryReader { geo in
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                    // Aqui você pode adicionar overlays se quiser
                }
                .frame(height: 300)
            }

            // Medidas
            VStack(alignment: .leading, spacing: 4) {
                Text("DP: \(String(format: "%.1f mm", record.dp))")
                Text("DNP(E): \(String(format: "%.1f mm", record.dnpLeft ?? 0)), DNP(D): \(String(format: "%.1f mm", record.dnpRight ?? 0))")
                Text("Tilt: \(String(format: "%.1f", record.frameTilt ?? 0))")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.top, 12)

        }
        .padding()
    }
}
