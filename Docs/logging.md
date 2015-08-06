### Logging

Siesta features extensive logging. It is disabled by default, but you can turn it on with:

```swift
    Siesta.enabledLogCategories = LogCategory.common
```

…or for the full fire hose:

```swift
    Siesta.enabledLogCategories = LogCategory.all
```

Common practice is to add a DEBUG Swift compiler flag to your project (if you haven’t already done so):

<p align="center"><img alt="Build Settings → Swift Compiler Flags - Custom Flags → Other Swift Flags → Debug → -DDEBUG" src="images/debug-flag@2x.png" width=482 height=120></p>

…and then automatically enable logging for common categories in your API’s `init()` or your `applicationDidFinishLaunching`:

```swift
    #if DEBUG
        Siesta.enabledLogCategories = LogCategory.common
    #endif
```
