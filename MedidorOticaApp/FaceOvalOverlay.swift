//
//  FaceOvalOverlay.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/15/25.
//

import SwiftUI

struct FaceOvalOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.7
            let h = geo.size.height * 0.7
            Ellipse()
                .stroke(Color.white.opacity(0.9), lineWidth: 4)
                .frame(width: w, height: h)
                .position(x: geo.size.width/2, y: geo.size.height/2)
                .shadow(radius: 8)
        }
        .allowsHitTesting(false)
    }
}
