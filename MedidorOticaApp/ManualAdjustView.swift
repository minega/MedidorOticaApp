//
//  ManualAdjustView.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//

import SwiftUI

struct ManualAdjustView: View {
    @Binding var record: MeasurementData
    @Environment(\.presentationMode) var presentationMode
    
    // State for adjustable points (original image coordinate values)
    @State private var leftPupil = CGPoint.zero
    @State private var rightPupil = CGPoint.zero
    @State private var leftBottom = CGPoint.zero
    @State private var rightBottom = CGPoint.zero
    
    // Compute scale and offsets to map image coordinates to displayed view
    private func computeTransform(for geoSize: CGSize) -> (scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        guard record.imageSize != .zero else {
            return (1.0, 0.0, 0.0)
        }
        let imgW = record.imageSize.width
        let imgH = record.imageSize.height
        let containerW = geoSize.width
        let containerH = geoSize.height
        let imageAspect = imgW / imgH
        let containerAspect = containerW / containerH
        var scale: CGFloat = 1.0
        var offsetX: CGFloat = 0.0
        var offsetY: CGFloat = 0.0
        if imageAspect > containerAspect {
            scale = containerW / imgW
            let scaledHeight = imgH * scale
            offsetY = (containerH - scaledHeight) / 2.0
        } else {
            scale = containerH / imgH
            let scaledWidth = imgW * scale
            offsetX = (containerW - scaledWidth) / 2.0
        }
        return (scale, offsetX, offsetY)
    }
    
    var body: some View {
        VStack {
            Text("Ajustar Pontos Manualmente")
                .font(.headline).padding()
            if let imgData = record.imageData, let uiImage = UIImage(data: imgData) {
                GeometryReader { geo in
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                        // Draggable points
                        let (scale, offsetX, offsetY) = computeTransform(for: geo.size)
                        // Left pupil point
                        if record.leftPupilPoint != nil {
                            Circle().fill(Color.red)
                                .frame(width: 12, height: 12)
                                .position(x: offsetX + leftPupil.x * scale, y: offsetY + leftPupil.y * scale)
                                .gesture(DragGesture().onChanged { value in
                                    // Update original coords by inverting transform
                                    leftPupil.x += value.translation.width / scale
                                    leftPupil.y += value.translation.height / scale
                                    // Update record point
                                    record.leftPupilPoint = leftPupil
                                })
                        }
                        // Right pupil point
                        if record.rightPupilPoint != nil {
                            Circle().fill(Color.red)
                                .frame(width: 12, height: 12)
                                .position(x: offsetX + rightPupil.x * scale, y: offsetY + rightPupil.y * scale)
                                .gesture(DragGesture().onChanged { value in
                                    rightPupil.x += value.translation.width / scale
                                    rightPupil.y += value.translation.height / scale
                                    record.rightPupilPoint = rightPupil
                                })
                        }
                        // Left frame bottom point
                        if record.leftFrameBottom != nil {
                            Circle().fill(Color.blue)
                                .frame(width: 12, height: 12)
                                .position(x: offsetX + leftBottom.x * scale, y: offsetY + leftBottom.y * scale)
                                .gesture(DragGesture().onChanged { value in
                                    leftBottom.x += value.translation.width / scale
                                    leftBottom.y += value.translation.height / scale
                                    record.leftFrameBottom = leftBottom
                                })
                        }
                        // Right frame bottom point
                        if record.rightFrameBottom != nil {
                            Circle().fill(Color.blue)
                                .frame(width: 12, height: 12)
                                .position(x: offsetX + rightBottom.x * scale, y: offsetY + rightBottom.y * scale)
                                .gesture(DragGesture().onChanged { value in
                                    rightBottom.x += value.translation.width / scale
                                    rightBottom.y += value.translation.height / scale
                                    record.rightFrameBottom = rightBottom
                                })
                        }
                    }
                }
                .padding()
                .onAppear {
                    // Initialize state points from record
                    if let lp = record.leftPupilPoint { leftPupil = lp }
                    if let rp = record.rightPupilPoint { rightPupil = rp }
                    if let lb = record.leftFrameBottom { leftBottom = lb }
                    if let rb = record.rightFrameBottom { rightBottom = rb }
                }
            } else {
                Text("Imagem não disponível")
                    .foregroundColor(.gray)
            }
            Button("Concluir") {
                // Dismiss this adjust view
                presentationMode.wrappedValue.dismiss()
            }
            .padding().foregroundColor(.white).background(Color.blue).cornerRadius(8)
        }
    }
}

