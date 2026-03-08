import Foundation
import UIKit

public struct ScriptItem: Decodable {
    public let title: String
    public let script: String
    public let game: String?
    public let views: Int?
    public let likes: Int?
    public let thumbnail: String?
    
    enum CodingKeys: String, CodingKey {
        case title, script, game, views, likes
        case thumbnail = "image"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        script = try container.decode(String.self, forKey: .script)
        game = try container.decodeIfPresent(String.self, forKey: .game)
        views = try container.decodeIfPresent(Int.self, forKey: .views)
        likes = try container.decodeIfPresent(Int.self, forKey: .likes)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
    }
}

struct ScriptBloxResponse: Decodable {
    let result: ScriptResult
}

struct ScriptResult: Decodable {
    let scripts: [ScriptItem]
}

public class ScriptBloxAPI {
    public static let shared = ScriptBloxAPI()
    private var searchCache = NSCache<NSString, NSArray>()
    private var imageCache = NSCache<NSString, UIImage>()
    private var currentTask: URLSessionDataTask?
    
    private init() {}
    
    public func search(query: String, completion: @escaping ([ScriptItem]) -> Void) {
        currentTask?.cancel()
        
        let cacheKey = NSString(string: query)
        if let cached = searchCache.object(forKey: cacheKey) as? [ScriptItem] {
            completion(cached)
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            let urlString = "https://scriptblox.com/api/script/search?q=\(query)&mode=free"
            guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
                completion([])
                return
            }
            
            self.currentTask = URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data, error == nil else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                
                do {
                    let decoded = try JSONDecoder().decode(ScriptBloxResponse.self, from: data)
                    let scripts = decoded.result.scripts
                    self.searchCache.setObject(scripts as NSArray, forKey: cacheKey)
                    DispatchQueue.main.async {
                        completion(scripts)
                    }
                } catch {
                    DispatchQueue.main.async { completion([]) }
                }
            }
            self.currentTask?.resume()
        }
    }
    
    public func loadThumbnail(url: String, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = NSString(string: url)
        
        if let cached = imageCache.object(forKey: cacheKey) {
            completion(cached)
            return
        }
        
        guard let imageUrl = URL(string: url) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: imageUrl) { [weak self] data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                self?.imageCache.setObject(image, forKey: cacheKey)
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
