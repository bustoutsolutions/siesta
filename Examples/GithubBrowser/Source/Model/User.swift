import SwiftyJSON

struct User {
    let login, repositoriesURL, avatarURL: String
    let name: String?

    init(json: JSON) throws {
        login           = try json["login"].string.required("user.login")
        name            = json["name"].string
        repositoriesURL = try json["repos_url"].string.required("user.repos_url")
        avatarURL       = try json["avatar_url"].string.required("user.avatar_url")
    }
}
