//
//  RingOverlay.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/13/25.
//
import SwiftUI

struct RingOverlay: View {
    var progress: Int
    var body: some View {
        ZStack {
            Ellipse()
                .stroke(Color.white.opacity(0.6), lineWidth: 3)
            Ellipse()
                .trim(from: 0, to: CGFloat(progress)/8)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(16)
        .shadow(radius: 8)
    }
}
