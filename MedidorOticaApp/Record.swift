//
//  Record.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/12/25.
//

import Foundation

struct Record: Codable, Identifiable {
    var id = UUID()
    var nome: String
    var medidas: MeasurementData
    var data: Date
}

