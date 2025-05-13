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

/// UIViewRepresentable que mostra AR, controla flash, captura snapshot e publica Record via Combine.
struct ARViewContainer: UIViewRepresentable {
    // IN
    let useFront: Bool
    @Binding var flashOn: Bool
    @Binding var autoCapOn: Bool
    @Binding var data: MeasurementData
    @Binding var alignMsg: String
    @Binding var eyeMsg: String

    // OUT
    static let publisher = PassthroughSubject<Record, Never>()
    static var lastSnapshot = UIImage()

    func makeCoordinator() -> ARCoordinator {
        let c = ARCoordinator(useFront: useFront,
                              flash: $flashOn,
                              data: $data,
                              head: $alignMsg,
                              eye:  $eyeMsg,
                              autoCap: { autoCapOn })
        c.onFinish = { pkg, snap in
            ARViewContainer.lastSnapshot = snap
            ARViewContainer.publisher.send(Record(name: "", snapshot: snap, data: pkg))
        }
        return c
    }

    func makeUIView(context: Context) -> ARSCNView {
        let scn = ARSCNView(frame:.zero)
        scn.delegate = context.coordinator
        context.coordinator.view = scn
        scn.automaticallyUpdatesLighting = true
        let cfg: ARConfiguration = {
            if useFront && ARFaceTrackingConfiguration.isSupported {
                let c = ARFaceTrackingConfiguration(); c.isLightEstimationEnabled = true; return c
            } else {
                let c = ARWorldTrackingConfiguration();
                if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) { c.frameSemantics.insert(.sceneDepth) }
                return c
            }
        }()
        scn.session.run(cfg, options: [.resetTracking,.removeExistingAnchors])
        return scn
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        guard let dev = AVCaptureDevice.default(for: .video), dev.hasTorch else { return }
        try? dev.lockForConfiguration(); dev.torchMode = flashOn ? .on : .off; dev.unlockForConfiguration()
    }
}
