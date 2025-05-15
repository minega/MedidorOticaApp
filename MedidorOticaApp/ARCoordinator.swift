//
//  ARCoordinator.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//
//

import ARKit
import Vision
import UIKit

class ARCoordinator: NSObject, ObservableObject, ARSessionDelegate, ARSCNViewDelegate {
    // Published properties for UI binding
    @Published var progress: Int = 0
    @Published var message: String? = nil
    @Published var arrow: String? = nil
    @Published var autoCapture: Bool = false
    @Published var flashOn: Bool = false
    @Published var useFront: Bool = true
    @Published var didCapture: Bool = false    // triggers navigation to result
    @Published var canCapture: Bool = false    // whether capture button is enabled
    
    // Captured record to pass to result view
    @Published var capturedRecord: MeasurementData? = nil
    
    // Internal state
    var sceneView: ARSCNView?            // reference to AR scene view
    private var sessionRunning: Bool = false
    private var capturedAlready: Bool = false
    private var autoCaptureTask: DispatchWorkItem? = nil
    
    // Measurements from current session
    private var measures = Measures()
    private var contourPoints: [CGPoint] = []     // detected frame contour points in image coords
    
    // Start AR session with appropriate configuration
    func startSession() {
        guard let sceneView = sceneView else { return }
        let configuration: ARConfiguration
        if useFront, ARFaceTrackingConfiguration.isSupported {
            // Front TrueDepth camera for face tracking
            let faceConfig = ARFaceTrackingConfiguration()
            faceConfig.isLightEstimationEnabled = true
            configuration = faceConfig
        } else {
            // Back camera: use world tracking just to get camera frames
            let worldConfig = ARWorldTrackingConfiguration()
            worldConfig.isLightEstimationEnabled = true
            configuration = worldConfig
        }
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        sessionRunning = true
        // Ensure flash state (if rear camera)
        updateFlashlight()
    }
    
    // Stop AR session
    func endSession() {
        sceneView?.session.pause()
        sessionRunning = false
        // Turn off flash if it was on
        if flashOn {
            toggleFlash()
        }
    }
    
    // Switch between front and back camera
    func switchCamera() {
        guard sessionRunning else { return }
        // Pause current session
        sceneView?.session.pause()
        sessionRunning = false
        // Toggle camera flag
        useFront.toggle()
        capturedAlready = false
        progress = 0
        message = nil
        arrow = nil
        // Restart session with new configuration
        startSession()
    }
    
