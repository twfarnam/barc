import AVFoundation


class Voice: NSObject, AVSpeechSynthesizerDelegate {
    
    let synth = AVSpeechSynthesizer()
    var callbacks : [ (() -> Void)? ] = [ ]
    
    
    public override init() {
        super.init()
        synth.delegate = self
    }
    
    
    func speak(_ words: String, _ callback: (() -> Void)? = nil) {
        let utterance = AVSpeechUtterance(string: words)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.55
        synth.speak(utterance)
        callbacks.append(callback)
    }
    
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if let callback = callbacks.removeFirst() {
            callback()
        }
    }
    
    
}

