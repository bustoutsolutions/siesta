import SwiftyJSON

struct Repository {
    let name, owner: String?

    init(json: JSON) {
        name  = json["owner"]["login"].string
        owner = json["name"].string
    }
}
