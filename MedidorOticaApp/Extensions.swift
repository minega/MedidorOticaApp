//
//  Extensions.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/12/25.
//

import UIKit

extension CGRect { var center: CGPoint { .init(x: midX, y: midY) } }

extension UIApplication {
    /// Key‑window rápida (para apresentar UIActivityViewController)
    var firstKeyWindow: UIWindow? {
        connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
