# Logging

Siesta features extensive logging. It is disabled by default, but you can turn it on with:

```swift
SiestaLog.Category.enabled = .common
```

…or for the full fire hose:

```swift
SiestaLog.Category.enabled = .all
```

Common practice is to add a DEBUG Swift compiler flag to your project (if you haven’t already done so):

<img alt="Build Settings → Swift Compiler Flags - Custom Flags → Other Swift Flags → Debug → -DDEBUG" src="/siesta/guide/images/debug-flag@2x.png" width="482" height="120">

…and then automatically enable logging for common categories in your API’s `init()` or your `applicationDidFinishLaunching`:

```swift
#if DEBUG
    SiestaLog.Category.enabled = .common
#endif
```

## Custom Log Action

By default, Siesta logs to stdout using `print(...)`, but you can augment or override the default by providing your own logging closure.

For example, if you want to drive yourself and everyone around you into a wild rage:

```swift
let speechSynth = AVSpeechSynthesizer()
let originalLogger = SiestaLog.messageHandler
SiestaLog.messageHandler = { category, message in
    originalLogger(category, message)
    speechSynth.speak(AVSpeechUtterance(string: message))
}
```
