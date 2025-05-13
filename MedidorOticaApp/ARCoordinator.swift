//
//  ARCoordinator.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//
//
//  ARCoordinator.swift   – versão FULL (12 verificações + captura automática)
//

import ARKit
import Vision
import SwiftUI

/// Responsável por toda a lógica de AR + Vision e cálculo das medidas
final class ARCoordinator: NSObject, ARSCNViewDelegate {

    // MARK: – Bindings vindos do SwiftUI
    @Binding var flash: Bool
    @Binding var data:  MeasurementData
    @Binding var headMsg: String
    @Binding var eyeMsg:  String

    let useFront: Bool
    let autoCapOn: () -> Bool            // toggle “captura automática” no ContentView

    /// Callback: retorna MeasurementData + snapshot quando terminar
    var onFinish: (MeasurementData, UIImage) -> Void = {_,_ in}

    weak var view: ARSCNView?            // referência ao ARSCNView criado no UIViewRepresentable

    // MARK: – Parâmetros de tolerância (mude à vontade)
    struct P {
        static var minZ: Float  = 1.5         // distância mínima (m)
        static var maxZ: Float  = 2.2         // distância máxima (m)
        static var yawPitch: Float = 0.03     // rad ≈ 1,7°
        static var centerTol: CGFloat = 40    // px
        static var gazeTol:  Float  = 0.08
        static var maxTilt:  CGFloat = 5      // graus
        static var autoDelay: TimeInterval = 3// s parado → dispara
        static var visionDim = 1024           // máx. dimensão da imagem Vision
    }

    // Vision request reutilizável
    private lazy var contourReq: VNDetectContoursRequest = {
        let r = VNDetectContoursRequest()
        r.contrastAdjustment = 1
        r.detectsDarkOnLight = true
        r.maximumImageDimension = P.visionDim
        return r
    }()

    // Estado da captura automática
    private var goodSince: TimeInterval?
    private var alreadySent = false

    // MARK: – Init
    init(useFront: Bool,
         flash: Binding<Bool>,
         data:  Binding<MeasurementData>,
         head:  Binding<String>,
         eye:   Binding<String>,
         autoCap: @escaping () -> Bool)
    {
        self.useFront = useFront
        _flash = flash
        _data  = data
        _headMsg = head
        _eyeMsg  = eye
        self.autoCapOn = autoCap
    }

