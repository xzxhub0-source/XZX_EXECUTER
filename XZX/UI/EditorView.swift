import UIKit
import Combine

class EditorView: UIView {
    
    let textView = UITextView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }
    
    private func build() {
        backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        layer.cornerRadius = 12
        
        textView.frame = bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textView.font = UIFont(name: "Menlo", size: 14)
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.text = "-- XZX Executor\nprint('Hello World!')"
        addSubview(textView)
    }
}

extension EditorView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        NotificationCenter.default.post(name: NSNotification.Name("EditorContentChanged"), 
                                        object: textView.text)
    }
}
