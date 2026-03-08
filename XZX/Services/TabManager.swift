import Foundation

public struct ScriptTab: Codable {
    public var id = UUID()
    public var name: String
    public var content: String
    public var isSaved: Bool = false
    
    public init(name: String, content: String) {
        self.name = name
        self.content = content
    }
}

public class TabManager: ObservableObject {
    public static let shared = TabManager()
    
    @Published public var tabs: [ScriptTab] = []
    @Published public var selectedTabIndex: Int = 0
    @Published public var savedScripts: [ScriptTab] = []
    
    private let userDefaults = UserDefaults.standard
    private let tabsKey = "xzx_tabs"
    private let savedKey = "xzx_saved"
    
    private init() {
        loadTabs()
        loadSaved()
        
        if tabs.isEmpty {
            tabs.append(ScriptTab(name: "Untitled 1", content: "-- XZX Executor\nprint('Hello World!')"))
        }
    }
    
    public func addTab() {
        let newTab = ScriptTab(name: "Untitled \(tabs.count + 1)", content: "")
        tabs.append(newTab)
        selectedTabIndex = tabs.count - 1
        saveTabs()
    }
    
    public func removeTab(at index: Int) {
        guard tabs.count > 1 else { return }
        tabs.remove(at: index)
        if selectedTabIndex >= tabs.count {
            selectedTabIndex = tabs.count - 1
        }
        saveTabs()
    }
    
    public func updateCurrentContent(_ content: String) {
        guard selectedTabIndex < tabs.count else { return }
        tabs[selectedTabIndex].content = content
        saveTabs()
    }
    
    public func saveScript(at index: Int) {
        guard index < tabs.count else { return }
        var script = tabs[index]
        script.isSaved = true
        savedScripts.append(script)
        saveSaved()
    }
    
    public func loadScript(_ script: ScriptTab) {
        tabs.append(script)
        selectedTabIndex = tabs.count - 1
        saveTabs()
    }
    
    private func saveTabs() {
        if let encoded = try? JSONEncoder().encode(tabs) {
            userDefaults.set(encoded, forKey: tabsKey)
        }
    }
    
    private func loadTabs() {
        if let data = userDefaults.data(forKey: tabsKey),
           let decoded = try? JSONDecoder().decode([ScriptTab].self, from: data) {
            tabs = decoded
        }
    }
    
    private func saveSaved() {
        if let encoded = try? JSONEncoder().encode(savedScripts) {
            userDefaults.set(encoded, forKey: savedKey)
        }
    }
    
    private func loadSaved() {
        if let data = userDefaults.data(forKey: savedKey),
           let decoded = try? JSONDecoder().decode([ScriptTab].self, from: data) {
            savedScripts = decoded
        }
    }
}
