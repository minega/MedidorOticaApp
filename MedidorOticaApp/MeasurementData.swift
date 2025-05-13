//
//  MeasurementData.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/12/25.
//
import Foundation

/// Pacote com todas as medidas (mm)
public struct MeasurementData: Sendable {
    public var dp, alt, vertical, horizontal, diagonal, ponte: Float
    public static let empty = MeasurementData(dp: 0, alt: 0, vertical: 0, horizontal: 0, diagonal: 0, ponte: 0)
}
