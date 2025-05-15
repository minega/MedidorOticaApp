//
//  ARCoordinator.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//
//

//
//  ARCoordinator.swift
//  MedidorOticaApp
//
//  Versão atualizada: distância dinâmica, mensagens claras de yaw/pitch,
//  prevenção de crash na câmera traseira, projeção 2D→3D corrigida,
//  auto-cap, DNP, ALT e DP implementados.
//  Created by ChatGPT em 05/2025.
//

import ARKit
import Vision
import SwiftUI

// MARK: – Helpers
extension simd_float4 { var xyz: simd_float3 { simd_float3(x,y,z) } }
extension SCNVector3 { var v: simd_float3 { simd_float3(x,y,z) } }
extension CIImage {
    func toUIImage() -> UIImage? {
        guard let cg = CIContext().createCGImage(self, from: extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
extension VNContoursObservation {
    /// fake box quando não houver armação (camera traseira)
    convenience init(fake bb: CGRect) { self.init(); setValue(bb, forKey: "boundingBox") }
}

// MARK: – ARCoordinator
final class ARCoordinator: NSObject, ARSCNViewDelegate {

    // Bindings vindos do SwiftUI
    @Binding var flashOn: Bool
    @Binding var data: MeasurementData
    @Binding var headMsg: String
    @Binding var eyeMsg: String

    let useFront: Bool
    let autoCapOn: () -> Bool

    // Callbacks
    var onFinish:   (MeasurementData, UIImage) -> Void = {_,_ in}
    var onProgress: (Int) -> Void = { _ in }

    weak var view: ARSCNView?

    // Parâmetros
    struct P {
        static let yawPitchRad: Float   = 0.03      // ≈1.7°
        static let gazeTol:     Float   = 0.1
        static let centerTol:   CGFloat = 50
        static let maxTiltDeg:  CGFloat = 5
        static let autoDelay:   TimeInterval = 3
        static let visionDim:   Int = 1024
    }

    // Vision Requests
    private let faceReq    = VNDetectFaceLandmarksRequest()
    private let contourReq: VNDetectContoursRequest = {
        let r = VNDetectContoursRequest()
        r.contrastAdjustment    = 1
        r.detectsDarkOnLight    = true
        r.maximumImageDimension = P.visionDim
        return r
    }()

    // Auto-captura
    private var goodSince: TimeInterval?
    private var alreadySent = false

    init(useFront: Bool,
         flashOn: Binding<Bool>,
         data: Binding<MeasurementData>,
         headMsg: Binding<String>,
         eyeMsg: Binding<String>,
         autoCapOn: @escaping ()->Bool)
    {
        self.useFront  = useFront
        _flashOn       = flashOn
        _data          = data
        _headMsg       = headMsg
        _eyeMsg        = eyeMsg
        self.autoCapOn = autoCapOn
    }

    // MARK: – Loop de renderização
    func renderer(_ renderer: SCNSceneRenderer,
                  didRenderScene scene: SCNScene,
                  atTime time: TimeInterval)
    {
        guard let frame = view?.session.currentFrame else {
            onProgress(0); resetAuto(); return
        }

        var score = 0
        let mm: Float = 1000

        // 1) DISTÂNCIA DINÂMICA FRONT/TRASEIRA
        let zMeters: Float
        if useFront {
            // ARFaceAnchor do ARKit
            guard let fa = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
                fail("Posicione o rosto"); return
            }
            zMeters = abs(fa.transform.columns.3.z)
        } else {
            // Vision + SceneDepth para câmera traseira
            try? VNImageRequestHandler(cvPixelBuffer: frame.capturedImage,
                                       orientation: .right).perform([faceReq])
            guard let fo = faceReq.results?.first as? VNFaceObservation else {
                fail("Sem rosto"); return
            }

            // gira no ponto do nariz (se existir)
            let sz = CGSize(width: CVPixelBufferGetWidth(frame.capturedImage),
                            height: CVPixelBufferGetHeight(frame.capturedImage))
            var p = CGPoint(x: fo.boundingBox.midX * sz.width,
                            y: (1 - fo.boundingBox.midY) * sz.height)
            if let nose = fo.landmarks?.nose?.normalizedPoints.first {
                p = CGPoint(x: nose.x * sz.width, y: (1 - nose.y) * sz.height)
            }

            guard let depthMap = frame.sceneDepth?.depthMap else {
                fail("Depth indisponível"); return
            }
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            let w     = CVPixelBufferGetWidth(depthMap)
            let row   = CVPixelBufferGetBytesPerRow(depthMap)/MemoryLayout<Float32>.size
            let base  = CVPixelBufferGetBaseAddress(depthMap)!
                         .assumingMemoryBound(to: Float32.self)
            let x     = min(max(0, Int(p.x)), w-1)
            let y     = min(max(0, Int(p.y)), CVPixelBufferGetHeight(depthMap)-1)
            zMeters   = base[y*row + x]
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
        }

        // limites front / back
        let (minZ, maxZ): (Float, Float) = useFront ? (0.35, 0.80) : (0.60, 1.20)
        guard zMeters >= minZ, zMeters <= maxZ else {
            fail(String(format: "Dist %.0f cm", zMeters*100)); return
        }
        data.distCM = zMeters*100
        score += 1; onProgress(score)

        // 2) CABEÇA: YAW / PITCH + FORÇA CAPTURA
        var faOptional: ARFaceAnchor? = nil
        if useFront {
            faOptional = frame.anchors.compactMap{ $0 as? ARFaceAnchor }.first
            if faOptional == nil {
                fail("Posicione o rosto"); return
            }
        }

        if let fa = faOptional {
            // yaw/pitch em rad e em deg
            let yaw   = atan2(fa.transform.columns.0.z, fa.transform.columns.0.x)
            let pitch = atan2(fa.transform.columns.1.z, fa.transform.columns.2.z)
            let yawDeg   = yaw   * 180 / .pi
            let pitchDeg = pitch * 180 / .pi

            // Yaw
            guard abs(yaw) <= P.yawPitchRad else {
                let txt = yawDeg > 0
                    ? "↩ Vire \(Int(abs(yawDeg)))° à esquerda"
                    : "↪ Vire \(Int(abs(yawDeg)))° à direita"
                fail(txt); return
            }
            score += 1; onProgress(score)

            // Pitch
            guard abs(pitch) <= P.yawPitchRad else {
                let txt = pitchDeg > 0
                    ? "⬆ Levante queixo \(Int(abs(pitchDeg)))°"
                    : "⬇ Abaixe queixo \(Int(abs(pitchDeg)))°"
                fail(txt); return
            }
            headMsg = "Cabeça OK"
            score += 1; onProgress(score)
        }

        // centralização
        let center = view!.bounds.center
        let proj   = view!.projectPoint(
            SCNVector3(frame.camera.transform.columns.3.xyz)
        )
        let dx = CGFloat(proj.x) - center.x
        let dy = CGFloat(proj.y) - center.y

        // se saiu do oval em X
        if abs(dx) > P.centerTol {
            headMsg = dx > 0
                ? "Mova seu rosto PARA A ESQUERDA"
                : "Mova seu rosto PARA A DIREITA"
            eyeMsg = ""
            resetAuto()
            onProgress(score)  // mantém progresso atual
            return
        }

        // se saiu do oval em Y
        if abs(dy) > P.centerTol {
            headMsg = dy > 0
                ? "Abaixe o dispositivo"
                : "Levante o dispositivo"
            eyeMsg = ""
            resetAuto()
            onProgress(score)
            return
        }

        // dentro do oval!
        headMsg = "Rosto centralizado"
        score += 1
        onProgress(score)

        // ── 5) GAZE — apenas no final, olhe PARA A CÂMERA ─────────────────
        if useFront, score >= 4, let fa = faOptional{
            let leDir = -simd_make_float3(fa.leftEyeTransform .columns.2)
            let reDir = -simd_make_float3(fa.rightEyeTransform.columns.2)

            guard abs(leDir.x) <= P.gazeTol,
                  abs(leDir.y) <= P.gazeTol,
                  abs(reDir.x) <= P.gazeTol,
                  abs(reDir.y) <= P.gazeTol else
            {
                // instrui o usuário a olhar só no final, depois de alinhar cabeça+centro
                headMsg = ""
                eyeMsg  = "Olhe para a câmera"
                resetAuto()
                onProgress(score)
                return
            }

            // se chegou aqui, os olhos estão alinhados
            eyeMsg = "Olhos alinhados"
            score += 1
            onProgress(score)
        }

        // autoCap forçado
        if autoCapOn(), score >= 5 {
            deliver()
        }

        // 3) DEPTH (já garantido no passo 1 p/ back, mas ok)
        guard frame.sceneDepth?.depthMap != nil else {
            fail("Depth off"); return
        }
        score += 1; onProgress(score)

        // 4) VISION (contorno / tilt)
        try? VNImageRequestHandler(cvPixelBuffer: frame.capturedImage,
                                   orientation: .right).perform([contourReq])
        let obs: VNContoursObservation
        if let first = contourReq.results?.first as? VNContoursObservation {
            obs = first
        } else {
            fail("Coloque armação"); return
        }
        let bb = obs.normalizedPath.boundingBox
        let sz = view!.bounds.size
        let tl = CGPoint(x: bb.minX*sz.width,  y: (1-bb.minY)*sz.height)
        let tr = CGPoint(x: bb.maxX*sz.width,  y: (1-bb.minY)*sz.height)
        let tilt = abs(atan2(tr.y-tl.y, tr.x-tl.x))*180/CGFloat.pi
        guard tilt <= P.maxTiltDeg else {
            fail("Tilt \(Int(tilt))°"); return
        }
        score += 1; onProgress(score)

        // 5) PROJEÇÃO 2D→3D + CÁLCULO MEDIDAS
        guard let depthMap = frame.sceneDepth?.depthMap else {
            fail("Depth off"); return
        }
        let pts2D = [
            tl,
            tr,
            CGPoint(x: bb.minX*sz.width, y: (1-bb.maxY)*sz.height),
            CGPoint(x: bb.maxX*sz.width, y: (1-bb.maxY)*sz.height)
        ]
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        let w   = CVPixelBufferGetWidth(depthMap)
        let row = CVPixelBufferGetBytesPerRow(depthMap)/MemoryLayout<Float32>.size
        let baseAddr = CVPixelBufferGetBaseAddress(depthMap)!
                         .assumingMemoryBound(to: Float32.self)

        var pts3: [SCNVector3] = []
        for p in pts2D {
            let x = min(max(0, Int(p.x)), w-1)
            let y = min(max(0, Int(p.y)), CVPixelBufferGetHeight(depthMap)-1)
            let z = baseAddr[y*row + x]
            pts3.append(view!.unprojectPoint(
                SCNVector3(Float(p.x), Float(p.y), z)))
        }
        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)

        func dist(_ a: SCNVector3, _ b: SCNVector3) -> Float {
            sqrtf(powf(b.x-a.x,2)+powf(b.y-a.y,2)+powf(b.z-a.z,2))
        }
        data.horizontal = dist(pts3[0],pts3[1])*mm
        data.vertical   = dist(pts3[0],pts3[2])*mm
        data.diagonal   = dist(pts3[2],pts3[1])*mm

        let midT = simd_float3((pts3[0].v + pts3[1].v)/2)
        let midB = simd_float3((pts3[2].v + pts3[3].v)/2)
        data.ponte = simd_distance(midT, midB)*mm

        // DP, DNP & ALT (se front)
        if useFront, let fa = faOptional {
            let lp = fa.leftEyeTransform .columns.3.xyz
            let rp = fa.rightEyeTransform.columns.3.xyz
            data.dp = simd_distance(lp, rp)*mm

            let centerX = (pts3[0].x + pts3[1].x)/2
            data.dnpLeft  = abs(Float(centerX) - pts3[0].x)*mm
            data.dnpRight = abs(Float(pts3[1].x) - centerX)*mm

            let eyeMidY = (lp.y + rp.y)/2
            data.alt = abs(eyeMidY - midB.y)*mm
        }

        // snapshot HD final
        if let img = CIImage(cvPixelBuffer: frame.capturedImage)
                          .oriented(.right)
                          .toUIImage() {
            onFinish(data, img)
        }

        drawMarkers(pts3)
        // auto-captura contínua
        if autoCapOn() {
            if goodSince == nil { goodSince = time }
            if !alreadySent, let s = goodSince,
               time - s >= P.autoDelay {
                deliver()
            }
        } else {
            resetAuto()
        }
    }

    // MARK: – Auxiliares
    private func fail(_ msg: String) {
        headMsg = msg
        eyeMsg  = ""
        onProgress(0)
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
    private func drawMarkers(_ pts: [SCNVector3]) {
        view?.scene.rootNode.childNode(withName: "m", recursively: false)?
            .removeFromParentNode()
        let parent = SCNNode()
        parent.name = "m"
        for p in pts {
            let sphere = SCNSphere(radius: 0.002)
            sphere.firstMaterial?.diffuse.contents = UIColor.red
            let node = SCNNode(geometry: sphere)
            node.position = p
            parent.addChildNode(node)
        }
        view?.scene.rootNode.addChildNode(parent)
    }
}
