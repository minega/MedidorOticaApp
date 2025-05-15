//
//  ARCoordinator.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//
//

import Foundation
import ARKit
import Vision
import SwiftUI
import simd


struct Medidas: Codable {
    var dp: CGFloat = 0
    var dnpLeft: CGFloat = 0
    var dnpRight: CGFloat = 0
    var altLeft: CGFloat = 0
    var altRight: CGFloat = 0
    var horizontal: CGFloat = 0
    var vertical: CGFloat = 0
    var diagonal: CGFloat = 0
    var ponte: CGFloat = 0
    var distCM: CGFloat = 0
    var alinhada: Bool = false
}

protocol ARCoordinatorDelegate: AnyObject {
    func onProgress(_ progress: Int)
    func onFinish(_ medidas: Medidas, _ imagem: UIImage)
    func onFail(_ mensagem: String)
    func onHint(_ mensagem: String, _ seta: String?)
}

class ARCoordinator: NSObject, ObservableObject,ARSCNViewDelegate, ARSessionDelegate {
    weak var delegate: ARCoordinatorDelegate?
    var useFront: Bool = true
    var autoCap: Bool = false
    private var progress: Int = 0
    private var medidas = Medidas()
    private var jaCapturado = false
    private var cenaView: ARSCNView?

    let minDist: CGFloat = 18
    let maxDist: CGFloat = 45
    let maxYaw: CGFloat = 12
    let maxPitch: CGFloat = 10
    let centerTolX: CGFloat = 0.13
    let centerTolY: CGFloat = 0.14

    enum Seta: String {
        case esquerda = "↩️"
        case direita = "↪️"
        case cima = "⬆️"
        case baixo = "⬇️"
        case nada = ""
    }
    
    func configurarCena(_ view: ARSCNView) {
        self.cenaView = view
        view.delegate = self
        view.session.delegate = self
        view.automaticallyUpdatesLighting = true
        let config = ARFaceTrackingConfiguration()
        config.isWorldTrackingEnabled = true
        config.maximumNumberOfTrackedFaces = 1
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard !jaCapturado, let view = cenaView else { return }
        guard let fa = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            delegate?.onFail("Rosto não detectado")
            return
        }
        let pixelBuffer = frame.capturedImage
        let largura = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let altura = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        
        // 1. Distância rosto-câmera
        let distCM = CGFloat(abs(fa.transform.columns.3.z)) * 100
        medidas.distCM = distCM
        if distCM < minDist {
            enviaProgresso(1, "Aproxime o rosto até pelo menos \(Int(minDist)) cm da câmera.", Seta.baixo.rawValue)
            return
        }
        if distCM > maxDist {
            enviaProgresso(1, "Aproxime o rosto, você está longe! Fique a até \(Int(maxDist)) cm.", Seta.cima.rawValue)
            return
        }
        // 2. Yaw/pitch: orientação da cabeça
        let transform = fa.transform
        // Cálculo correto dos ângulos:
        let yaw = atan2(Double(transform.columns.0.z), Double(transform.columns.0.x)) * 180 / .pi
        let pitch = atan2(-Double(transform.columns.1.z), Double(transform.columns.2.z)) * 180 / .pi

        if abs(yaw) > Double(maxYaw) {
            let lado = yaw > 0 ? "direita" : "esquerda"
            let seta = yaw > 0 ? Seta.direita.rawValue : Seta.esquerda.rawValue
            enviaProgresso(2, "Vire \(Int(abs(yaw)))° para a \(lado).", seta)
            return
        }
        if abs(pitch) > Double(maxPitch) {
            let sentido = pitch > 0 ? "baixo" : "cima"
            let seta = pitch > 0 ? Seta.baixo.rawValue : Seta.cima.rawValue
            enviaProgresso(3, "Ajuste o queixo \(Int(abs(pitch)))° para \(sentido).", seta)
            return
        }
        // 3. Centralização do rosto
        let t = fa.transform
        let x = CGFloat(t.columns.3.x)
        let y = CGFloat(t.columns.3.y)
        if abs(x) > centerTolX {
            let lado = x > 0 ? "direita" : "esquerda"
            let seta = x > 0 ? Seta.direita.rawValue : Seta.esquerda.rawValue
            enviaProgresso(4, "Centralize seu rosto: mova para a \(lado).", seta)
            return
        }
        if abs(y) > centerTolY {
            let sentido = y > 0 ? "baixo" : "cima"
            let seta = y > 0 ? Seta.baixo.rawValue : Seta.cima.rawValue
            enviaProgresso(5, "Ajuste a altura do rosto para \(sentido).", seta)
            return
        }

        // 4. Detecção da armação + alinhamento + medidas faciais exatas
        let leftEye = fa.leftEyeTransform.columns.3
        let rightEye = fa.rightEyeTransform.columns.3
        let nose = pontoCentralNariz(faceAnchor: fa)
        let left = simd_float3(leftEye.x, leftEye.y, leftEye.z)
        let right = simd_float3(rightEye.x, rightEye.y, rightEye.z)

        medidas.dp = CGFloat(simd_distance(left, right)) * 1000
        medidas.dnpLeft = CGFloat(simd_distance(left, nose)) * 1000
        medidas.dnpRight = CGFloat(simd_distance(right, nose)) * 1000

