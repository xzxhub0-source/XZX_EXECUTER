import UIKit

class HubView: UIView {
    
    private let collectionView: UICollectionView
    private let searchBar = UISearchBar()
    private var scripts: [ScriptItem] = []
    
    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 280, height: 120)
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 15
        layout.sectionInset = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(frame: frame)
        build()
    }
    
    required init?(coder: NSCoder) {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 280, height: 120)
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 15
        layout.sectionInset = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(coder: coder)
        build()
    }
    
    private func build() {
        backgroundColor = .clear
        
        searchBar.frame = CGRect(x: 10, y: 10, width: bounds.width - 20, height: 50)
        searchBar.autoresizingMask = [.flexibleWidth]
        searchBar.placeholder = "Search ScriptBlox..."
        searchBar.searchBarStyle = .minimal
        searchBar.barStyle = .black
        searchBar.tintColor = UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 1)
        searchBar.delegate = self
        addSubview(searchBar)
        
        collectionView.frame = CGRect(x: 0, y: 70, width: bounds.width, height: bounds.height - 70)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        collectionView.register(ScriptCardCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = self
        collectionView.delegate = self
        addSubview(collectionView)
        
        search(query: "blox")
    }
    
    func search(query: String) {
        ScriptBloxAPI.shared.search(query: query) { [weak self] scripts in
            self?.scripts = scripts
            self?.collectionView.reloadData()
        }
    }
}

extension HubView: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let query = searchBar.text, !query.isEmpty {
            search(query: query)
        }
    }
}

extension HubView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return scripts.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! ScriptCardCell
        cell.configure(with: scripts[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let script = scripts[indexPath.item]
        NotificationCenter.default.post(name: NSNotification.Name("LoadScript"), 
                                        object: script)
    }
}

class ScriptCardCell: UICollectionViewCell {
    
    private let titleLabel = UILabel()
    private let gameLabel = UILabel()
    private let thumbnailView = UIImageView()
    private let loadButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 0.9)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 0.3).cgColor
        
        thumbnailView.frame = CGRect(x: 8, y: 8, width: 50, height: 50)
        thumbnailView.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1)
        thumbnailView.layer.cornerRadius = 8
        thumbnailView.clipsToBounds = true
        contentView.addSubview(thumbnailView)
        
        titleLabel.frame = CGRect(x: 66, y: 8, width: frame.width - 74, height: 20)
        titleLabel.font = .systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = .white
        contentView.addSubview(titleLabel)
        
        gameLabel.frame = CGRect(x: 66, y: 28, width: frame.width - 74, height: 16)
        gameLabel.font = .systemFont(ofSize: 12)
        gameLabel.textColor = .lightGray
        contentView.addSubview(gameLabel)
        
        loadButton.frame = CGRect(x: frame.width - 60, y: 40, width: 50, height: 30)
        loadButton.setTitle("Load", for: .normal)
        loadButton.backgroundColor = UIColor(red: 0.65, green: 0.35, blue: 1, alpha: 0.8)
        loadButton.setTitleColor(.white, for: .normal)
        loadButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        loadButton.layer.cornerRadius = 8
        contentView.addSubview(loadButton)
    }
    
    func configure(with script: ScriptItem) {
        titleLabel.text = script.title
        gameLabel.text = script.game ?? "Unknown Game"
        
        if let thumbUrl = script.thumbnail {
            ScriptBloxAPI.shared.loadThumbnail(url: thumbUrl) { [weak self] image in
                self?.thumbnailView.image = image
            }
        }
    }
}
