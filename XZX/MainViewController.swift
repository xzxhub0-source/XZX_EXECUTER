import UIKit

public class MainViewController: UIViewController {
    
    private let neonWindow = NeonWindow()
    private let sidebar = SidebarView()
    private let editor = EditorView()
    private let hub = HubView()
    private let executeButton = UIButton()
    private let clearButton = UIButton()
    private let saveButton = UIButton()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        // Manually initialize the core after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            print("[XZX] Manually initializing core...")
            XZXCore.shared().initialize()
            InitLua()
        }
        
        setupWindow()
        setupSidebar()
        setupViews()
        setupToolbar()
        setupNotifications()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onGameJoined),
            name: NSNotification.Name("GameJoined"),
            object: nil
        )
    }
    
    private func setupWindow() {
        neonWindow.frame = CGRect(x: 40, y: 80, width: 400, height: 500)
        view.addSubview(neonWindow)
    }
    
    private func setupSidebar() {
        sidebar.frame = CGRect(x: 0, y: 0, width: 180, height: 500)
        sidebar.onTabSelected = { [weak self] index in
            self?.switchToTab(index)
        }
        neonWindow.addSubview(sidebar)
    }
    
    private func setupViews() {
        editor.frame = CGRect(x: 190, y: 20, width: 190, height: 420)
        editor.tag = 0
        neonWindow.addSubview(editor)
        
        hub.frame = CGRect(x: 190, y: 20, width: 190, height: 420)
        hub.tag = 1
        hub.isHidden = true
        neonWindow.addSubview(hub)
    }
    
    private func setupToolbar() {
        executeButton.frame = CGRect(x: 190, y: 450, width: 60, height: 40)
        executeButton.setTitle("▶️", for: .normal)
        executeButton.backgroundColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1)
        executeButton.layer.cornerRadius = 8
        executeButton.addTarget(self, action: #selector(executeScript), for: .touchUpInside)
        neonWindow.addSubview(executeButton)
        
        clearButton.frame = CGRect(x: 255, y: 450, width: 60, height: 40)
        clearButton.setTitle("🗑️", for: .normal)
        clearButton.backgroundColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        clearButton.layer.cornerRadius = 8
        clearButton.addTarget(self, action: #selector(clearScript), for: .touchUpInside)
        neonWindow.addSubview(clearButton)
        
        saveButton.frame = CGRect(x: 320, y: 450, width: 60, height: 40)
        saveButton.setTitle("💾", for: .normal)
        saveButton.backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 1)
        saveButton.layer.cornerRadius = 8
        saveButton.addTarget(self, action: #selector(saveScript), for: .touchUpInside)
        neonWindow.addSubview(saveButton)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loadScriptFromHub(_:)),
            name: NSNotification.Name("LoadScript"),
            object: nil
        )
    }
    
    private func switchToTab(_ index: Int) {
        editor.isHidden = index != 0
        hub.isHidden = index != 1
    }
    
    @objc private func executeScript() {
        let script = editor.textView.text ?? ""
        ExecuteScript(script)
    }
    
    @objc private func clearScript() {
        editor.textView.text = ""
    }
    
    @objc private func saveScript() {
        print("Script saved")
    }
    
    @objc private func loadScriptFromHub(_ notification: Notification) {
        if let scriptTitle = notification.object as? String {
            switchToTab(0)
            editor.textView.text = "-- Loaded: \(scriptTitle)\n\nprint('Script loaded!')"
        }
    }
    
    @objc private func onGameJoined() {
        DispatchQueue.main.async {
            self.neonWindow.isHidden = false
            self.view.bringSubviewToFront(self.neonWindow)
        }
    }
}
