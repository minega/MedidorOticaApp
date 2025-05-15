//
//  ARViewContainer.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//

import SwiftUI
import ARKit
import SceneKit
import Combine

// guarda sessão global p/ pausar
private var sharedSession: ARSession?

struct ARViewContainer: UIViewRepresentable {

    // IN
    let useFront: Bool
    @Binding var flashOn: Bool
    @Binding var autoCapOn: Bool
    @Binding var data: MeasurementData
    @Binding var alignMsg: String
    @Binding var eyeMsg: String

    // Publishers
    static let publisher = PassthroughSubject<Record, Never>()
    static let progress  = PassthroughSubject<Int,    Never>()   // NEW
    static var lastSnapshot = UIImage()

    func makeCoordinator() -> ARCoordinator {
        let c = ARCoordinator(
            useFront: useFront,
                    flashOn:  $flashOn,
                    data:     $data,
                    headMsg:  $alignMsg,                // exato “headMsg:”
                    eyeMsg:   $eyeMsg,                  // exato “eyeMsg:”
                    autoCapOn:{ autoCapOn })
        c.onFinish = { (pkg: MeasurementData, snap: UIImage) in
            ARViewContainer.lastSnapshot = snap
            ARViewContainer.publisher.send(
                Record(name: "", snapshot: snap, data: pkg))
        }
        c.onProgress = { p in ARViewContainer.progress.send(p) }   // NEW
        return c
    }

    func makeUIView(context: Context) -> ARSCNView {
        let scn = ARSCNView(frame: .zero)
        scn.delegate = context.coordinator
        context.coordinator.view = scn
        scn.automaticallyUpdatesLighting = true

        // Config AR segura
        let cfg: ARConfiguration = {
            if useFront && ARFaceTrackingConfiguration.isSupported {
                let c = ARFaceTrackingConfiguration()
                c.isLightEstimationEnabled = true; return c
            } else {
                let c = ARWorldTrackingConfiguration()
                if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth){
                    c.frameSemantics.insert(.sceneDepth)
                }
                return c
            }
        }()
        scn.session.run(cfg, options: [.resetTracking,.removeExistingAnchors])
        sharedSession = scn.session                      // guarda
        return scn
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // flash só na câmera traseira
        guard !useFront else { return }
        if let dev = AVCaptureDevice.default(.builtInWideAngleCamera,
                                             for: .video, position: .back),
           dev.hasTorch
        {
            try? dev.lockForConfiguration()
            dev.torchMode = flashOn ? .on : .off
            dev.unlockForConfiguration()
        }
    }

    // chamado em onDisappear
    static func pauseSession() {
        sharedSession?.pause()
        sharedSession = nil
    }
}
