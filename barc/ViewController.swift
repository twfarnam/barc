//
//  ViewController.swift
//  barc
//
//  Created by Tim Farnam on 10/31/17.
//  Copyright © 2017 Tim Farnam. All rights reserved.

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    let apiEndpoint = "https://barc.squids.online/api/images"
    let apiToken = "4Fbz8RL2U5PUcRdq"
    
    let synth = AVSpeechSynthesizer()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        requestCameraPermission()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    

    
    func requestCameraPermission() {
        
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        
        switch authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted:Bool) -> Void in
                if granted {
                    self.start()
                } else {
                    self.alertNoPermission()
                }
            })
        case .authorized:
            start()
        case .denied, .restricted:
            alertNoPermission()
        }
    }
    
    
    func alertNoPermission() {
        speak("Camera permission is required to run")
    }
    
    
    func start() {
        takePhoto = true
        prepareCamera()
    }
    
    
    
    
    
    
    let captureSession = AVCaptureSession()
    var previewLayer:CALayer!
    var captureDevice:AVCaptureDevice!
    var takePhoto = false
    
    func prepareCamera() {
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
        let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices
        captureDevice = availableDevices.first
        beginSession()
    }
    
    func beginSession () {
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(captureDeviceInput)
        } catch {
            print("device error")
            print(error.localizedDescription)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = previewLayer
        self.view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.view.layer.frame

        let dataOutput = AVCaptureVideoDataOutput()
        print(dataOutput.videoSettings)
        dataOutput.videoSettings = [((kCVPixelBufferPixelFormatTypeKey as NSString) as String):NSNumber(value:kCVPixelFormatType_32BGRA)]
        dataOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
        }
        
        let queue = DispatchQueue(label: "twf.barc")
        dataOutput.setSampleBufferDelegate(self, queue: queue)
        
        captureSession.startRunning()
    }
    
    
    @IBAction func takePhoto(_ sender: Any) {
        takePhoto = true
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        if takePhoto {
            takePhoto = false
            
            if let image = self.getImageFromSampleBuffer(buffer: sampleBuffer) {
                
                let ratio = 0.3905 as CGFloat
                let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                UIGraphicsBeginImageContextWithOptions(newSize, true, 0)
                image.draw(in: CGRect(origin: CGPoint(x: 0, y: 0), size: newSize))
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                print("Photo captured!")
                speakCaption(image!)
            }
            
            
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
    
    
    func stopCaptureSession () {
        self.captureSession.stopRunning()
        
        if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                self.captureSession.removeInput(input)
            }
        }
        
    }
    
    
    
    func speakCaption(_ image: UIImage) {
        
        guard let url = URL(string: apiEndpoint) else {
            print("Error: cannot create URL")
            return
        }
        
        var urlRequest = URLRequest(url: url)
        
        urlRequest.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Token token=\(apiToken)", forHTTPHeaderField: "Authorization")

        urlRequest.httpBody = createBody(
            parameters: [:],
            boundary: boundary,
            data: UIImageJPEGRepresentation(image, 0.7)!,
            mimeType: "image/jpg",
            filename: "hello.jpg"
        )
        
        let session = URLSession.shared
        
        let task = session.dataTask(with: urlRequest) {
            (data, response, error) in
            
            self.takePhoto = true
            
            // check for any errors
            guard error == nil else {
                self.speak("server down")
                print(error!)
                return
            }
            
            // make sure we got data
            guard let responseData = data else {
                self.speak("server down")
                return
            }
            // parse the result as JSON, since that's what the API provides
            do {
                
                guard let caption = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] else {
                    self.speak("server down")
                    return
                }
                
                if let result = caption["result"] as? String {
                    print("Result: " + result)
                    self.speak(result)
                } else {
                    print("No result")
                }
                
            } catch  {
                print("error trying to convert data to JSON")
                return
            }
        }
        task.resume()
    }
    
    
    func createBody(parameters: [String: String],
                    boundary: String,
                    data: Data,
                    mimeType: String,
                    filename: String) -> Data {
        
        var body = Data()
        
        let boundaryPrefix = Data("--\(boundary)\r\n".utf8)
        
        for (key, value) in parameters {
            body.append(boundaryPrefix)
            body.append(Data("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }
        
        body.append(boundaryPrefix)
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n".utf8))
        body.append(Data("--".appending(boundary.appending("--")).utf8))
        
        return body as Data
    }
    
    
    func speak(_ words: String) {
        let utterance = AVSpeechUtterance(string: words)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        // utterance.rate = AVSpeechUtteranceMaximumSpeechRate / 1.7
        utterance.volume = 1.0
        synth.speak(utterance)
    }
    
}

