//
//  MeasurementData.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/12/25.
//
import Foundation

struct MeasurementData: Codable, Identifiable {
    var id = UUID()
    var nome: String
    var medidas: Medidas
    var data: Date
}


