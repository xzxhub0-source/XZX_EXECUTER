import UIKit

class NeonWindow: UIView {
    
    private let gradientLayer = CAGradientLayer()
    private var dragStartPoint: CGPoint?
    private var dragStartFrame: CGRect?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupDragging()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupDragging()
    }
    
    private func setup() {
        backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 0.95)
        layer.cornerRadius = 18
        layer.masksToBounds = true
        
        gradientLayer.frame = bounds
        gradientLayer.colors = [
            UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 1).cgColor,
            UIColor(red: 0.45, green: 0.25, blue: 0.8, alpha: 1).cgColor,
            UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 1).cgColor
        ]
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradientLayer)
        
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [0, 0.5, 1]
        animation.toValue = [0.2, 0.7, 1.2]
        animation.duration = 3
        animation.autoreverses = true
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: "glowAnimation")
        
        layer.shadowColor = UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 1).cgColor
        layer.shadowOpacity = 0.8
        layer.shadowRadius = 25
        layer.shadowOffset = .zero
    }
    
    private func setupDragging() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
        addGestureRecognizer(panGesture)
    }
    
    @objc private func handleDrag(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            dragStartPoint = gesture.location(in: superview)
            dragStartFrame = frame
        case .changed:
            guard let startPoint = dragStartPoint,
                  let startFrame = dragStartFrame else { return }
            
            let translation = gesture.location(in: superview)
            let dx = translation.x - startPoint.x
            let dy = translation.y - startPoint.y
            
            frame = CGRect(
                x: startFrame.origin.x + dx,
                y: startFrame.origin.y + dy,
                width: startFrame.width,
                height: startFrame.height
            )
        default:
            dragStartPoint = nil
            dragStartFrame = nil
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}
