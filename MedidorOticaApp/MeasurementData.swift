//
//  MeasurementData.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/12/25.
//
import SwiftUI
import CoreGraphics
import Foundation

struct MeasurementData: Identifiable, Codable {
    var id = UUID()
    var name: String = ""
    var dp: Float = 0.0               // Distância Pupilar (mm)
    var dnpLeft: Float = 0.0          // Distância Naso-Pupilar esquerda (mm)
    var dnpRight: Float = 0.0         // Distância Naso-Pupilar direita (mm)
    var frameTilt: Float? = nil       // Frame alignment tilt in degrees (optional)
    var imageData: Data? = nil        // Captured image data (JPEG/PNG)
    var imageSize: CGSize = .zero     // Original image size in pixels
    // Points for overlay (in original image pixel coordinates)
    var leftPupilPoint: CGPoint? = nil
    var rightPupilPoint: CGPoint? = nil
    var leftFrameBottom: CGPoint? = nil
    var rightFrameBottom: CGPoint? = nil
}

// Internal structure for ongoing measurements (not persisted, not codable)
struct Measures {
    var dp: Float = 0.0
    var dnpLeft: Float = 0.0
    var dnpRight: Float = 0.0
    var frameTilt: Float? = nil
    var leftEyePoint: CGPoint? = nil
    var rightEyePoint: CGPoint? = nil
    var leftFrameBottom: CGPoint? = nil
    var rightFrameBottom: CGPoint? = nil
}



