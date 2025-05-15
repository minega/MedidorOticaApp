//
//  DraggableOverlay.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/12/25.
//

import SwiftUI

struct DraggableOverlay: View {
    @Binding var point: CGPoint
    var body: some View {
        Circle()
            .fill(Color.red.opacity(0.85))
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .position(point)
            .gesture(DragGesture()
                .onChanged { value in self.point = value.location }
            )
    }
}
