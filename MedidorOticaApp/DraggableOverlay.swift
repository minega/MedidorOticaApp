//
//  DraggableOverlay.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/12/25.
//

import SwiftUI

/// Overlay com 4 alvos arrastáveis (cantos) para ajuste fino manual.
public struct DraggableOverlay: View {
    @Binding var points: [CGPoint]          // TL, TR, BL, BR
    private let handle: CGFloat = 22

    public init(points: Binding<[CGPoint]>) { _points = points }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // retângulo verde
                Path { p in guard points.count == 4 else { return }; p.addLines(points + [points[0]]) }
                    .stroke(Color.green, lineWidth: 2)
                // handles vermelhos
                ForEach(points.indices, id: \.self) { i in
                    Circle().fill(Color.red)
                        .frame(width: handle, height: handle)
                        .position(points[i])
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { g in points[i] = clamp(g.location, in: geo.frame(in: .local)) }
                        )
                }
            }
            .contentShape(Rectangle())
            .onAppear {
                if points.count != 4 {
                    let w = geo.size.width, h = geo.size.height
                    points = [CGPoint(x:w*0.25,y:h*0.25), CGPoint(x:w*0.75,y:h*0.25), CGPoint(x:w*0.25,y:h*0.75), CGPoint(x:w*0.75,y:h*0.75)]
                }
            }
        }
    }
    private func clamp(_ p: CGPoint, in r: CGRect) -> CGPoint {
        .init(x: min(max(p.x, 0), r.width), y: min(max(p.y, 0), r.height))
    }
}
