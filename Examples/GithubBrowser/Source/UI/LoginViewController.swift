import UIKit

class LoginViewController: UIViewController {

    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        usernameField.becomeFirstResponder()
    }

    @IBAction func cancel(_ sender: AnyObject) {
        dismiss(animated: true) { }
    }

    @IBAction func moveToPassword() {
        passwordField.becomeFirstResponder()
    }

    @IBAction func logIn() {
        guard let username = usernameField.text else {
            usernameField.becomeFirstResponder()
            return
        }
        guard let password = passwordField.text else {
            passwordField.becomeFirstResponder()
            return
        }

        GithubAPI.logIn(username: username, password: password)
        dismiss(animated: true) { }
    }
}
