import Foundation
import Combine

struct ScriptTab: Codable, Identifiable {
    var id = UUID()
    var name: String
    var content: String
    var isSaved: Bool = false
}

class TabManager: ObservableObject {
    static let shared = TabManager()
    
    @Published var tabs: [ScriptTab] = []
    @Published var selectedTabIndex: Int = 0
    @Published var savedScripts: [ScriptTab] = []
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadTabs()
        loadSaved()
        
        if tabs.isEmpty {
            tabs.append(ScriptTab(name: "Untitled 1", content: "-- XZX Executor\nprint('Hello World!')"))
        }
    }
    
    var currentScript: String {
        get { selectedTabIndex < tabs.count ? tabs[selectedTabIndex].content : "" }
        set {
            guard selectedTabIndex < tabs.count else { return }
            tabs[selectedTabIndex].content = newValue
            saveTabs()
        }
    }
    
    func addTab() {
        let newTab = ScriptTab(name: "Untitled \(tabs.count + 1)", content: "")
        tabs.append(newTab)
        selectedTabIndex = tabs.count - 1
        saveTabs()
    }
    
    func removeTab(at index: Int) {
        guard tabs.count > 1 else { return }
        tabs.remove(at: index)
        if selectedTabIndex >= tabs.count {
            selectedTabIndex = tabs.count - 1
        }
        saveTabs()
    }
    
    func saveCurrentScript() {
        guard selectedTabIndex < tabs.count else { return }
        var script = tabs[selectedTabIndex]
        script.isSaved = true
        savedScripts.append(script)
        saveSaved()
    }
    
    func loadScript(_ script: ScriptTab) {
        tabs.append(script)
        selectedTabIndex = tabs.count - 1
        saveTabs()
    }
    
    private func saveTabs() {
        if let encoded = try? JSONEncoder().encode(tabs) {
            userDefaults.set(encoded, forKey: "xzx_tabs")
        }
    }
    
    private func loadTabs() {
        if let data = userDefaults.data(forKey: "xzx_tabs"),
           let decoded = try? JSONDecoder().decode([ScriptTab].self, from: data) {
            tabs = decoded
        }
    }
    
    private func saveSaved() {
        if let encoded = try? JSONEncoder().encode(savedScripts) {
            userDefaults.set(encoded, forKey: "xzx_saved")
        }
    }
    
    private func loadSaved() {
        if let data = userDefaults.data(forKey: "xzx_saved"),
           let decoded = try? JSONDecoder().decode([ScriptTab].self, from: data) {
            savedScripts = decoded
        }
    }
}
