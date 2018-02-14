import AVFoundation
import UIKit
import CoreMotion


class ImageCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let captureSession = AVCaptureSession()
    let motionManager = CMMotionManager()
    let accThreshold = 0.5
    let rotThreshold = 0.5

    var imageCaptureQueued = false
    var callback = { (_:UIImage?) in }
    
    
    func requestPermission(_ callback: @escaping (_ : Bool) -> Void) {
        
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        
        switch authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted:Bool) -> Void in
                callback(granted)
            })
        case .authorized:
            callback(true)
        case .denied, .restricted:
            callback(false)
        }
    }
    
    
    func beginSession(_ view: UIView) {
        
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
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.layer.frame
        
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
        self.captureSession.stopRunning()
        
        if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                self.captureSession.removeInput(input)
            }
        }
        
    }
    
    
    func takePhoto(_ callback: @escaping (_ image: UIImage?) -> Void) {
        self.callback = callback
        
        // timers do not work on background queue
        DispatchQueue.main.async() {
            
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { timer in
                
                guard let motion = self.motionManager.deviceMotion else { return }
                
                let acc = motion.userAcceleration
                let rot = motion.rotationRate
                
                // let maxAcc = max(acc.x.magnitude, acc.y.magnitude, acc.z.magnitude)
                // let maxRot = max(rot.x.magnitude, rot.y.magnitude, rot.z.magnitude)
                
                if (acc.x.magnitude < self.accThreshold &&
                    acc.y.magnitude < self.accThreshold &&
                    acc.z.magnitude < self.accThreshold &&
                    rot.x.magnitude < self.rotThreshold &&
                    rot.y.magnitude < self.rotThreshold &&
                    rot.z.magnitude < self.rotThreshold) {
                    
                    // not moving
                    // print(String(format: "NOT moving: %.1f %.1f", maxAcc, maxRot))
                    
                    timer.invalidate()
                    self.imageCaptureQueued = true
                }
                else {
                    // it's moving so wait
                    // print(String(format: "moving: %.1f %.1f", maxAcc, maxRot))
                }
                
            })
        }
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if imageCaptureQueued {
            imageCaptureQueued = false

            guard let image = self.getImageFromSampleBuffer(buffer: sampleBuffer) else {
                self.callback(nil)
                return
            }
            
            let ratio = 0.3905 as CGFloat
            let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            UIGraphicsBeginImageContextWithOptions(newSize, true, 0)
            image.draw(in: CGRect(origin: CGPoint(x: 0, y: 0), size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            self.callback(resizedImage)
        }
    }
    
    
    func getImageFromSampleBuffer (buffer:CMSampleBuffer) -> UIImage? {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            
            let imageRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            
            if let image = context.createCGImage(ciImage, from: imageRect) {
                return UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .right)
            }
        }
        
        return nil
    }
    
}

