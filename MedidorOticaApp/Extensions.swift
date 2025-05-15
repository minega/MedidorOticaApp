//
//  Extensions.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/12/25.
//

import Foundation
import SwiftUI

extension UIImage {
    func resized(to width: CGFloat) -> UIImage? {
        let size = CGSize(width: width, height: width * size.height / size.width)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        draw(in: CGRect(origin: .zero, size: size))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
}

