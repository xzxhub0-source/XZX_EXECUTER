import UIKit

@objc(XZXMainViewController)
public class MainViewController: UIViewController, UITextViewDelegate {
    
    private let textView = UITextView()
    private let executeButton = UIButton()
    private let clearButton = UIButton()
    private let saveButton = UIButton()
    private let closeButton = UIButton()
    private let scriptHubButton = UIButton()
    private var scriptHubView: UIView?
    private var isVisible = false
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start invisible - will be resized by xzx_core.m when game detected
        view.isHidden = true
        view.alpha = 0
        
        setupUI()
        setupNotifications()
        loadSavedScripts()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 0.95)
        view.layer.cornerRadius = 18
        view.clipsToBounds = true
        
        setupSubviews()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Only layout if view has valid bounds
        guard view.bounds.width > 0 && view.bounds.height > 0 else { return }
        
        let w = view.bounds.width
        let h = view.bounds.height
        
        closeButton.frame = CGRect(x: w - 50, y: 12, width: 38, height: 38)
        scriptHubButton.frame = CGRect(x: w - 100, y: 16, width: 80, height: 30)
        textView.frame = CGRect(x: 16, y: 60, width: w - 32, height: h - 160)
        executeButton.frame = CGRect(x: 16, y: h - 80, width: 90, height: 50)
        clearButton.frame = CGRect(x: 116, y: h - 80, width: 90, height: 50)
        saveButton.frame = CGRect(x: 216, y: h - 80, width: 90, height: 50)
        
        if let hub = scriptHubView {
            hub.frame = CGRect(x: 16, y: 110, width: w - 32, height: h - 210)
        }
    }
    
    private func setupSubviews() {
        // Title Label
        let titleLabel = UILabel()
        titleLabel.frame = CGRect(x: 16, y: 16, width: 150, height: 28)
        titleLabel.text = "XZX"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        view.addSubview(titleLabel)
        
        // Close Button
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 20)
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(closeButton)
        
        // Script Hub Button
        scriptHubButton.setTitle("Script Hub", for: .normal)
        scriptHubButton.backgroundColor = UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 0.8)
        scriptHubButton.layer.cornerRadius = 8
        scriptHubButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        scriptHubButton.addTarget(self, action: #selector(toggleScriptHub), for: .touchUpInside)
        view.addSubview(scriptHubButton)
        
        // Text View (Script Editor)
        textView.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 0.9)
        textView.textColor = .white
        textView.font = UIFont(name: "Menlo", size: 13)
        textView.layer.cornerRadius = 8
        textView.text = "-- XZX Executor\nprint('Hello World!')"
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.delegate = self
        view.addSubview(textView)
        
        // Action Buttons
        let buttons: [(UIButton, String, UIColor)] = [
            (executeButton, "Execute", UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1)),
            (clearButton, "Clear", UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)),
            (saveButton, "Save", UIColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 1))
        ]
        
        for (btn, title, color) in buttons {
            btn.setTitle(title, for: .normal)
            btn.backgroundColor = color
            btn.layer.cornerRadius = 8
            view.addSubview(btn)
        }
        
        executeButton.addTarget(self, action: #selector(executeScript), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearScript), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveScript), for: .touchUpInside)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleScriptLoad(_:)),
            name: NSNotification.Name("LoadScript"), object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleMakeVisible),
            name: NSNotification.Name("XZXMakeVisible"), object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleMakeInvisible),
            name: NSNotification.Name("XZXMakeInvisible"), object: nil
        )
    }
    
    private func loadSavedScripts() {
        if let savedScript = UserDefaults.standard.string(forKey: "XZXSavedScript") {
            textView.text = savedScript
        }
    }
    
    // MARK: - Script Hub
    
    @objc private func toggleScriptHub() {
        if scriptHubView == nil {
            let hub = UIView()
            hub.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 0.9)
            hub.layer.cornerRadius = 8
            scriptHubView = hub
            view.addSubview(hub)
            view.setNeedsLayout()
            fetchScripts(query: "blox fruits")
        } else {
            scriptHubView?.removeFromSuperview()
            scriptHubView = nil
            view.setNeedsLayout()
        }
    }
    
    private func fetchScripts(query: String) {
        let urlStr = "https://scriptblox.com/api/script/search?q=\(query)&mode=free"
        guard let encoded = urlStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encoded) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let scripts = result["scripts"] as? [[String: Any]] else { return }
            DispatchQueue.main.async { self?.displayScripts(scripts) }
        }.resume()
    }
    
    private func displayScripts(_ scripts: [[String: Any]]) {
        guard let hub = scriptHubView else { return }
        hub.subviews.forEach { $0.removeFromSuperview() }
        
        let scroll = UIScrollView(frame: hub.bounds)
        hub.addSubview(scroll)
        var y: CGFloat = 8
        
        for script in scripts {
            let title = script["title"] as? String ?? "Untitled"
            let game = script["game"] as? String ?? "Unknown"
            let code = script["script"] as? String ?? ""
            
            let card = UIView(frame: CGRect(x: 8, y: y, width: scroll.bounds.width - 16, height: 64))
            card.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
            card.layer.cornerRadius = 8
            
            let titleLabel = UILabel(frame: CGRect(x: 10, y: 8, width: card.bounds.width - 80, height: 20))
            titleLabel.text = title
            titleLabel.textColor = .white
            titleLabel.font = .boldSystemFont(ofSize: 13)
            
            let gameLabel = UILabel(frame: CGRect(x: 10, y: 30, width: card.bounds.width - 80, height: 18))
            gameLabel.text = game
            gameLabel.textColor = .lightGray
            gameLabel.font = .systemFont(ofSize: 11)
            
            let loadButton = UIButton(frame: CGRect(x: card.bounds.width - 66, y: 16, width: 58, height: 30))
            loadButton.setTitle("Load", for: .normal)
            loadButton.backgroundColor = UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 0.8)
            loadButton.layer.cornerRadius = 6
            loadButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
            objc_setAssociatedObject(loadButton, "code", code, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            loadButton.addTarget(self, action: #selector(loadScript(_:)), for: .touchUpInside)
            
            [titleLabel, gameLabel, loadButton].forEach { card.addSubview($0) }
            scroll.addSubview(card)
            y += 72
        }
        
        scroll.contentSize = CGSize(width: scroll.bounds.width, height: y + 8)
    }
    
    @objc private func loadScript(_ sender: UIButton) {
        textView.text = objc_getAssociatedObject(sender, "code") as? String ?? ""
        toggleScriptHub()
    }
    
    // MARK: - Actions
    
    @objc func executeScript() {
        guard let script = textView.text, !script.isEmpty else { return }
        script.withCString { ExecuteScript($0) }
    }
    
    @objc func clearScript() {
        textView.text = ""
    }
    
    @objc func saveScript() {
        UserDefaults.standard.set(textView.text, forKey: "XZXSavedScript")
        let alert = UIAlertController(title: "Saved", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc func close() {
        // Post notification to hide/shrink the overlay
        NotificationCenter.default.post(name: NSNotification.Name("XZXMakeInvisible"), object: nil)
    }
    
    // MARK: - Visibility Handlers
    
    @objc private func handleMakeVisible() {
        DispatchQueue.main.async {
            // Animate the transition from invisible to visible
            UIView.animate(withDuration: 0.3) {
                self.view.isHidden = false
                self.view.alpha = 1
            }
            self.isVisible = true
            print("[XZX] ViewController became visible")
        }
    }
    
    @objc private func handleMakeInvisible() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3) {
                self.view.alpha = 0
            } completion: { _ in
                self.view.isHidden = true
            }
            self.isVisible = false
            print("[XZX] ViewController became invisible")
        }
    }
    
    @objc private func handleScriptLoad(_ notification: Notification) {
        if let script = notification.object as? String {
            textView.text = script
        }
    }
    
    // MARK: - UITextViewDelegate
    
    public func textViewDidChange(_ textView: UITextView) {
        UserDefaults.standard.set(textView.text, forKey: "XZXSavedScript")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