        // Detecção de contornos da armação
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        let contornoReq = VNDetectContoursRequest()
        contornoReq.contrastAdjustment = 1.0
        contornoReq.detectDarkOnLight = true
        var contornoArmacoes: [CGPoint] = []
        do {
            try handler.perform([contornoReq])
            if let obs = contornoReq.results?.first as? VNContoursObservation {
                var pontos: [CGPoint] = []
                // topLevelContours é um array!
                for contour in obs.topLevelContours {
                    for point in contour.normalizedPoints {
                        let pt = CGPoint(
                            x: CGFloat(point.x) * largura,
                            y: (1 - CGFloat(point.y)) * altura
                        )
                        pontos.append(pt)
                    }
                }
                contornoArmacoes = pontos
            }
        } catch { }
        if contornoArmacoes.count < 10 {
            enviaProgresso(6, "Coloque a armação e ajuste para melhor detecção.", nil)
            return
        }
        
        // Alinhamento total da armação (base inferior de ambos os lados)
        let metade = largura / 2
        let ptsEsq = contornoArmacoes.filter { $0.x < metade }
        let ptsDir = contornoArmacoes.filter { $0.x >= metade }
        if let pBaseEsq = ptsEsq.max(by: { $0.y < $1.y }),
           let pBaseDir = ptsDir.max(by: { $0.y < $1.y }) {
            let deltaY = pBaseDir.y - pBaseEsq.y
            let deltaX = pBaseDir.x - pBaseEsq.x
            let anguloRad = atan2(deltaY, deltaX)
            let anguloGraus = anguloRad * 180 / .pi
            medidas.alinhada = abs(anguloGraus) <= 1.5
            if !medidas.alinhada {
                let seta = anguloGraus > 0 ? Seta.direita.rawValue : Seta.esquerda.rawValue
                enviaProgresso(6, "A armação está torta, alinhe até ficar reta.", seta)
                return
            }
        }

        // 5. ALT precisa ser precisa (vertical na reta da pupila)
        for (label, eye, isLeft) in [("altLeft", leftEye, true), ("altRight", rightEye, false)] {
            let xPupila = CGFloat(eye.x) * largura
            let yPupila = CGFloat(eye.y) * altura
            let pontosVerticais = contornoArmacoes.filter { abs($0.x - xPupila) < largura * 0.015 && $0.y > yPupila }
            if let pontoInferior = pontosVerticais.min(by: { $0.y < $1.y }) {
                let altValor = abs(yPupila - pontoInferior.y)
                if isLeft { medidas.altLeft = altValor }
                else { medidas.altRight = altValor }
            }
        }

        // 6. Medidas da armação (horizontal, vertical, diagonal, ponte)
        var maxH: CGFloat = 0
        var maxV: CGFloat = 0
        var maxD: CGFloat = 0
        for i in 0..<contornoArmacoes.count {
            for j in i+1..<contornoArmacoes.count {
                let p1 = contornoArmacoes[i], p2 = contornoArmacoes[j]
                let dx = abs(p1.x - p2.x)
                let dy = abs(p1.y - p2.y)
                let dist = hypot(dx, dy)
                if dy < (altura * 0.15), dx > maxH { maxH = dx }
                if dx < (largura * 0.15), dy > maxV { maxV = dy }
                if dist > maxD { maxD = dist }
            }
        }
        medidas.horizontal = maxH
        medidas.vertical   = maxV
        medidas.diagonal   = maxD
        let meioX = largura/2
        let esquerda = contornoArmacoes.filter { $0.x < meioX }
        let direita  = contornoArmacoes.filter { $0.x > meioX }
        var minBridge: CGFloat = .greatestFiniteMagnitude
        for pL in esquerda {
            for pR in direita {
                let dist = hypot(pL.x - pR.x, pL.y - pR.y)
                if dist < minBridge {
                    minBridge = dist
                }
            }
        }
        medidas.ponte = minBridge

        // 7. Só agora peça para olhar para a câmera!
        let leftZ = Double(leftEye.z)
        let rightZ = Double(rightEye.z)
        let eyeLook = (leftZ + rightZ)/2.0
        if eyeLook > -0.35 {
            enviaProgresso(7, "Olhe diretamente para a câmera!", nil)
            return
        }

        enviaProgresso(8, "Pronto! Capture ou ajuste manualmente.", nil)
        if autoCap && progress == 8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.capturar(view: view)
            }
        }
    }
    
    private func pontoCentralNariz(faceAnchor: ARFaceAnchor) -> simd_float3 {
        let landmarks = faceAnchor.geometry.vertices
        let indicesNariz = [9, 13, 14, 18]
        for idx in indicesNariz {
            if landmarks.indices.contains(idx) {
                return landmarks[idx]
            }
        }
        // fallback: retorna o meio dos olhos, como float3
        let l = faceAnchor.leftEyeTransform.columns.3
        let r = faceAnchor.rightEyeTransform.columns.3
        return simd_float3((l.x + r.x)/2, (l.y + r.y)/2, (l.z + r.z)/2)
    }



    func capturar(view: ARSCNView) {
        guard !jaCapturado else { return }
        jaCapturado = true
        let img = view.snapshot()
        delegate?.onFinish(medidas, img)
    }
    func capturarManual() {
        guard let view = cenaView else { return }
        capturar(view: view)
    }
    func reset() {
        jaCapturado = false
        progress = 0
        medidas = Medidas()
    }
    private func enviaProgresso(_ progress: Int, _ dica: String, _ seta: String?) {
        self.progress = progress
        delegate?.onProgress(progress)
        delegate?.onHint(dica, seta)
    }
}
