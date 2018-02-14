import AVFoundation


class Speaker : NSObject, AVSpeechSynthesizerDelegate {
    
    let synth = AVSpeechSynthesizer()
    var callback : (() -> Void)?
    
    public override init() {
        super.init()
        synth.delegate = self
    }
    
    
    func speak(_ words: String, _ callback: (() -> Void)? = nil) {
        let utterance = AVSpeechUtterance(string: words)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(utterance)
        self.callback = callback
    }
    
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if callback != nil {
            callback!()
        }
    }
    
}

