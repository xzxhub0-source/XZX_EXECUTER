import UIKit

public class SidebarView: UIView {
    
    public var buttons: [UIButton] = []
    public var onTabSelected: ((Int) -> Void)?
    
    private let items = [
        ("📝", "Editor"),
        ("🌐", "Hub"),
        ("📌", "Tabs"),
        ("💾", "Saved"),
        ("⚙️", "Settings")
    ]
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }
    
    private func build() {
        backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 0.9)
        layer.cornerRadius = 12
        
        for i in 0..<items.count {
            let btn = createButton(title: "\(items[i].0) \(items[i].1)", tag: i)
            btn.frame = CGRect(x: 10, y: 20 + (i * 55), width: 160, height: 45)
            addSubview(btn)
            buttons.append(btn)
        }
        
        animateButton(buttons[0])
    }
    
    private func createButton(title: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        btn.backgroundColor = UIColor(red: 0.16, green: 0.14, blue: 0.22, alpha: 1)
        btn.layer.cornerRadius = 10
        btn.tag = tag
        btn.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        
        btn.layer.shadowColor = UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 0.5).cgColor
        btn.layer.shadowOffset = .zero
        btn.layer.shadowRadius = 5
        btn.layer.shadowOpacity = 0
        
        return btn
    }
    
    private func animateButton(_ button: UIButton) {
        let animation = CABasicAnimation(keyPath: "shadowOpacity")
        animation.fromValue = 0
        animation.toValue = 0.8
        animation.duration = 1.5
        animation.autoreverses = true
        animation.repeatCount = .infinity
        button.layer.add(animation, forKey: "buttonGlow")
    }
    
    @objc private func buttonTapped(_ sender: UIButton) {
        buttons.forEach { btn in
            btn.backgroundColor = UIColor(red: 0.16, green: 0.14, blue: 0.22, alpha: 1)
            btn.layer.removeAnimation(forKey: "buttonGlow")
            btn.layer.shadowOpacity = 0
        }
        
        sender.backgroundColor = UIColor(red: 0.25, green: 0.2, blue: 0.35, alpha: 1)
        animateButton(sender)
        onTabSelected?(sender.tag)
    }
}
