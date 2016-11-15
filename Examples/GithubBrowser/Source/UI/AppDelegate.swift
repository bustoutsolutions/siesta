import UIKit
import Siesta

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        SiestaTheme.applyAppearanceDefaults()

        // Show network indicator in iOS status bar when loading images. (We don’t show it for the Github API itself,
        // because Apple’s HI guidelines say not to display it for brief requests.)

        RemoteImageView.defaultImageService.configure {
            $0.useNetworkActivityIndicator()
        }

        // Github auto login so that local testing doesn’t hit API rate limits

        let env = ProcessInfo.processInfo.environment
        if let username = env["GITHUB_USER"],
           let password = env["GITHUB_PASS"] {
            GitHubAPI.logIn(username: username, password: password)
        }

        return true
    }

}
