import UIKit
import Combine

class MainViewController: UIViewController {
    
    private let neonWindow = NeonWindow()
    private let sidebar = SidebarView()
    private let editor = EditorView()
    private let hub = HubView()
    private let tabManager = TabManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let executeButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupWindow()
        setupSidebar()
        setupViews()
        setupToolbar()
        setupObservers()
        InitLua()
    }
    
    private func setupWindow() {
        neonWindow.frame = CGRect(x: 40, y: 80, width: 900, height: 600)
        view.addSubview(neonWindow)
    }
    
    private func setupSidebar() {
        sidebar.frame = CGRect(x: 0, y: 0, width: 200, height: 600)
        sidebar.onTabSelected = { [weak self] index in
            self?.switchToTab(index)
        }
        neonWindow.addSubview(sidebar)
    }
    
    private func setupViews() {
        editor.frame = CGRect(x: 210, y: 20, width: 670, height: 500)
        editor.tag = 0
        neonWindow.addSubview(editor)
        
        hub.frame = CGRect(x: 210, y: 20, width: 670, height: 500)
        hub.tag = 1
        hub.isHidden = true
        neonWindow.addSubview(hub)
    }
    
    private func setupToolbar() {
        executeButton.frame = CGRect(x: 220, y: 530, width: 100, height: 40)
        executeButton.setTitle("▶️ Execute", for: .normal)
        executeButton.backgroundColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1)
        executeButton.setTitleColor(.white, for: .normal)
        executeButton.layer.cornerRadius = 8
        executeButton.addTarget(self, action: #selector(executeScript), for: .touchUpInside)
        neonWindow.addSubview(executeButton)
        
        clearButton.frame = CGRect(x: 330, y: 530, width: 100, height: 40)
        clearButton.setTitle("🗑️ Clear", for: .normal)
        clearButton.backgroundColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.layer.cornerRadius = 8
        clearButton.addTarget(self, action: #selector(clearScript), for: .touchUpInside)
        neonWindow.addSubview(clearButton)
        
        saveButton.frame = CGRect(x: 440, y: 530, width: 100, height: 40)
        saveButton.setTitle("💾 Save", for: .normal)
        saveButton.backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 1)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 8
        saveButton.addTarget(self, action: #selector(saveScript), for: .touchUpInside)
        neonWindow.addSubview(saveButton)
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: NSNotification.Name("LoadScript"))
            .sink { [weak self] notification in
                if let scriptItem = notification.object as? ScriptItem {
                    self?.loadScriptFromHub(scriptItem)
                }
            }
            .store(in: &cancellables)
    }
    
    private func switchToTab(_ index: Int) {
        editor.isHidden = index != 0
        hub.isHidden = index != 1
    }
    
    private func loadScriptFromHub(_ scriptItem: ScriptItem) {
        tabManager.addTab()
        tabManager.currentScript = "-- Loaded: \(scriptItem.title)\n\n" + scriptItem.script
        editor.textView.text = tabManager.currentScript
        switchToTab(0)
    }
    
    @objc private func executeScript() {
        ExecuteScript(editor.textView.text ?? "")
    }
    
    @objc private func clearScript() {
        editor.textView.text = ""
        tabManager.currentScript = ""
    }
    
    @objc private func saveScript() {
        tabManager.saveCurrentScript()
    }
}
