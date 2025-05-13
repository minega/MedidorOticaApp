//
//  Record.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/12/25.
//

import UIKit

struct Record: Identifiable {
    let id = UUID(), date = Date()
    let name: String
    let snapshot: UIImage
    let data: MeasurementData
}
