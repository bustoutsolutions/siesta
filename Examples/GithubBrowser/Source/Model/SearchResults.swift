struct SearchResults<T: Decodable>: Decodable {
    let items: [T]
}

