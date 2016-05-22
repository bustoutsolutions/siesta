import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        SiestaTheme.applyAppearanceDefaults()

        let env = NSProcessInfo.processInfo().environment
        if let username = env["GITHUB_USER"],
               password = env["GITHUB_PASS"] {
            GithubAPI.logIn(username: username, password: password)
        }

        return true
    }

}
