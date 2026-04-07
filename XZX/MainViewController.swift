import UIKit

// Use a unique, predictable name for Objective-C lookup
@objc(XZXMainViewController)
public class MainViewController: UIViewController, UITextViewDelegate, UISearchBarDelegate {
    private let textView = UITextView()
    private let executeButton = UIButton()
    private let clearButton = UIButton()
    private let saveButton = UIButton()
    private let closeButton = UIButton()
    private let scriptHubButton = UIButton()
    private let searchBar = UISearchBar()
    private var scriptHubView: UIView?

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNotifications()
        loadSavedScripts()
        InitLua()
    }

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 0.95)
        view.layer.cornerRadius = 18
        view.layer.masksToBounds = true

        let titleLabel = UILabel()
        titleLabel.frame = CGRect(x: 20, y: 20, width: 200, height: 30)
        titleLabel.text = "XZX"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        view.addSubview(titleLabel)

        scriptHubButton.frame = CGRect(x: view.bounds.width - 100, y: 20, width: 80, height: 30)
        scriptHubButton.setTitle("Script Hub", for: .normal)
        scriptHubButton.backgroundColor = UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 0.8)
        scriptHubButton.layer.cornerRadius = 8
        scriptHubButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        scriptHubButton.addTarget(self, action: #selector(toggleScriptHub), for: .touchUpInside)
        view.addSubview(scriptHubButton)

        searchBar.frame = CGRect(x: 20, y: 60, width: view.bounds.width - 40, height: 40)
        searchBar.placeholder = "Search scripts..."
        searchBar.searchBarStyle = .minimal
        searchBar.barStyle = .black
        searchBar.tintColor = UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 1)
        searchBar.delegate = self
        searchBar.isHidden = true
        view.addSubview(searchBar)

        textView.frame = CGRect(x: 20, y: 60, width: view.bounds.width - 40, height: view.bounds.height - 160)
        textView.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 0.9)
        textView.textColor = .white
        textView.font = UIFont(name: "Menlo", size: 14)
        textView.layer.cornerRadius = 8
        textView.text = "-- XZX Executor\nprint('Hello World!')"
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.delegate = self
        view.addSubview(textView)

        executeButton.frame = CGRect(x: 20, y: view.bounds.height - 80, width: 80, height: 50)
        executeButton.setTitle("Execute", for: .normal)
        executeButton.backgroundColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1)
        executeButton.layer.cornerRadius = 8
        executeButton.addTarget(self, action: #selector(executeScript), for: .touchUpInside)
        view.addSubview(executeButton)

        clearButton.frame = CGRect(x: 110, y: view.bounds.height - 80, width: 80, height: 50)
        clearButton.setTitle("Clear", for: .normal)
        clearButton.backgroundColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        clearButton.layer.cornerRadius = 8
        clearButton.addTarget(self, action: #selector(clearScript), for: .touchUpInside)
        view.addSubview(clearButton)

        saveButton.frame = CGRect(x: 200, y: view.bounds.height - 80, width: 80, height: 50)
        saveButton.setTitle("Save", for: .normal)
        saveButton.backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 1)
        saveButton.layer.cornerRadius = 8
        saveButton.addTarget(self, action: #selector(saveScript), for: .touchUpInside)
        view.addSubview(saveButton)

        closeButton.frame = CGRect(x: view.bounds.width - 60, y: 20, width: 40, height: 40)
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 24)
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(closeButton)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleScriptLoad), name: NSNotification.Name("LoadScript"), object: nil)
    }

    private func loadSavedScripts() {
        let saved = UserDefaults.standard.string(forKey: "XZXSavedScript")
        if let savedScript = saved {
            textView.text = savedScript
        }
    }

    @objc private func toggleScriptHub() {
        if scriptHubView == nil {
            showScriptHub()
            searchBar.isHidden = false
            textView.frame = CGRect(x: 20, y: 110, width: view.bounds.width - 40, height: view.bounds.height - 210)
        } else {
            hideScriptHub()
            searchBar.isHidden = true
            textView.frame = CGRect(x: 20, y: 60, width: view.bounds.width - 40, height: view.bounds.height - 160)
        }
    }

    private func showScriptHub() {
        scriptHubView = UIView(frame: CGRect(x: 20, y: 110, width: view.bounds.width - 40, height: view.bounds.height - 210))
        scriptHubView?.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 0.9)
        scriptHubView?.layer.cornerRadius = 8
        view.addSubview(scriptHubView!)

        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = CGPoint(x: (scriptHubView?.bounds.width ?? 200) / 2, y: (scriptHubView?.bounds.height ?? 400) / 2)
        activityIndicator.startAnimating()
        scriptHubView?.addSubview(activityIndicator)

        loadScripts(query: "blox")
    }

    private func hideScriptHub() {
        scriptHubView?.removeFromSuperview()
        scriptHubView = nil
    }

    private func loadScripts(query: String) {
        let urlString = "https://scriptblox.com/api/script/search?q=\(query)&mode=free"
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let result = json?["result"] as? [String: Any]
                let scripts = result?["scripts"] as? [[String: Any]] ?? []
                DispatchQueue.main.async {
                    self?.displayScripts(scripts)
                }
            } catch {
                print("Error loading scripts: \(error)")
            }
        }.resume()
    }

    private func displayScripts(_ scripts: [[String: Any]]) {
        scriptHubView?.subviews.forEach { $0.removeFromSuperview() }

        let scrollView = UIScrollView(frame: scriptHubView?.bounds ?? CGRect.zero)
        scriptHubView?.addSubview(scrollView)

        var yOffset: CGFloat = 10
        for (index, script) in scripts.enumerated() {
            let title = script["title"] as? String ?? "Untitled"
            let scriptContent = script["script"] as? String ?? ""
            let game = script["game"] as? String ?? "Unknown Game"

            let card = UIView(frame: CGRect(x: 10, y: yOffset, width: scrollView.bounds.width - 20, height: 80))
            card.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 0.9)
            card.layer.cornerRadius = 8
            card.tag = index

            let titleLabel = UILabel(frame: CGRect(x: 10, y: 5, width: card.bounds.width - 80, height: 25))
            titleLabel.text = title
            titleLabel.textColor = .white
            titleLabel.font = .systemFont(ofSize: 14, weight: .bold)
            card.addSubview(titleLabel)

            let gameLabel = UILabel(frame: CGRect(x: 10, y: 30, width: card.bounds.width - 80, height: 20))
            gameLabel.text = game
            gameLabel.textColor = .lightGray
            gameLabel.font = .systemFont(ofSize: 12)
            card.addSubview(gameLabel)

            let loadBtn = UIButton(frame: CGRect(x: card.bounds.width - 70, y: 25, width: 60, height: 30))
            loadBtn.setTitle("Load", for: .normal)
            loadBtn.backgroundColor = UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 0.8)
            loadBtn.layer.cornerRadius = 6
            loadBtn.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
            loadBtn.tag = index
            loadBtn.addTarget(self, action: #selector(loadScriptFromHub(_:)), for: .touchUpInside)
            objc_setAssociatedObject(loadBtn, "scriptContent", scriptContent, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            card.addSubview(loadBtn)

            scrollView.addSubview(card)
            yOffset += 90
        }

        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: yOffset + 20)
    }

    @objc private func loadScriptFromHub(_ sender: UIButton) {
        let scriptContent = objc_getAssociatedObject(sender, "scriptContent") as? String ?? ""
        textView.text = scriptContent
        toggleScriptHub()
    }

    @objc func executeScript() {
        let script = textView.text ?? ""
        guard !script.isEmpty else { return }
        script.withCString { ptr in
            ExecuteScript(ptr)
        }
    }

    @objc func clearScript() {
        textView.text = ""
    }

    @objc func saveScript() {
        UserDefaults.standard.set(textView.text, forKey: "XZXSavedScript")
        UserDefaults.standard.synchronize()

        let alert = UIAlertController(title: "Saved", message: "Script saved successfully", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc func close() {
        view.isHidden = true
    }

    @objc private func handleScriptLoad(_ notification: Notification) {
        if let script = notification.object as? String {
            textView.text = script
        }
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        guard let query = searchBar.text, !query.isEmpty else { return }
        loadScripts(query: query)
    }

    public func textViewDidChange(_ textView: UITextView) {
        UserDefaults.standard.set(textView.text, forKey: "XZXSavedScript")
    }
}