    // MARK: – Loop principal
    func renderer(_ r: SCNSceneRenderer,
                  didRenderScene s: SCNScene,
                  atTime t: TimeInterval)
    {
        guard let frame = view?.session.currentFrame,
              let face  = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first
        else { resetAuto(); return }

        // 1) Distância
        let z = abs(face.transform.columns.3.z)
        guard z >= P.minZ && z <= P.maxZ else {
            fail("Dist: \(String(format: "%.2f", z)) m")
            return

        }

        // 2-3) Yaw e Pitch
        let yaw   = atan2(face.transform.columns.0.z, face.transform.columns.0.x)
        let pitch = atan2(face.transform.columns.1.z, face.transform.columns.2.z)
        guard abs(yaw) <= P.yawPitch && abs(pitch) <= P.yawPitch else {
            fail(abs(yaw) > abs(pitch)
                 ? (yaw > 0 ? "Vire ←" : "Vire →")
                 : (pitch > 0 ? "Baixe queixo" : "Levante queixo"))
            return
        }

        // 4-5) Centralização (X e Y)
        let c = view!.bounds.center
        let proj = view!.projectPoint(
            SCNVector3(face.transform.columns.3.x,
                       face.transform.columns.3.y,
                       face.transform.columns.3.z))
        guard abs(CGFloat(proj.x) - c.x) <= P.centerTol,
              abs(CGFloat(proj.y) - c.y) <= P.centerTol else {
            fail("Centralize rosto"); return
        }
        headMsg = "Cabeça OK"

        // 6-7) Gaze (olhar)
        let le = -simd_make_float3(face.leftEyeTransform.columns.2)
        let re = -simd_make_float3(face.rightEyeTransform.columns.2)
        guard abs(le.x) <= P.gazeTol, abs(le.y) <= P.gazeTol,
              abs(re.x) <= P.gazeTol, abs(re.y) <= P.gazeTol else {
            eyeMsg = "Olhe câmera"; resetAuto(); return
        }
        eyeMsg = "Olhos OK"

        // 8) Depth
        guard let depth = frame.sceneDepth?.depthMap else {
            fail("Depth off"); return
        }

        // 9) Vision contorno da lente
        try? VNImageRequestHandler(cvPixelBuffer: frame.capturedImage,
                                   orientation: .right)
            .perform([contourReq])
        guard let obs = contourReq.results?.first as? VNContoursObservation else {
            fail("Lente?"); return
        }

        // 10) Inclinação da armação
        let bb = obs.normalizedPath.boundingBox
        let sz = view!.bounds.size
        let tl2D = CGPoint(x: bb.minX*sz.width, y: (1-bb.minY)*sz.height)
        let tr2D = CGPoint(x: bb.maxX*sz.width, y: (1-bb.minY)*sz.height)
        let tilt = abs(atan2(tr2D.y - tl2D.y, tr2D.x - tl2D.x))*180/CGFloat.pi
        guard tilt <= P.maxTilt else { fail("Tilt \(Int(tilt))°"); return }

        // 11) Projeção 2D → 3D + cálculo
        let pts2D = [
            tl2D, tr2D,
            CGPoint(x: bb.minX*sz.width, y: (1-bb.maxY)*sz.height),
            CGPoint(x: bb.maxX*sz.width, y: (1-bb.maxY)*sz.height)
        ]

        CVPixelBufferLockBaseAddress(depth, .readOnly)
        let w   = CVPixelBufferGetWidth(depth)
        let row = CVPixelBufferGetBytesPerRow(depth)/MemoryLayout<Float32>.size
        let base = CVPixelBufferGetBaseAddress(depth)!
            .assumingMemoryBound(to: Float32.self)
        var pts3: [SCNVector3] = []
        for p in pts2D {
            let x = min(max(Int(p.x), 0), w-1)
            let h = CVPixelBufferGetHeight(depth)
            let y = min(max(Int(p.y), 0), h-1)
            let zDepth = base[y*row + x]
            pts3.append(view!.unprojectPoint(
                SCNVector3(Float(p.x), Float(p.y), zDepth)))
        }
        CVPixelBufferUnlockBaseAddress(depth, .readOnly)

        func dist(_ a: SCNVector3, _ b: SCNVector3) -> Float {
            sqrtf(powf(b.x-a.x,2) + powf(b.y-a.y,2) + powf(b.z-a.z,2))
        }
        let mm: Float = 1000
        data.horizontal = dist(pts3[0], pts3[1]) * mm
        data.vertical   = dist(pts3[0], pts3[2]) * mm
        data.diagonal   = dist(pts3[2], pts3[1]) * mm
        let midT = SCNVector3((pts3[0].x+pts3[1].x)/2,
                              (pts3[0].y+pts3[1].y)/2,
                              (pts3[0].z+pts3[1].z)/2)
        let midB = SCNVector3((pts3[2].x+pts3[3].x)/2,
                              (pts3[2].y+pts3[3].y)/2,
                              (pts3[2].z+pts3[3].z)/2)
        data.ponte = dist(midT, midB) * mm

        // DP & ALT aproximados (use ajuste fino se quiser calibrar)
        let eyeDistM = simd_distance(face.leftEyeTransform.columns.3,
                                     face.rightEyeTransform.columns.3)
        data.dp  = eyeDistM * mm
        data.alt = 18 // placeholder – calibre se precisar

        draw(pts3)                     // (12) Desenha marcadores 3-D

        // Captura automática
        if autoCapOn() {
            if goodSince == nil { goodSince = t }
            if !alreadySent, let start = goodSince,
               t - start >= P.autoDelay {
                deliver()
            }
        } else { resetAuto() }
    }

    // MARK: – Helper: falha / reset / entrega / desenho

    private func fail(_ msg: String) {
        headMsg = msg
        eyeMsg  = ""
        resetAuto()
    }

    private func resetAuto() {
        goodSince   = nil
        alreadySent = false
    }

    private func deliver() {
        let snap = view?.snapshot() ?? UIImage()
        onFinish(data, snap)
        alreadySent = true
        resetAuto()
    }

    private func draw(_ pts: [SCNVector3]) {
        view?.scene.rootNode
            .childNode(withName: "m", recursively: false)?
            .removeFromParentNode()

        let parent = SCNNode()
        parent.name = "m"

        for p in pts {
            let sph = SCNSphere(radius: 0.002)
            sph.firstMaterial?.diffuse.contents = UIColor.green
            let node = SCNNode(geometry: sph)
            node.position = p
            parent.addChildNode(node)
        }
        view?.scene.rootNode.addChildNode(parent)
    }
}
