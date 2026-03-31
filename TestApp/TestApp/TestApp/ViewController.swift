import UIKit
import SKPhotoBrowser

// MARK: - Sample Data

private let sampleURLs = [
    "https://picsum.photos/id/10/1200/800",
    "https://picsum.photos/id/20/800/1200",
    "https://picsum.photos/id/29/1200/800",
    "https://picsum.photos/id/37/800/1200",
    "https://picsum.photos/id/49/1200/800",
]

private let sampleCaptions = [
    "Misty forest trail in the morning light",
    "Coastal cliffs at golden hour",
    "Mountain peak above the clouds",
    "Cherry blossoms along the river",
    "Traditional village at sunset",
]

// MARK: - Demo Scenarios

private enum Demo: CaseIterable {
    case singleImage
    case multipleImages
    case withCaptions
    case swipeDismissOnly
    case closeButtonOnly
    case counterHidden
    case customBackground
    case zoomTransition

    var title: String {
        switch self {
        case .singleImage:        return "Single Image"
        case .multipleImages:     return "Multiple Images (5)"
        case .withCaptions:       return "With Captions"
        case .swipeDismissOnly:   return "Swipe Dismiss Only (no close btn)"
        case .closeButtonOnly:    return "Close Button Only (no swipe)"
        case .counterHidden:      return "Counter Hidden"
        case .customBackground:   return "Custom Background (dark gray)"
        case .zoomTransition:     return "iOS 18 Zoom Transition"
        }
    }

    var subtitle: String {
        switch self {
        case .singleImage:        return "Basic single photo viewer"
        case .multipleImages:     return "Paging, zoom, swipe dismiss, close"
        case .withCaptions:       return "Each photo has a caption label"
        case .swipeDismissOnly:   return "displayCloseButton = false"
        case .closeButtonOnly:    return "disableVerticalSwipe = true"
        case .counterHidden:      return "displayCounterLabel = false"
        case .customBackground:   return "backgroundColor = .darkGray"
        case .zoomTransition:     return "preferredTransition = .zoom (fluid)"
        }
    }
}

// MARK: - Demo List

class DemoListViewController: UITableViewController {

    private let demos = Demo.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "SKPhotoBrowser Tests"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        demos.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let demo = demos[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = demo.title
        config.secondaryText = demo.subtitle
        config.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presentDemo(demos[indexPath.row])
    }

    // MARK: - Present

    private func presentDemo(_ demo: Demo) {
        // Reset all options to defaults before each demo
        resetOptions()

        let photos: [SKPhoto]
        let startIndex: Int

        switch demo {
        case .singleImage:
            photos = [makePhoto(index: 0)]
            startIndex = 0

        case .multipleImages:
            photos = (0..<sampleURLs.count).map { makePhoto(index: $0) }
            startIndex = 0

        case .withCaptions:
            photos = (0..<sampleURLs.count).map { makePhoto(index: $0, caption: sampleCaptions[$0]) }
            startIndex = 0

        case .swipeDismissOnly:
            SKPhotoBrowserOptions.displayCloseButton = false
            photos = (0..<3).map { makePhoto(index: $0) }
            startIndex = 0

        case .closeButtonOnly:
            SKPhotoBrowserOptions.disableVerticalSwipe = true
            photos = (0..<3).map { makePhoto(index: $0) }
            startIndex = 1

        case .counterHidden:
            SKPhotoBrowserOptions.displayCounterLabel = false
            photos = (0..<sampleURLs.count).map { makePhoto(index: $0) }
            startIndex = 2

        case .customBackground:
            SKPhotoBrowserOptions.backgroundColor = .darkGray
            photos = (0..<3).map { makePhoto(index: $0) }
            startIndex = 0

        case .zoomTransition:
            let gridVC = ThumbnailGridViewController()
            navigationController?.pushViewController(gridVC, animated: true)
            return
        }

        let browser = SKPhotoBrowser(photos: photos, initialPageIndex: startIndex)
        browser.delegate = self
        present(browser, animated: true)
    }

    // MARK: - Helpers

    private func makePhoto(index: Int, caption: String? = nil) -> SKPhoto {
        let photo = SKPhoto.photoWithImageURL(sampleURLs[index % sampleURLs.count])
        photo.caption = caption
        return photo
    }

