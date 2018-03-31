import AVFoundation
import CoreMotion


public protocol CameraDelegate: class {
    func didCaptureImage(pixelBuffer: CVPixelBuffer, motion: MotionObservation) -> Void
    func cameraPermissionGranted() -> Void
    func cameraPermissionDenied() -> Void
}

public struct MotionObservation: Codable {
    var rotationX: Double
    var rotationY: Double
    var rotationZ: Double
    var accelerationX: Double
    var accelerationY: Double
    var accelerationZ: Double
    
    init(_ motion: CMDeviceMotion) {
        rotationX = motion.userAcceleration.x
        rotationY = motion.userAcceleration.y
        rotationZ = motion.userAcceleration.z
        accelerationX = motion.userAcceleration.x
        accelerationY = motion.userAcceleration.y
        accelerationZ = motion.userAcceleration.z
    }

}


class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var delegate : CameraDelegate?
    public var previewLayer: AVCaptureVideoPreviewLayer?
    var imageCaptureQueued = false
    let captureSession = AVCaptureSession()
    let motionManager = CMMotionManager()
    let accelerationThreshold = 0.5
    let rotationThreshold = 0.5
    var shutterSound : AVAudioPlayer!
    var motion : MotionObservation?
    
    
    func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(
                for: AVMediaType.video,
                completionHandler: { granted in
                    if (granted) {
                        self.delegate!.cameraPermissionGranted()
                    } else {
                        self.delegate!.cameraPermissionDenied()
                    }
                }
            )
        case .authorized:
            self.delegate!.cameraPermissionGranted()
        case .denied, .restricted:
            self.delegate!.cameraPermissionDenied()
        }
    }
    
    
    func beginSession() {
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates()
        
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
        let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices
        let captureDevice = availableDevices.first
        
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice!)
            captureSession.addInput(captureDeviceInput)
        } catch {
            print("device error")
            print(error.localizedDescription)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [((kCVPixelBufferPixelFormatTypeKey as NSString) as String):NSNumber(value:kCVPixelFormatType_32BGRA)]
        dataOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
        }
        
        let queue = DispatchQueue(label: "twf.barc")
        dataOutput.setSampleBufferDelegate(self, queue: queue)
        
        captureSession.startRunning()
    }
    
    
    
    func stopSession () {
        captureSession.stopRunning()
        motionManager.stopDeviceMotionUpdates()
        if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                captureSession.removeInput(input)
            }
        }
    }
    
    
    func captureImage() {
        DispatchQueue.main.async() {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { timer in
                guard let motion = self.motionManager.deviceMotion else { return }
                
                self.motion = MotionObservation(motion)
                
                let acc = motion.userAcceleration
                let rot = motion.rotationRate
                
                if (max(acc.x.magnitude, acc.y.magnitude, acc.z.magnitude) < self.accelerationThreshold &&
                    max(rot.x.magnitude, rot.y.magnitude, rot.z.magnitude) < self.rotationThreshold) {
                    
                    timer.invalidate()
                    self.imageCaptureQueued = true
                }
            })
        }
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if imageCaptureQueued, delegate != nil, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            imageCaptureQueued = false
            delegate!.didCaptureImage(pixelBuffer: pixelBuffer, motion: motion!)
        }
        
    }
    
    
}

