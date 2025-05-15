//
//  ReportView.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//

import SwiftUI

struct ReportView: View {
    var medidas: MeasurementData
    var imagem: UIImage

    var body: some View {
        ScrollView {
            Image(uiImage: imagem)
                .resizable()
                .scaledToFit()
                .frame(height: 220)
                .cornerRadius(12)
            VStack(alignment: .leading, spacing: 6) {
                Text("DP: \(String(format: "%.2f", medidas.dp)) mm")
                Text("DNP(E): \(String(format: "%.2f", medidas.dnpLeft)) mm")
                Text("DNP(D): \(String(format: "%.2f", medidas.dnpRight)) mm")
                Text("Tilt: \(String(format: "%.2f", medidas.frameTilt ?? 0))°")
                if let left = medidas.leftPupilPoint {
                    Text("Pupila Esquerda: (x: \(String(format: "%.0f", left.x)), y: \(String(format: "%.0f", left.y)))")
                }
                if let right = medidas.rightPupilPoint {
                    Text("Pupila Direita: (x: \(String(format: "%.0f", right.x)), y: \(String(format: "%.0f", right.y)))")
                }
                if let leftB = medidas.leftFrameBottom {
                    Text("Base Esquerda Armação: (x: \(String(format: "%.0f", leftB.x)), y: \(String(format: "%.0f", leftB.y)))")
                }
                if let rightB = medidas.rightFrameBottom {
                    Text("Base Direita Armação: (x: \(String(format: "%.0f", rightB.x)), y: \(String(format: "%.0f", rightB.y)))")
                }
            }
            .padding(.top, 12)
        }
        .padding()
    }
}

