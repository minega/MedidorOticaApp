//
//  ManualAdjustView.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//

import SwiftUI

struct ManualAdjustView: View {
    @Binding var image: UIImage
    @Binding var points: [CGPoint]
    var body: some View {
        ZStack {
            Image(uiImage: image).resizable().scaledToFit()
            ForEach(0..<points.count, id: \.self) { idx in
                DraggableOverlay(point: $points[idx])
            }
        }
    }
}
