import UIKit

@objc(XZXMainViewController)
public class MainViewController: UIViewController, UITextViewDelegate {

    private let textView        = UITextView()
    private let executeButton   = UIButton()
    private let clearButton     = UIButton()
    private let saveButton      = UIButton()
    private let closeButton     = UIButton()
    private let scriptHubButton = UIButton()
    private var scriptHubView: UIView?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 0.95)
        view.layer.cornerRadius = 18
        view.clipsToBounds = true
        setupSubviews()
        setupNotifications()
        loadSavedScripts()
        // FIX: InitLua() removed — xzx_core.m already calls it once before
        // this VC is ever created. Calling it again caused a double-init crash.
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let w = view.bounds.width
        let h = view.bounds.height

        closeButton.frame        = CGRect(x: w - 50, y: 12, width: 38, height: 38)
        scriptHubButton.frame    = CGRect(x: w - 100, y: 16, width: 80, height: 30)
        textView.frame           = CGRect(x: 16, y: 60, width: w - 32, height: h - 160)
        executeButton.frame      = CGRect(x: 16,  y: h - 80, width: 90, height: 50)
        clearButton.frame        = CGRect(x: 116, y: h - 80, width: 90, height: 50)
        saveButton.frame         = CGRect(x: 216, y: h - 80, width: 90, height: 50)

        if let hub = scriptHubView {
            hub.frame = CGRect(x: 16, y: 110, width: w - 32, height: h - 210)
        }
    }

    private func setupSubviews() {
        let titleLabel = UILabel()
        titleLabel.frame = CGRect(x: 16, y: 16, width: 150, height: 28)
        titleLabel.text = "XZX"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        view.addSubview(titleLabel)

        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 20)
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(closeButton)

        scriptHubButton.setTitle("Script Hub", for: .normal)
        scriptHubButton.backgroundColor = UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 0.8)
        scriptHubButton.layer.cornerRadius = 8
        scriptHubButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        scriptHubButton.addTarget(self, action: #selector(toggleScriptHub), for: .touchUpInside)
        view.addSubview(scriptHubButton)

        textView.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 0.9)
        textView.textColor = .white
        textView.font = UIFont(name: "Menlo", size: 13)
        textView.layer.cornerRadius = 8
        textView.text = "-- XZX Executor\nprint('Hello World!')"
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.delegate = self
        view.addSubview(textView)

        for (btn, title, color) in [
            (executeButton, "Execute", UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1)),
            (clearButton,   "Clear",   UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)),
            (saveButton,    "Save",    UIColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 1))
        ] {
            btn.setTitle(title, for: .normal)
            btn.backgroundColor = color
            btn.layer.cornerRadius = 8
            view.addSubview(btn)
        }
        executeButton.addTarget(self, action: #selector(executeScript), for: .touchUpInside)
        clearButton.addTarget(self,   action: #selector(clearScript),   for: .touchUpInside)
        saveButton.addTarget(self,    action: #selector(saveScript),    for: .touchUpInside)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleScriptLoad(_:)),
            name: NSNotification.Name("LoadScript"), object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleHideOverlay),
            name: NSNotification.Name("XZXHideOverlay"), object: nil)
    }

    private func loadSavedScripts() {
        if let s = UserDefaults.standard.string(forKey: "XZXSavedScript") {
            textView.text = s
        }
    }

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
        guard let encoded = "https://scriptblox.com/api/script/search?q=\(query)&mode=free"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
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
        for s in scripts {
            let title = s["title"] as? String ?? "Untitled"
            let game  = s["game"]  as? String ?? "Unknown"
            let code  = s["script"] as? String ?? ""
            let card  = UIView(frame: CGRect(x: 8, y: y, width: scroll.bounds.width - 16, height: 64))
            card.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
            card.layer.cornerRadius = 8
            let tl = UILabel(frame: CGRect(x: 10, y: 8, width: card.bounds.width - 80, height: 20))
            tl.text = title; tl.textColor = .white; tl.font = .boldSystemFont(ofSize: 13)
            let gl = UILabel(frame: CGRect(x: 10, y: 30, width: card.bounds.width - 80, height: 18))
            gl.text = game; gl.textColor = .lightGray; gl.font = .systemFont(ofSize: 11)
            let lb = UIButton(frame: CGRect(x: card.bounds.width - 66, y: 16, width: 58, height: 30))
            lb.setTitle("Load", for: .normal)
            lb.backgroundColor = UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 0.8)
            lb.layer.cornerRadius = 6
            lb.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
            objc_setAssociatedObject(lb, "code", code, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            lb.addTarget(self, action: #selector(loadScript(_:)), for: .touchUpInside)
            [tl, gl, lb].forEach { card.addSubview($0) }
            scroll.addSubview(card)
            y += 72
        }
        scroll.contentSize = CGSize(width: scroll.bounds.width, height: y + 8)
    }

    @objc private func loadScript(_ sender: UIButton) {
        textView.text = objc_getAssociatedObject(sender, "code") as? String ?? ""
        toggleScriptHub()
    }

    @objc func executeScript() {
        guard let s = textView.text, !s.isEmpty else { return }
        s.withCString { ExecuteScript($0) }
    }

    @objc func clearScript() { textView.text = "" }

    @objc func saveScript() {
        UserDefaults.standard.set(textView.text, forKey: "XZXSavedScript")
        let a = UIAlertController(title: "Saved", message: nil, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // FIX: old close() did view.isHidden = true — the UIWindow stayed alive
    // and key, so Roblox UI behind it was completely touch-dead.
    // Now we hide the window itself and give key status back to Roblox.
    @objc func close() {
        NotificationCenter.default.post(
            name: NSNotification.Name("XZXHideOverlay"), object: nil)
    }

    @objc private func handleHideOverlay() {
        view.window?.isHidden = true
        if let robloxWindow = UIApplication.shared.windows.first(where: { $0 !== view.window }) {
            robloxWindow.makeKey()
        }
    }

    @objc private func handleScriptLoad(_ n: Notification) {
        if let s = n.object as? String { textView.text = s }
    }

    public func textViewDidChange(_ textView: UITextView) {
        UserDefaults.standard.set(textView.text, forKey: "XZXSavedScript")
    }
}
