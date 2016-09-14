import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        SiestaTheme.applyAppearanceDefaults()

        let env = ProcessInfo.processInfo.environment
        if let username = env["GITHUB_USER"],
           let password = env["GITHUB_PASS"] {
            GithubAPI.logIn(username: username, password: password)
        }

        return true
    }

}
