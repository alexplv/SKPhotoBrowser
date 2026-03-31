import SwiftUI
import SKPhotoBrowser

// MARK: - ViewAnchor

/// Transparent UIViewRepresentable overlay that exposes a real UIView reference
/// for bridging SwiftUI → UIKit displacement transitions.
struct ViewAnchor: UIViewRepresentable {
    let onViewReady: (UIView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            onViewReady(uiView)
        }
    }
}

// MARK: - Simple image loader (test app only — real app uses Kingfisher)

@MainActor
@Observable
class ImageStore {
    var images: [Int: UIImage] = [:]

    func load(index: Int, url: URL) {
        guard images[index] == nil else { return }
        Task.detached {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            await MainActor.run { self.images[index] = image }
        }
    }
}

// MARK: - SwiftUI Gallery Grid

struct SwiftUIGalleryDemoView: View {
    private let urls = [
        "https://picsum.photos/id/10/600/400",
        "https://picsum.photos/id/20/400/600",
        "https://picsum.photos/id/29/600/400",
        "https://picsum.photos/id/37/400/600",
        "https://picsum.photos/id/49/600/400",
        "https://picsum.photos/id/57/600/400",
        "https://picsum.photos/id/65/400/600",
        "https://picsum.photos/id/76/600/400",
        "https://picsum.photos/id/84/400/600",
    ]

    @State private var anchorViews: [Int: UIView] = [:]
    @State private var imageStore = ImageStore()
    @State private var browserPresenter = PhotoBrowserPresenter()

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, urlString in
                    thumbnailCell(index: index, urlString: urlString)
                }
            }
            .padding(2)
        }
        .navigationTitle("SwiftUI → UIKit")
    }

    @ViewBuilder
    private func thumbnailCell(index: Int, urlString: String) -> some View {
        let image = imageStore.images[index]

        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray.opacity(0.15)
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                ViewAnchor { view in
                    anchorViews[index] = view
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                openBrowser(at: index)
            }
            .onAppear {
                if let url = URL(string: urlString) {
                    imageStore.load(index: index, url: url)
                }
            }
    }

    private func openBrowser(at index: Int) {
        SKPhotoBrowserOptions.displayCloseButton = true
        SKPhotoBrowserOptions.displayAction = false
        SKPhotoBrowserOptions.displayBackAndForwardButton = false
        SKPhotoBrowserOptions.displayCounterLabel = true
        SKPhotoBrowserOptions.disableVerticalSwipe = false

        // Use full-res URLs for the browser
        let fullResURLs = [
            "https://picsum.photos/id/10/1200/800",
            "https://picsum.photos/id/20/800/1200",
            "https://picsum.photos/id/29/1200/800",
            "https://picsum.photos/id/37/800/1200",
            "https://picsum.photos/id/49/1200/800",
            "https://picsum.photos/id/57/1200/800",
            "https://picsum.photos/id/65/800/1200",
            "https://picsum.photos/id/76/1200/800",
            "https://picsum.photos/id/84/800/1200",
        ]
        let photos: [SKPhoto] = fullResURLs.map { SKPhoto.photoWithImageURL($0) }

        browserPresenter.present(
            photos: photos,
            initialIndex: index,
            originImage: imageStore.images[index],
            sourceViewProvider: { [anchorViews] photoIndex in
                anchorViews[photoIndex]
            }
        )
    }
}

// MARK: - Presenter bridge (SwiftUI → UIKit modal)

@MainActor
class PhotoBrowserPresenter {
    func present(
        photos: [SKPhoto],
        initialIndex: Int,
        originImage: UIImage?,
        sourceViewProvider: @escaping (Int) -> UIView?
    ) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let presenter = rootVC.topmost

        let browser: SKPhotoBrowser
        if let image = originImage, let sourceView = sourceViewProvider(initialIndex) {
            browser = SKPhotoBrowser(originImage: image, photos: photos, animatedFromView: sourceView)
            browser.initializePageIndex(initialIndex)
        } else {
            browser = SKPhotoBrowser(photos: photos, initialPageIndex: initialIndex)
        }

        let proxy = DelegateProxy(sourceViewProvider: sourceViewProvider)
        browser.delegate = proxy
        objc_setAssociatedObject(browser, &DelegateProxy.key, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        presenter.present(browser, animated: true)
    }
}

private extension UIViewController {
    var topmost: UIViewController {
        var vc: UIViewController = self
        while let presented = vc.presentedViewController { vc = presented }
        return vc
    }
}

// MARK: - Delegate proxy for displacement source

private class DelegateProxy: NSObject, SKPhotoBrowserDelegate {
    static var key: UInt8 = 0
    let sourceViewProvider: (Int) -> UIView?

    init(sourceViewProvider: @escaping (Int) -> UIView?) {
        self.sourceViewProvider = sourceViewProvider
    }

    func viewForPhoto(_ browser: SKPhotoBrowser, index: Int) -> UIView? {
        sourceViewProvider(index)
    }

    func didDismissAtPageIndex(_ index: Int) {
        print("[SwiftUI] dismissed at \(index)")
    }
}

// MARK: - UIKit hosting wrapper

class SwiftUIGalleryDemoHostingController: UIHostingController<SwiftUIGalleryDemoView> {
    init() {
        super.init(rootView: SwiftUIGalleryDemoView())
    }

    required init?(coder: NSCoder) { fatalError() }
}