    private func resetOptions() {
        SKPhotoBrowserOptions.displayStatusbar = false
        SKPhotoBrowserOptions.displayCloseButton = true
        SKPhotoBrowserOptions.displayAction = false
        SKPhotoBrowserOptions.displayBackAndForwardButton = false
        SKPhotoBrowserOptions.displayCounterLabel = true
        SKPhotoBrowserOptions.bounceAnimation = false
        SKPhotoBrowserOptions.enableZoomBlackArea = true
        SKPhotoBrowserOptions.enableSingleTapDismiss = false
        SKPhotoBrowserOptions.backgroundColor = .black
        SKPhotoBrowserOptions.disableVerticalSwipe = false
    }
}

// MARK: - SKPhotoBrowserDelegate

extension DemoListViewController: SKPhotoBrowserDelegate {
    func didShowPhotoAtIndex(_ browser: SKPhotoBrowser, index: Int) {
        print("[Demo] showing photo \(index)")
    }

    func willDismissAtPageIndex(_ index: Int) {
        print("[Demo] will dismiss at \(index)")
    }

    func didDismissAtPageIndex(_ index: Int) {
        print("[Demo] dismissed at \(index)")
        // Reset after dismiss so next demo starts clean
        resetOptions()
    }

    func didScrollToIndex(_ browser: SKPhotoBrowser, index: Int) {
        print("[Demo] scrolled to \(index)")
    }

    func controlsVisibilityToggled(_ browser: SKPhotoBrowser, hidden: Bool) {
        print("[Demo] controls hidden: \(hidden)")
    }
}

// MARK: - iOS 18 Zoom Transition Demo

class ThumbnailGridViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    private var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tap to Zoom"
        view.backgroundColor = .systemBackground

        let layout = UICollectionViewCompositionalLayout { _, environment in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0 / 3.0),
                                                  heightDimension: .fractionalWidth(1.0 / 3.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .fractionalWidth(1.0 / 3.0))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            return NSCollectionLayoutSection(group: group)
        }

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.register(ThumbnailCell.self, forCellWithReuseIdentifier: ThumbnailCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    // MARK: - DataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sampleURLs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ThumbnailCell.reuseID, for: indexPath) as! ThumbnailCell
        cell.loadImage(from: sampleURLs[indexPath.item])
        return cell
    }

    // MARK: - Delegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let tappedIndex = indexPath.item

        // Disable SKPhotoBrowser's own swipe-to-dismiss — the zoom transition handles interactive pop
        SKPhotoBrowserOptions.disableVerticalSwipe = true
        SKPhotoBrowserOptions.displayCloseButton = false
        SKPhotoBrowserOptions.displayAction = false
        SKPhotoBrowserOptions.displayBackAndForwardButton = false
        SKPhotoBrowserOptions.displayCounterLabel = true

        let photos: [SKPhoto] = sampleURLs.map { SKPhoto.photoWithImageURL($0) }
        let browser = SKPhotoBrowser(photos: photos, initialPageIndex: tappedIndex)

        // iOS 18 fluid zoom — source view updates as user pages between photos
        browser.preferredTransition = .zoom { [weak self] context in
            guard let self,
                  let browser = context.zoomedViewController as? SKPhotoBrowser else { return nil }
            let ip = IndexPath(item: browser.currentPageIndex, section: 0)
            return (self.collectionView.cellForItem(at: ip) as? ThumbnailCell)?.imageView
        }

        navigationController?.pushViewController(browser, animated: true)
    }
}

extension ThumbnailGridViewController: SKPhotoBrowserDelegate {
    func didDismissAtPageIndex(_ index: Int) {
        // Reset options after zoom browser pops
        SKPhotoBrowserOptions.disableVerticalSwipe = false
        SKPhotoBrowserOptions.displayCloseButton = true
    }
}

// MARK: - Thumbnail Cell

private class ThumbnailCell: UICollectionViewCell {
    static let reuseID = "ThumbnailCell"

    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.frame = contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }

    func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { self?.imageView.image = image }
        }.resume()
    }
}
