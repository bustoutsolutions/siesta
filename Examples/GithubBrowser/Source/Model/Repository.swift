import SwiftyJSON

struct Repository {
    let name, owner: String?

    init(json: JSON) {
        name  = json["name"].string
        owner = json["owner"]["login"].string
    }
}
