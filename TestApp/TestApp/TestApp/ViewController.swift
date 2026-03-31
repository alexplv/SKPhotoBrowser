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
    case thumbnailGrid
    case displacementTransition
    case swiftUIDisplacement
    case bottomSheetClipping

    var title: String {
        switch self {
        case .singleImage:              return "Single Image"
        case .multipleImages:           return "Multiple Images (5)"
        case .withCaptions:             return "With Captions"
        case .swipeDismissOnly:         return "Swipe Dismiss Only (no close btn)"
        case .closeButtonOnly:          return "Close Button Only (no swipe)"
        case .counterHidden:            return "Counter Hidden"
        case .customBackground:         return "Custom Background (dark gray)"
        case .thumbnailGrid:            return "Thumbnail Grid (fade transition)"
        case .displacementTransition:   return "Displacement Transition (UIKit)"
        case .swiftUIDisplacement:      return "SwiftUI → UIKit Displacement"
        case .bottomSheetClipping:      return "Bottom Sheet (clipped thumbnails)"
        }
    }

    var subtitle: String {
        switch self {
        case .singleImage:              return "Basic single photo viewer"
        case .multipleImages:           return "Paging, zoom, swipe dismiss, close"
        case .withCaptions:             return "Each photo has a caption label"
        case .swipeDismissOnly:         return "displayCloseButton = false"
        case .closeButtonOnly:          return "disableVerticalSwipe = true"
        case .counterHidden:            return "displayCounterLabel = false"
        case .customBackground:         return "backgroundColor = .darkGray"
        case .thumbnailGrid:            return "Grid → modal, no source view"
        case .displacementTransition:   return "Grid → modal, zooms from UIKit thumbnail"
        case .swiftUIDisplacement:      return "SwiftUI grid + ViewAnchor bridge"
        case .bottomSheetClipping:      return "Tests visible-rect masking at sheet edge"
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

        case .thumbnailGrid:
            let gridVC = ThumbnailGridViewController(useDisplacement: false)
            navigationController?.pushViewController(gridVC, animated: true)
            return

        case .displacementTransition:
            let gridVC = ThumbnailGridViewController(useDisplacement: true)
            navigationController?.pushViewController(gridVC, animated: true)
            return

        case .swiftUIDisplacement:
            let vc = SwiftUIGalleryDemoHostingController()
            navigationController?.pushViewController(vc, animated: true)
            return

        case .bottomSheetClipping:
            presentBottomSheetDemo()
            return
        }

        let browser = SKPhotoBrowser(photos: photos, initialPageIndex: startIndex)
        browser.delegate = self
        present(browser, animated: true)
    }

    private func presentBottomSheetDemo() {
        let sheetVC = BottomSheetGalleryViewController()
        sheetVC.modalPresentationStyle = .pageSheet
        if let sheet = sheetVC.sheetPresentationController {
            let smallDetent = UISheetPresentationController.Detent.custom { context in
                context.maximumDetentValue * 0.4
            }
            sheet.detents = [smallDetent, .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
            sheet.selectedDetentIdentifier = smallDetent.identifier
        }
        present(sheetVC, animated: true)
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

// MARK: - Thumbnail Grid Demo

class ThumbnailGridViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    private var collectionView: UICollectionView!
    private let useDisplacement: Bool

    init(useDisplacement: Bool) {
        self.useDisplacement = useDisplacement
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = useDisplacement ? "Displacement Transition" : "Fade Transition"
        view.backgroundColor = .systemBackground

        let layout = UICollectionViewCompositionalLayout { _, _ in
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
        SKPhotoBrowserOptions.displayCloseButton = true
        SKPhotoBrowserOptions.displayAction = false
        SKPhotoBrowserOptions.displayBackAndForwardButton = false
        SKPhotoBrowserOptions.displayCounterLabel = true
        SKPhotoBrowserOptions.disableVerticalSwipe = false

        let photos: [SKPhoto] = sampleURLs.map { SKPhoto.photoWithImageURL($0) }

        if useDisplacement {
            // Displacement path — provide originImage + animatedFromView
            // so the animator zooms from the tapped thumbnail
            guard let cell = collectionView.cellForItem(at: indexPath) as? ThumbnailCell,
                  let thumb = cell.imageView.image else { return }

            let browser = SKPhotoBrowser(originImage: thumb, photos: photos, animatedFromView: cell.imageView)
            browser.initializePageIndex(indexPath.item)
            browser.delegate = self
            present(browser, animated: true)
        } else {
            // Fade path — no source view, browser fades in directly
            let browser = SKPhotoBrowser(photos: photos, initialPageIndex: indexPath.item)
            browser.delegate = self
            present(browser, animated: true)
        }
    }
}

extension ThumbnailGridViewController: SKPhotoBrowserDelegate {
    func didShowPhotoAtIndex(_ browser: SKPhotoBrowser, index: Int) {
        print("[Grid] showing photo \(index)")
    }

    func didDismissAtPageIndex(_ index: Int) {
        print("[Grid] dismissed at \(index)")
    }

    // Displacement path needs this to know where to zoom back to on dismiss
    func viewForPhoto(_ browser: SKPhotoBrowser, index: Int) -> UIView? {
        guard useDisplacement else { return nil }
        let ip = IndexPath(item: index, section: 0)
        return (collectionView.cellForItem(at: ip) as? ThumbnailCell)?.imageView
    }
}

// MARK: - Bottom Sheet Gallery (tests visible-rect clipping)

class BottomSheetGalleryViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    private var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.text = "Scroll down — bottom thumbnails are clipped by the sheet edge"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0 / 3.0),
                                                  heightDimension: .fractionalWidth(1.0 / 3.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .fractionalWidth(1.0 / 3.0))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            return NSCollectionLayoutSection(group: group)
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(ThumbnailCell.self, forCellWithReuseIdentifier: ThumbnailCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.clipsToBounds = true
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            collectionView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sampleURLs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ThumbnailCell.reuseID, for: indexPath) as! ThumbnailCell
        cell.loadImage(from: sampleURLs[indexPath.item])
        cell.imageView.layer.cornerRadius = 12
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ThumbnailCell,
              let thumb = cell.imageView.image else { return }

        SKPhotoBrowserOptions.displayCloseButton = true
        SKPhotoBrowserOptions.displayAction = false
        SKPhotoBrowserOptions.displayBackAndForwardButton = false
        SKPhotoBrowserOptions.displayCounterLabel = true

        let photos: [SKPhoto] = sampleURLs.map { SKPhoto.photoWithImageURL($0) }
        let browser = SKPhotoBrowser(originImage: thumb, photos: photos, animatedFromView: cell.imageView)
        browser.initializePageIndex(indexPath.item)
        browser.delegate = self

        // Present from the window root so gallery covers everything
        if let rootVC = view.window?.rootViewController {
            var presenter: UIViewController = rootVC
            while let p = presenter.presentedViewController { presenter = p }
            presenter.present(browser, animated: true)
        }
    }
}

extension BottomSheetGalleryViewController: SKPhotoBrowserDelegate {
    func viewForPhoto(_ browser: SKPhotoBrowser, index: Int) -> UIView? {
        let ip = IndexPath(item: index, section: 0)
        return (collectionView.cellForItem(at: ip) as? ThumbnailCell)?.imageView
    }

    func didDismissAtPageIndex(_ index: Int) {
        print("[Sheet] dismissed at \(index)")
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
