import UIKit
import AVFoundation
import Vision


class ViewController: UIViewController, CameraDelegate, NeuralNetworkDelegate {
    
    let voice = Voice()
    let camera = Camera()
    let service = WebService()
    let neuralNet = NeuralNetwork()
    var failSound : AVAudioPlayer!
    var image : CVPixelBuffer?
    var motionData : MotionObservation?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        camera.delegate = self
        neuralNet.delegate = self
        if let failSoundURL = Bundle.main.url(forResource: "fail_sound", withExtension: "caf") {
            failSound = try! AVAudioPlayer(contentsOf: failSoundURL)
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        camera.requestPermission()
    }
    
    
    func cameraPermissionGranted() {
        voice.speak("Starting Barc")
        camera.beginSession()
        if camera.previewLayer != nil {
            view.layer.addSublayer(camera.previewLayer!)
            camera.previewLayer!.frame = view.layer.frame
        }
        neuralNet.initModel()
    }
    
    
    func cameraPermissionDenied() {
        voice.speak("Barc requires camera permission to operate. Please enable it in your device settings.")
    }
    
    
    func didCaptureImage(pixelBuffer: CVPixelBuffer, motion: MotionObservation) {
        neuralNet.classifyImage(pixelBuffer)
        image = pixelBuffer
        motionData = motion
    }
    
    
    func willUpdateModel() {
        voice.speak("Barc is updating. Please wait a moment.")
    }
    
    
    func didInitModel() {
        camera.captureImage()
    }
    
    
    func initModelError(errorMessage: String) {
        voice.speak(errorMessage)
    }
    
    
    func didClassifyImage(results: [ ClassificationResult ]) {
        
        if results.count > 1 && results.first!.confidence >= 0.5 {
            let label = results.first!.label
            let index = label.index(label.index(of: "|")!, offsetBy: 2)
            let object = String(describing: label[index...])
            voice.speak(object, { self.camera.captureImage() })
        } else {
            failSound.play()
            camera.captureImage()
        }
        
        service.report(pixelBuffer: image!, results: results, motion: motionData!)
    }
    
    
}