    // Toggle flash (torch) on rear camera
    func toggleFlash() {
        flashOn.toggle()
        updateFlashlight()
    }
    private func updateFlashlight() {
        guard !useFront, let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                device.torchMode = flashOn ? .on : .off
                device.unlockForConfiguration()
            } catch {
                print("Error toggling flash: \(error)")
            }
        }
    }
    
    // MARK: - Capture Logic
    
    // Manually trigger capture (called from UI buttons or auto-capture timer)
    func captureNow() {
        guard let sceneView = sceneView, !capturedAlready else { return }
        capturedAlready = true
        // Pause the session to freeze the frame
        sceneView.session.pause()
        // Take snapshot of the ARSCNView (camera image)
        let uiImage = sceneView.snapshot()
        
        // Prepare a new record with captured data
        var record = MeasurementData()
        // Fill in measurement values
        record.dp = measures.dp
        record.dnpLeft = measures.dnpLeft
        record.dnpRight = measures.dnpRight
        record.frameTilt = measures.frameTilt  // might be nil if not applicable
        // Save image as JPEG data
        if let jpegData = uiImage.jpegData(compressionQuality: 0.9) {
            record.imageData = jpegData
            record.imageSize = CGSize(width: uiImage.size.width * uiImage.scale,
                                       height: uiImage.size.height * uiImage.scale)
        }
        // Save key points for overlay (if available)
        if let leftEyePt = measures.leftEyePoint, let rightEyePt = measures.rightEyePoint {
            record.leftPupilPoint = leftEyePt
            record.rightPupilPoint = rightEyePt
        }
        if let leftBase = measures.leftFrameBottom, let rightBase = measures.rightFrameBottom {
            record.leftFrameBottom = leftBase
            record.rightFrameBottom = rightBase
        }
        
        // Set up for navigation to result view
        self.capturedRecord = record
        self.didCapture = true
        // Cancel any pending auto-capture tasks
        autoCaptureTask?.cancel()
        autoCaptureTask = nil
        // Disable flashlight after capture if it was on (to save battery)
        if flashOn {
            toggleFlash()
        }
    }
    
    // Reset state to allow a new measurement in the same session
    func resetMeasurement() {
        capturedAlready = false
        progress = 0
        message = nil
        arrow = nil
        measures = Measures()
        contourPoints.removeAll()
        didCapture = false
        capturedRecord = nil
        // Resume session if needed
        if let sceneView = sceneView, sessionRunning == false {
            sceneView.session.run(sceneView.session.configuration ?? ARWorldTrackingConfiguration())
            sessionRunning = true
        }
    }
    
    // MARK: - ARSessionDelegate (camera frames and tracking)
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // If already captured, do nothing
        if capturedAlready { return }
        
        // If using rear camera, perform Vision face detection
        var faceAnchor: ARFaceAnchor? = nil
        if useFront {
            // For front camera, find ARFaceAnchor from frame anchors
            faceAnchor = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first
        }
        
        // Prepare variables for validations
        var faceDetected = false
        var distanceOK = false
        var yawOK = false
        var pitchOK = false
        var centeredOK = false
        var framesOK = false
        
        // Check if face is present
        if useFront, let fAnchor = faceAnchor {
            faceDetected = true
            // Compute distance from camera
            let facePos = fAnchor.transform.columns.3   // position of face anchor relative to camera
            let distance = simd_length(simd_float3(facePos.x, facePos.y, facePos.z))
            // Evaluate distance within acceptable range
            let minDist: Float = 0.25    // 25 cm
            let maxDist: Float = 0.60    // 60 cm
            if distance < minDist {
                message = "Afaste-se um pouco"
                arrow = nil
                distanceOK = false
            } else if distance > maxDist {
                message = "Aproxime-se um pouco"
                arrow = nil
                distanceOK = false
            } else {
                distanceOK = true
            }
            // If distance not OK, we stop further processing
            if !distanceOK {
                progress = 0
            }
            
            if distanceOK {
                // Gaze direction check - ensure user looks at camera
                if let blendShapes = fAnchor.blendShapes as? [ARFaceAnchor.BlendShapeLocation: Any] {
                    let eyeLookInLeft = (blendShapes[.eyeLookInLeft] as? Float) ?? 0
                    let eyeLookOutLeft = (blendShapes[.eyeLookOutLeft] as? Float) ?? 0
                    let eyeLookInRight = (blendShapes[.eyeLookInRight] as? Float) ?? 0
                    let eyeLookOutRight = (blendShapes[.eyeLookOutRight] as? Float) ?? 0
                    let eyeLookUpLeft = (blendShapes[.eyeLookUpLeft] as? Float) ?? 0
                    let eyeLookDownLeft = (blendShapes[.eyeLookDownLeft] as? Float) ?? 0
                    let eyeLookUpRight = (blendShapes[.eyeLookUpRight] as? Float) ?? 0
                    let eyeLookDownRight = (blendShapes[.eyeLookDownRight] as? Float) ?? 0
                    // If eyes are looking significantly away (horizontal or vertical)
                    if eyeLookInLeft + eyeLookOutLeft > 0.6 || eyeLookInRight + eyeLookOutRight > 0.6 ||
                        eyeLookUpLeft + eyeLookDownLeft > 0.6 || eyeLookUpRight + eyeLookDownRight > 0.6 {
                        // User is not looking straight at camera
                        progress = 0
                        message = "Olhe diretamente para a câmera!"
                        arrow = nil
                        return
                    }
                }
                // Compute head rotation (yaw and pitch)
                let node = SCNNode()
                node.simdTransform = fAnchor.transform   // face transform relative to camera
                let euler = node.eulerAngles
                let yawDeg = euler.y * 180.0 / Float.pi
                let pitchDeg = euler.x * 180.0 / Float.pi
                // Yaw (left-right orientation)
                let yawThreshold: Float = 5.0
                if abs(yawDeg) > yawThreshold {
                    arrow = yawDeg > 0 ? "➡️" : "⬅️"
                    let direction = yawDeg > 0 ? "direita" : "esquerda"
                    message = "Vire \(Int(abs(yawDeg)))° à \(direction)"
                    yawOK = false
                } else {
                    yawOK = true
                }
                // Pitch (up-down orientation)
                let pitchThreshold: Float = 5.0
                if abs(pitchDeg) > pitchThreshold {
                    arrow = pitchDeg > 0 ? "⬇️" : "⬆️"
                    let direction = pitchDeg > 0 ? "abaixe" : "levante"
                    message = "\(direction) o queixo \(Int(abs(pitchDeg)))°"
                    pitchOK = false
                } else {
                    pitchOK = true
                }
                // If either yaw or pitch is not OK, then show corresponding message and stop further checks
                if !yawOK || !pitchOK {
                    progress = 1  // face detected & distance OK, but alignment not done
                    // (Keep progress at 1 so that "Distância OK" is checked, others not yet)
                    return
                }
                // At this point, head is properly aligned (both yaw and pitch)
                // Centering check: ensure face is centered in view horizontally
                let offsetX = fAnchor.transform.columns.3.x   // horizontal offset in meters
                if abs(offsetX) < 0.03 {
                    centeredOK = true
                } else {
                    centeredOK = false
                }
                if !centeredOK {
                    // No explicit message for centering; user can adjust via overlay
                    progress = 3  // distance + yaw + pitch OK
                    arrow = nil
                    message = nil
                    // Don't return; allow frame detection even if not perfectly centered,
                    // but capture button won't enable until centered.
                }
            }
        } else if !useFront {
            // Using rear camera: perform Vision-based face detection
            guard let pixelBuffer = frame.capturedImage as CVPixelBuffer? else {
                progress = 0
                return
            }
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            let faceDetectRequest = VNDetectFaceLandmarksRequest()
            do {
                try imageRequestHandler.perform([faceDetectRequest])
            } catch {
                print("Vision face detect error: \(error)")
            }
            if let faceObs = faceDetectRequest.results?.first as? VNFaceObservation {
                faceDetected = true
                // Rough distance check using face bounding box size
                let bbox = faceObs.boundingBox  // normalized coordinates
                // If face box is too small or too large relative to frame, user is too far/close
                if bbox.width < 0.2 {
                    message = "Aproxime-se um pouco"
                    distanceOK = false
                } else if bbox.width > 0.6 {
                    message = "Afaste-se um pouco"
                    distanceOK = false
                } else {
                    distanceOK = true
                }
                if !distanceOK {
                    progress = 0
                }
                if distanceOK {
                    // Head orientation from face observation (Vision can estimate yaw)
                    if let yawRadians = faceObs.yaw?.doubleValue {
                        let yawDeg = Float(yawRadians * 180.0 / .pi)
                        if abs(yawDeg) > 10 {
                            arrow = yawDeg > 0 ? "➡️" : "⬅️"
                            let direction = yawDeg > 0 ? "direita" : "esquerda"
                            message = "Vire \(Int(abs(yawDeg)))° à \(direction)"
                            yawOK = false
                        } else {
                            yawOK = true
                        }
                    } else {
                        yawOK = true
                    }
                    // Note: Vision faceObs.pitch is not available (pitch always nil in Vision), so we skip pitch for rear.
                    pitchOK = true
                    if !yawOK {
                        progress = 1
                        return
                    }
                    // Centering: check face bounding box center
                    let faceCenterX = faceObs.boundingBox.midX
                    if abs(faceCenterX - 0.5) < 0.1 {
                        centeredOK = true
                    } else {
                        centeredOK = false
                    }
                    // no explicit message for centering on rear camera
                }
            } else {
                faceDetected = false
            }
        }
        
        // Evaluate overall progress from the above flags
        if faceDetected == false {
            // No face found
            progress = 0
            message = "Posicione o rosto no oval"
            arrow = nil
            return
        }
        
        // If we reach here, face is detected. Determine progress milestones.
        if useFront {
            // Front camera case: we already updated progress in alignment checks.
            // distanceOK, yawOK, pitchOK, centeredOK are all relevant here.
            if distanceOK {
                progress = 1
                if yawOK && pitchOK {
                    progress = 3  // yaw and pitch aligned
                    if centeredOK {
                        progress = 4  // face centered as well
                    }
                }
            }
        } else {
            // Rear camera case:
            if faceDetected && distanceOK {
                progress = 1
                if yawOK {
                    progress = 2
                    // (We skip pitch for rear)
                    progress = 3
                    if centeredOK {
                        progress = 4
                    }
                }
            }
        }
        
        // At this point, progress is up to 4 (all face validations done) if all conditions met.
        // Next: detect eyeglasses frame (if using front camera, since rear detection for frames is complex)
        contourPoints.removeAll()
        framesOK = false
        if useFront, let fAnchor = faceAnchor, let pixelBuffer = frame.capturedImage as CVPixelBuffer? {
            // Use Vision contours to detect glasses frame edges
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            let contourRequest = VNDetectContoursRequest()
            // Adjust parameters for better detection of thin frames
            contourRequest.contrastAdjustment = 1.0
            contourRequest.detectDarkOnLight = true  // initial assumption: dark frame on light background
            do {
                try handler.perform([contourRequest])
                if let obs = contourRequest.results?.first as? VNContoursObservation {
                    // Retrieve all normalized points from all contours
                    var pts: [CGPoint] = []
                    for idx in 0 ..< obs.contourCount {
                        if let contour = try? obs.contour(at: idx) {
                            if contour.indexPath.count == 1 {
                                let cgPoints = contour.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
                                pts.append(contentsOf: cgPoints)
                            }
                        }
                    }
                    // Convert normalized points to image pixel coordinates
                    let width = CVPixelBufferGetWidth(pixelBuffer)
                    let height = CVPixelBufferGetHeight(pixelBuffer)
                    contourPoints = pts.map { CGPoint(x: $0.x * CGFloat(width), y: (1 - $0.y) * CGFloat(height)) }
                }
            } catch {
                print("Contour detection error: \(error)")
            }
            // If not enough contour points detected, try alternate parameters (light frame on dark background)
            if contourPoints.count < 10 {
                contourPoints.removeAll()
                contourRequest.detectDarkOnLight = false
                contourRequest.contrastAdjustment = 1.0
                do {
                    try handler.perform([contourRequest])
                    if let obs = contourRequest.results?.first as? VNContoursObservation {
                        var pts: [CGPoint] = []
                        for idx in 0 ..< obs.contourCount {
                            if let contour = try? obs.contour(at: idx) {
                                if contour.indexPath.count == 1 {
                                    let cgPoints = contour.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
                                    pts.append(contentsOf: cgPoints)
                                }
                            }
                        }
                        let width = CVPixelBufferGetWidth(pixelBuffer)
                        let height = CVPixelBufferGetHeight(pixelBuffer)
                        contourPoints = pts.map { CGPoint(x: $0.x * CGFloat(width), y: (1 - $0.y) * CGFloat(height)) }
                    }
                } catch {
                    // ignore errors
                }
            }
            if contourPoints.count < 10 {
                // Not enough frame edges detected
                framesOK = false
            } else {
                framesOK = true
            }
        }
        
        // If frames are expected but not detected, optionally prompt user
        if useFront && !framesOK {
            // If the user has not put on glasses yet (or wearing frameless glasses), we allow capture at DP stage.
            // We will not force progress reset to 0 here unless we explicitly want to prompt for glasses.
            // We'll just keep progress at whatever face validations achieved (up to 4).
        }
        if framesOK {
            // All validations including frame presence are good
            progress = 5
        }
        
        // Update measure values continuously if possible (for display after capture)
        if useFront, let fAnchor = faceAnchor {
            // Pupillary distance (distance between eyes in mm)
            let leftEyePos = fAnchor.leftEyeTransform.columns.3
            let rightEyePos = fAnchor.rightEyeTransform.columns.3
            // Nose (bridge) position: use face mesh to get approximate nose tip
            let nosePos = getNoseCenter(faceAnchor: fAnchor)
            // Calculate distances in mm
            let distEyes = simd_distance(simd_float3(leftEyePos.x, leftEyePos.y, leftEyePos.z),
                                         simd_float3(rightEyePos.x, rightEyePos.y, rightEyePos.z)) * 1000.0
            let distLeftNose = simd_distance(simd_float3(leftEyePos.x, leftEyePos.y, leftEyePos.z),
                                             simd_float3(nosePos.x, nosePos.y, nosePos.z)) * 1000.0
            let distRightNose = simd_distance(simd_float3(rightEyePos.x, rightEyePos.y, rightEyePos.z),
                                              simd_float3(nosePos.x, nosePos.y, nosePos.z)) * 1000.0
            measures.dp = distEyes
            measures.dnpLeft = distLeftNose
            measures.dnpRight = distRightNose
            // Project key points to 2D image coordinates for overlay
             let camera = frame.camera
                let imageWidth = CGFloat(frame.camera.imageResolution.width)
                let imageHeight = CGFloat(frame.camera.imageResolution.height)
                let leftEye2D = camera.projectPoint(simd_float3(leftEyePos.x, leftEyePos.y, leftEyePos.z),
                                                    orientation: .portrait, viewportSize: CGSize(width: imageWidth, height: imageHeight))
                let rightEye2D = camera.projectPoint(simd_float3(rightEyePos.x, rightEyePos.y, rightEyePos.z),
                                                     orientation: .portrait, viewportSize: CGSize(width: imageWidth, height: imageHeight))
                measures.leftEyePoint = leftEye2D
                measures.rightEyePoint = rightEye2D
            
            // If frames detected, compute frame alignment (tilt) using bottom-most points on each side
            if framesOK, !contourPoints.isEmpty {
                // Find bottom points of the frame on left and right side
                let width = CVPixelBufferGetWidth(frame.capturedImage)
                let midX = CGFloat(width) / 2.0
                let leftSidePoints = contourPoints.filter { $0.x < midX }
                let rightSidePoints = contourPoints.filter { $0.x >= midX }
                if let lowestLeft = leftSidePoints.max(by: { $0.y < $1.y }),
                   let lowestRight = rightSidePoints.max(by: { $0.y < $1.y }) {
                    measures.leftFrameBottom = lowestLeft
                    measures.rightFrameBottom = lowestRight
                    // Compute tilt angle in degrees between the two bottom points
                    let dx = Float(lowestRight.x - lowestLeft.x)
                    let dy = Float(lowestRight.y - lowestLeft.y)
                    let angleRad = atan2(dy, dx)
                    let angleDeg = angleRad * 180.0 / Float.pi
                    measures.frameTilt = abs(angleDeg)
                }
            } else {
                measures.frameTilt = nil
            }
        }
        // Determine if capture button can be enabled
        // If user is wearing glasses (frames detected), require all 5 validations. If not, require 4.
        let requiredProgress = framesOK ? 5 : 4
        canCapture = progress >= requiredProgress
        
        // Handle auto-capture if enabled
        if autoCapture {
            let required = requiredProgress
            if progress >= required && !capturedAlready {
                if autoCaptureTask == nil {
                    // Schedule automatic capture after brief delay
                    let task = DispatchWorkItem { [weak self] in
                        self?.captureNow()
                    }
                    autoCaptureTask = task
                    // Provide a heads-up message to user
                    message = "Pronto! Capturando..."
                    arrow = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
                }
            } else {
                // If conditions fell off or not ready, cancel any pending auto-capture
                if let task = autoCaptureTask {
                    task.cancel()
                    autoCaptureTask = nil
                    // Remove "capturing..." message if it was set
                    if message?.hasPrefix("Pronto") == true {
                        message = nil
                    }
                }
            }
        }
    }
    
    // Helper: approximate nose center using face mesh vertices or midpoint of eyes
    private func getNoseCenter(faceAnchor: ARFaceAnchor) -> simd_float4 {
         let mesh = faceAnchor.geometry
            let vertices = mesh.vertices
            // Possible indices for nose tip area
            let noseIndices: [Int] = [9, 14, 18, 24, 19]
            for idx in noseIndices {
                if idx < vertices.count {
                    let v = vertices[idx]
                    return simd_float4(v.x, v.y, v.z, 1.0)
                }
            }
        
        // Fallback: midpoint between eyes
        let leftEye = faceAnchor.leftEyeTransform.columns.3
        let rightEye = faceAnchor.rightEyeTransform.columns.3
        let mid = (leftEye + rightEye) / 2.0
        return mid
    }
}
