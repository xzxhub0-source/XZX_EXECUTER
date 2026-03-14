import Foundation
import UIKit

struct ScriptItem: Decodable {
    let title: String
    let script: String
    let game: String?
    let views: Int?
    let likes: Int?
    let thumbnail: String?
}

class ScriptBloxAPI {
    static let shared = ScriptBloxAPI()
    private var searchCache = NSCache<NSString, NSArray>()
    private var imageCache = NSCache<NSString, UIImage>()
    
    func search(query: String, completion: @escaping ([ScriptItem]) -> Void) {
        let urlString = "https://scriptblox.com/api/script/search?q=\(query)&mode=free"
        guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encoded) else {
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            do {
                struct Response: Decodable {
                    let result: ScriptResult
                }
                struct ScriptResult: Decodable {
                    let scripts: [ScriptItem]
                }
                let decoded = try JSONDecoder().decode(Response.self, from: data)
                DispatchQueue.main.async {
                    completion(decoded.result.scripts)
                }
            } catch {
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
    
    func loadThumbnail(url: String, completion: @escaping (UIImage?) -> Void) {
        guard let imageUrl = URL(string: url) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: imageUrl) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }.resume()
    }
}
