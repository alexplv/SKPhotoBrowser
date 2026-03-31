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

// MARK: - SwiftUI Gallery Grid

struct SwiftUIGalleryDemoView: View {
    private let urls = [
        "https://picsum.photos/id/10/1200/800",
        "https://picsum.photos/id/20/800/1200",
        "https://picsum.photos/id/29/1200/800",
        "https://picsum.photos/id/37/800/1200",
        "https://picsum.photos/id/49/1200/800",
        "https://picsum.photos/id/57/1200/800",
    ]

    @State private var anchorViews: [Int: UIView] = [:]
    @State private var loadedImages: [Int: UIImage] = [:]

    /// Bridge to present SKPhotoBrowser from SwiftUI
    @State private var browserPresenter = PhotoBrowserPresenter()

    let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, urlString in
                    AsyncImage(url: URL(string: urlString)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(minHeight: 120)
                                .clipped()
                                .onAppear {
                                    // Cache the UIImage for displacement
                                    if let uiImage = ImageRenderer(content: image.resizable()).uiImage {
                                        loadedImages[index] = uiImage
                                    }
                                }
                        case .failure:
                            Color.gray.opacity(0.3)
                                .frame(minHeight: 120)
                        default:
                            Color.gray.opacity(0.1)
                                .frame(minHeight: 120)
                        }
                    }
                    .frame(minHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        // Anchor: invisible UIView for displacement source
                        ViewAnchor { view in
                            anchorViews[index] = view
                        }
                    }
                    .onTapGesture {
                        openBrowser(at: index)
                    }
                }
            }
            .padding(4)
        }
        .navigationTitle("SwiftUI → UIKit")
    }

    private func openBrowser(at index: Int) {
        SKPhotoBrowserOptions.displayCloseButton = true
        SKPhotoBrowserOptions.displayAction = false
        SKPhotoBrowserOptions.displayBackAndForwardButton = false
        SKPhotoBrowserOptions.displayCounterLabel = true
        SKPhotoBrowserOptions.disableVerticalSwipe = false

        let photos: [SKPhoto] = urls.map { SKPhoto.photoWithImageURL($0) }

        browserPresenter.present(
            photos: photos,
            initialIndex: index,
            originImage: loadedImages[index],
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

        browser.delegate = DelegateProxy(sourceViewProvider: sourceViewProvider)
        // Keep delegate alive for the browser's lifetime
        objc_setAssociatedObject(browser, &DelegateProxy.key, browser.delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

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
