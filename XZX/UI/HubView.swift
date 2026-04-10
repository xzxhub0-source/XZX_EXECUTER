import UIKit

class HubView: UIView {

    private let scrollView   = UIScrollView()
    private let contentStack = UIStackView()
    private var trendingCV:  UICollectionView!
    private var verifiedCV:  UICollectionView!
    private var trendingScripts: [ScriptItem] = []
    private var verifiedScripts: [ScriptItem] = []
    private var hasLoadedInitial = false

    override init(frame: CGRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { super.init(coder: coder); build() }

    private func build() {
        backgroundColor = .clear
        addSearchPill()
        setupScrollView()
        addSection(title: "Trending scripts",
                   subtitle: "The top scripts featured for today.",
                   exploreLabel: "Explore all trending scripts ›",
                   tag: 0)
        addSection(title: "Verified creators",
                   subtitle: "Scripts published by reputable authors.",
                   exploreLabel: "Explore all verified creators ›",
                   tag: 1)
    }

    private func addSearchPill() {
        let pill = UIView()
        pill.backgroundColor = UIColor(red: 0.38, green: 0.18, blue: 0.65, alpha: 0.75)
        pill.layer.cornerRadius = 20
        pill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pill)

        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = .white
        icon.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(icon)

        let field = UITextField()
        field.attributedPlaceholder = NSAttributedString(
            string: "Search for scripts",
            attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.5)])
        field.textColor = .white
        field.returnKeyType = .search
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(field)

        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pill.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.6),
            pill.heightAnchor.constraint(equalToConstant: 40),
            icon.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            field.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            field.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12),
            field.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
        ])
    }

    private func setupScrollView() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        contentStack.axis    = .vertical
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 60),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func addSection(title: String, subtitle: String, exploreLabel: String, tag: Int) {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.heightAnchor.constraint(equalToConstant: 58).isActive = true

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.textColor = .white
        titleLbl.font = .systemFont(ofSize: 17, weight: .bold)
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLbl)

        let subLbl = UILabel()
        subLbl.text = subtitle
        subLbl.textColor = UIColor(white: 1, alpha: 0.4)
        subLbl.font = .systemFont(ofSize: 11)
        subLbl.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(subLbl)

        let exploreBtn = UIButton(type: .system)
        exploreBtn.setTitle(exploreLabel, for: .normal)
        exploreBtn.setTitleColor(UIColor(red: 0.65, green: 0.45, blue: 1, alpha: 1), for: .normal)
        exploreBtn.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        exploreBtn.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(exploreBtn)

        NSLayoutConstraint.activate([
            titleLbl.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            titleLbl.topAnchor.constraint(equalTo: header.topAnchor, constant: 10),
            subLbl.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            subLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 2),
            exploreBtn.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -12),
            exploreBtn.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        contentStack.addArrangedSubview(header)

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection     = .horizontal
        layout.itemSize            = CGSize(width: 190, height: 120)
        layout.minimumLineSpacing  = 12
        layout.sectionInset        = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.register(ScriptCardCell.self, forCellWithReuseIdentifier: "card")
        cv.tag        = tag
        cv.dataSource = self
        cv.delegate   = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.heightAnchor.constraint(equalToConstant: 140).isActive = true

        if tag == 0 { trendingCV = cv } else { verifiedCV = cv }
        contentStack.addArrangedSubview(cv)

        let gap = UIView()
        gap.translatesAutoresizingMaskIntoConstraints = false
        gap.heightAnchor.constraint(equalToConstant: 20).isActive = true
        contentStack.addArrangedSubview(gap)
    }

    func loadInitialScriptsIfNeeded() {
        guard !hasLoadedInitial else { return }
        hasLoadedInitial = true
        ScriptBloxAPI.shared.search(query: "blox fruits") { [weak self] s in
            self?.trendingScripts = s
            self?.trendingCV?.reloadData()
        }
        ScriptBloxAPI.shared.search(query: "universal") { [weak self] s in
            self?.verifiedScripts = s
            self?.verifiedCV?.reloadData()
        }
    }

    func search(query: String) {
        ScriptBloxAPI.shared.search(query: query) { [weak self] s in
            self?.trendingScripts = s
            self?.trendingCV?.reloadData()
        }
    }
}

extension HubView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let q = textField.text, !q.isEmpty { search(query: q) }
        return true
    }
}

extension HubView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        cv.tag == 0 ? trendingScripts.count : verifiedScripts.count
    }
    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "card", for: ip) as! ScriptCardCell
        let s = cv.tag == 0 ? trendingScripts[ip.item] : verifiedScripts[ip.item]
        cell.configure(with: s)
        return cell
    }
    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        let s = cv.tag == 0 ? trendingScripts[ip.item] : verifiedScripts[ip.item]
        NotificationCenter.default.post(name: NSNotification.Name("LoadScript"), object: s.script)
    }
}

class ScriptCardCell: UICollectionViewCell {

    private let thumb    = UIImageView()
    private let gradient = CAGradientLayer()
    private let titleLbl = UILabel()
    private let gameLbl  = UILabel()
    private let viewsLbl = UILabel()
    private let starBtn  = UIButton(type: .system)

    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        layer.cornerRadius = 12
        clipsToBounds      = true
        backgroundColor    = UIColor(red: 0.14, green: 0.12, blue: 0.22, alpha: 1)

        thumb.contentMode      = .scaleAspectFill
        thumb.clipsToBounds    = true
        thumb.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        thumb.frame            = bounds
        contentView.addSubview(thumb)

        gradient.colors    = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.82).cgColor]
        gradient.locations = [0.35, 1.0]
        contentView.layer.addSublayer(gradient)

        titleLbl.textColor     = .white
        titleLbl.font          = .systemFont(ofSize: 12, weight: .bold)
        titleLbl.numberOfLines = 2
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLbl)

        gameLbl.textColor = UIColor(white: 1, alpha: 0.55)
        gameLbl.font      = .systemFont(ofSize: 10)
        gameLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(gameLbl)

        viewsLbl.textColor = UIColor(white: 1, alpha: 0.45)
        viewsLbl.font      = .systemFont(ofSize: 10)
        viewsLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(viewsLbl)

        starBtn.setImage(UIImage(systemName: "star"), for: .normal)
        starBtn.tintColor = UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)
        starBtn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(starBtn)

        NSLayoutConstraint.activate([
            starBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            starBtn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            starBtn.widthAnchor.constraint(equalToConstant: 22),
            starBtn.heightAnchor.constraint(equalToConstant: 22),

            viewsLbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            viewsLbl.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            gameLbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            gameLbl.bottomAnchor.constraint(equalTo: viewsLbl.topAnchor, constant: -2),

            titleLbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            titleLbl.bottomAnchor.constraint(equalTo: gameLbl.topAnchor, constant: -2),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    func configure(with s: ScriptItem) {
        titleLbl.text = s.title
        gameLbl.text  = s.game ?? "Universal"
        viewsLbl.text = s.views.map { v in "👁 \(v >= 1000 ? "\(v / 1000)k" : "\(v)")" } ?? ""
        thumb.image   = nil
        if let url = s.thumbnail {
            ScriptBloxAPI.shared.loadThumbnail(url: url) { [weak self] img in
                self?.thumb.image = img
            }
        }
    }
}
