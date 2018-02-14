import UIKit
import AVFoundation


class ViewController: UIViewController {
    
    let voice = Speaker()
    let camera = ImageCapture()
    let service = ImageRecognitionService()
    var shutterSound : AVAudioPlayer?
    var clickSound : AVAudioPlayer?
    var clickTimer = Timer()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            if let shutterURL = Bundle.main.url(forResource: "shutter", withExtension: "caf") {
                shutterSound = try AVAudioPlayer(contentsOf: shutterURL)
            }
            if let clickURL = Bundle.main.url(forResource: "waiting_click", withExtension: "wav") {
                clickSound = try AVAudioPlayer(contentsOf: clickURL)
            }
        } catch {
            print(error)
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        requestPermissions()
    }
    
    
    func requestPermissions() {
        camera.requestPermission({ granted in
            if (granted) {
                self.start()
            }
            else {
                self.voice.speak("Barc requires camera permission", { self.requestPermissions() })
            }
        })
    }
    
    
    func start() {
        camera.beginSession(self.view)
        voice.speak("starting Barc", { self.photoLoop() })
    }
    
    
    func photoLoop() {
        
        camera.takePhoto({ image in
            
            self.shutterSound?.play()
            self.startClicking()
            
            guard image != nil else {
                self.stopClicking()
                self.voice.speak("Cant take a picture", { self.delayedPhotoLoop() })
                return
            }
            
            self.service.request(
                image!,
                callback: { response in
                    self.stopClicking()
                    guard response != nil else { self.photoLoop(); return }
                    self.voice.speak(response!, { self.photoLoop() })
                },
                errorCallback: { message in
                    self.stopClicking()
                    self.voice.speak(message, { self.delayedPhotoLoop() })
                }
            )

        })
        
    }
    
    
    func delayedPhotoLoop() {
        // timers do not work on a background queue
        DispatchQueue.main.async() {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: false, block: { _ in
                self.photoLoop()
            })
        }
    }
    
    
    func startClicking() {
        // timers do not work on a background queue
        DispatchQueue.main.async() {
            self.clickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
                self.clickSound?.play()
            })
        }
    }
    
    
    func stopClicking() {
        clickTimer.invalidate()
    }
    
}

