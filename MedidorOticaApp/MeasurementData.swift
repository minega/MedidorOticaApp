//
//  MeasurementData.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/12/25.
//
import Foundation

struct MeasurementData: Identifiable {
    let id = UUID()

    var dp:        Float = 0
    var alt:       Float = 0
    var vertical:  Float = 0
    var horizontal:Float = 0
    var diagonal:  Float = 0
    var ponte:     Float = 0
    var dnpLeft:   Float = 0       // distância naso-pupilar ESQ
    var dnpRight:  Float = 0       // distância naso-pupilar DIR
    var distCM:    Float = 0
    static let empty = MeasurementData()
}

