import Siesta
import AVFoundation

func guide_logging(service: Service, resource: Resource) {

    //══════ guide_logging:0 ══════
    SiestaLog.Category.enabled = .common
    //════════════════════════════════════

    //══════ guide_logging:1 ══════
    SiestaLog.Category.enabled = .all
    //════════════════════════════════════

    //══════ guide_logging:2 ══════
    #if DEBUG
        SiestaLog.Category.enabled = .common
    #endif
    //════════════════════════════════════

    //══════ guide_logging:3 ══════
    let speechSynth = AVSpeechSynthesizer()
    let originalLogger = SiestaLog.messageHandler
    SiestaLog.messageHandler = { category, message in
        originalLogger(category, message)
        speechSynth.speak(AVSpeechUtterance(string: message))
    }
    //════════════════════════════════════

}
