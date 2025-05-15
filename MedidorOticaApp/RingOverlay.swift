//
//  RingOverlay.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/13/25.
//
import SwiftUI

/// Anel com 8 segmentos; cada verificação válida preenche 1.
struct RingOverlay: View {
    let progress: Int           // 0‥8
    private let total = 8
    private let lineW: CGFloat = 8

    var body: some View {
        ZStack {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .trim(from: CGFloat(i)/CGFloat(total),
                          to:   CGFloat(i+1)/CGFloat(total))
                    .stroke(style: StrokeStyle(lineWidth: lineW,
                                               lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .foregroundColor(i < progress ? .green : .gray.opacity(0.3))
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .padding(40)                  // distância da borda
        .allowsHitTesting(false)
    }
}

// 1) OVAL ESTÁTICO — contorno onde o rosto deve ficar
struct FaceOvalOverlay: View {
    let hInset: CGFloat = 0.15   // afastamento horizontal (15%)
    let vInset: CGFloat = 0.10   // afastamento vertical   (10%)
    let lineWidth: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * (1 - hInset * 2)
            let h = geo.size.height * (1 - vInset * 2)
            Ellipse()
                .stroke(Color.white.opacity(0.8),
                        lineWidth: lineWidth)
                .frame(width: w, height: h)
                .position(x: geo.size.width/2,
                          y: geo.size.height/2)
        }
        .allowsHitTesting(false)
    }
}

// 2) OVAL PROGRESSIVO — anel em forma de oval
struct ProgressOvalOverlay: View {
    let progress: Int    // de 0…8
    let hInset: CGFloat = 0.15
    let vInset: CGFloat = 0.10
    let lineWidth: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * (1 - hInset * 2)
            let h = geo.size.height * (1 - vInset * 2)
            Ellipse()
                .trim(from: 0, to: CGFloat(progress) / 8)
                .stroke(Color.blue,
                        style: StrokeStyle(lineWidth: lineWidth,
                                           lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: w, height: h)
                .position(x: geo.size.width/2,
                          y: geo.size.height/2)
        }
        .allowsHitTesting(false)
    }
}
