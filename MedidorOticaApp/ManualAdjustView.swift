//
//  ManualAdjustView.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//

import SwiftUI

struct ManualAdjustView: View {
    let snapshot: UIImage
    @State var points: [CGPoint]           // normalizados 0–1
    let onComplete: ([CGPoint]) -> Void    // callback com novos pontos

    @State private var imgSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // fundo
                Image(uiImage: snapshot)
                    .resizable().scaledToFit()
                    .onAppear {
                        let aspect = snapshot.size.width / snapshot.size.height
                        let w = min(geo.size.width, geo.size.height * aspect)
                        imgSize = CGSize(width: w, height: w / aspect)
                    }

                // alvos arrastáveis
                ForEach(0..<points.count, id: \.self) { i in
                    Circle().stroke(Color.blue, lineWidth: 2).frame(width: 24, height: 24)
                        .position(toScreen(points[i], in: imgSize, container: geo.size))
                        .gesture(DragGesture().onChanged { g in
                            points[i] = fromScreen(g.location, in: imgSize, container: geo.size)
                        })
                }

                // botão concluir
                VStack {
                    Spacer()
                    Button("Concluir Ajuste") {
                        onComplete(points)
                    }
                    .padding().background(Color.blue).foregroundColor(.white).cornerRadius(8)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // converte normalizado→tela
    private func toScreen(_ norm: CGPoint, in img: CGSize, container c: CGSize) -> CGPoint {
        let xOff = (c.width - img.width)/2, yOff = (c.height - img.height)/2
        return CGPoint(x: xOff + norm.x * img.width,
                       y: yOff + (1 - norm.y) * img.height)
    }

    // converte tela→normalizado
    private func fromScreen(_ pt: CGPoint, in img: CGSize, container c: CGSize) -> CGPoint {
        let xOff = (c.width - img.width)/2, yOff = (c.height - img.height)/2
        let x = (pt.x - xOff)/img.width, y = 1 - ((pt.y - yOff)/img.height)
        return CGPoint(x: min(max(0,x),1), y: min(max(0,y),1))
    }
}
