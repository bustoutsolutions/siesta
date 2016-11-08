import Siesta
import AVFoundation

func guide_logging(service: Service, resource: Resource) {
                                                                                                                        
    //══════ guide_logging:0 ══════
    Siesta.LogCategory.enabled = LogCategory.common
    //════════════════════════════════════
        
    //══════ guide_logging:1 ══════
    Siesta.LogCategory.enabled = LogCategory.all
    //════════════════════════════════════
        
    //══════ guide_logging:2 ══════
    #if DEBUG
        Siesta.LogCategory.enabled = LogCategory.common
    #endif
    //════════════════════════════════════
        
    //══════ guide_logging:3 ══════
    let speechSynth = AVSpeechSynthesizer()
    let originalLogger = Siesta.logger
    Siesta.logger = { category, message in
        originalLogger(category, message)
        speechSynth.speak(AVSpeechUtterance(string: message))
    }
    //════════════════════════════════════
    
}
