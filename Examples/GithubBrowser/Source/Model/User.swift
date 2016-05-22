import SwiftyJSON

struct User {
    let login, name, repositoriesURL, avatarURL: String?

    init(json: JSON) {
        login           = json["login"].string
        name            = json["name"].string
        repositoriesURL = json["repos_url"].string
        avatarURL       = json["avatar_url"].string
    }
}
