//
//  SKPhotoBrowser.swift
//  SKViewExample
//
//  Created by suzuki_keishi on 2015/10/01.
//  Copyright © 2015 suzuki_keishi. All rights reserved.
//

import UIKit

public let SKPHOTO_LOADING_DID_END_NOTIFICATION = "photoLoadingDidEndNotification"

// MARK: - SKPhotoBrowser
open class SKPhotoBrowser: UIViewController {
    // open function
    open var currentPageIndex: Int = 0
    open var initPageIndex: Int = 0
    open var photos: [SKPhotoProtocol] = []
    open var autoHideControllsfadeOutDelay: Double = 4.0
    open var shouldAutoHideControlls: Bool = true

    internal lazy var pagingScrollView: SKPagingScrollView = SKPagingScrollView(frame: self.view.frame, browser: self)

    // appearance
    fileprivate let bgColor: UIColor = SKPhotoBrowserOptions.backgroundColor
    // animation
    let animator: SKAnimator = .init()

    // child component
    private var standaloneNavBar: UINavigationBar?
    fileprivate(set) var paginationView: SKPaginationView!
    fileprivate(set) var toolbar: SKToolbar!

    // actions
    fileprivate var panGesture: UIPanGestureRecognizer?

    // for status check property
    fileprivate var isEndAnimationByToolBar: Bool = true
    fileprivate var isViewActive: Bool = false
    fileprivate var isPerformingLayout: Bool = false

    // pangesture property
    fileprivate var firstX: CGFloat = 0.0
    fileprivate var firstY: CGFloat = 0.0
    fileprivate var targetCornerRadius: CGFloat = 0.0
    fileprivate var isCompletingPresent = false
    fileprivate var naturalPanCenter: CGPoint = .zero

    // timer
    fileprivate var controlVisibilityTimer: Timer!

    // delegate
    open weak var delegate: SKPhotoBrowserDelegate?

    // statusbar initial state
    private var statusbarHidden: Bool = UIApplication.shared.isStatusBarHidden

    // MARK: - Initializer
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    public override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
        super.init(nibName: nil, bundle: nil)
        setup()
    }

    public convenience init(photos: [SKPhotoProtocol]) {
        self.init(photos: photos, initialPageIndex: 0)
    }

    @available(*, deprecated)
    public convenience init(originImage: UIImage, photos: [SKPhotoProtocol], animatedFromView: UIView) {
        self.init(nibName: nil, bundle: nil)
        self.photos = photos
        self.photos.forEach { $0.checkCache() }
        animator.senderOriginImage = originImage
        animator.senderViewForAnimation = animatedFromView
    }

    public convenience init(photos: [SKPhotoProtocol], initialPageIndex: Int) {
        self.init(nibName: nil, bundle: nil)
        self.photos = photos
        self.currentPageIndex = min(initialPageIndex, photos.count - 1)
        self.initPageIndex = self.currentPageIndex
        animator.senderOriginImage = photos[currentPageIndex].underlyingImage
        animator.senderViewForAnimation = photos[currentPageIndex] as? UIView
    }

    func setup() {
        modalPresentationCapturesStatusBarAppearance = true
        modalPresentationStyle = .custom
        transitioningDelegate = self
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSKPhotoLoadingDidEndNotification(_:)),
                                               name: NSNotification.Name(rawValue: SKPHOTO_LOADING_DID_END_NOTIFICATION),
                                               object: nil)
    }

    // MARK: - override
    override open func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        configurePagingScrollView()
        configureGestureControl()
        configurePaginationView()
        configureToolbar()
        configureNavigationBar()

        animator.willPresent(self)
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        reloadData()

        var i = 0
        for photo: SKPhotoProtocol in photos {
            photo.index = i
            i += 1
        }
    }

    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        isPerformingLayout = true
        // where did start
        delegate?.didShowPhotoAtIndex?(self, index: currentPageIndex)

        // toolbar
        toolbar.frame = frameForToolbarAtOrientation()

        // paging
        switch SKCaptionOptions.captionLocation {
        case .basic:
            paginationView.updateFrame(frame: view.frame)
        case .bottom:
            paginationView.frame = frameForPaginationAtOrientation()
        }
        pagingScrollView.updateFrame(view.bounds, currentPageIndex: currentPageIndex)

        isPerformingLayout = false
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        isViewActive = true
    }

    override open var prefersStatusBarHidden: Bool {
        return !SKPhotoBrowserOptions.displayStatusbar
    }

    // MARK: - Notification
    @objc open func handleSKPhotoLoadingDidEndNotification(_ notification: Notification) {
        guard let photo = notification.object as? SKPhotoProtocol else {
            return
        }

        DispatchQueue.main.async(execute: {
            guard let page = self.pagingScrollView.pageDisplayingAtPhoto(photo), let photo = page.photo else {
                return
            }

            if photo.underlyingImage != nil {
                page.displayImage(complete: true)
                self.loadAdjacentPhotosIfNecessary(photo)
            } else {
                page.displayImageFailure()
            }
        })
    }

    open func loadAdjacentPhotosIfNecessary(_ photo: SKPhotoProtocol) {
        pagingScrollView.loadAdjacentPhotosIfNecessary(photo, currentPageIndex: currentPageIndex)
    }

    // MARK: - initialize / setup
    open func reloadData() {
        performLayout()
        view.setNeedsLayout()
    }

    open func performLayout() {
        isPerformingLayout = true

        // reset local cache
        pagingScrollView.reload()
        pagingScrollView.updateContentOffset(currentPageIndex)
        pagingScrollView.tilePages()

        delegate?.didShowPhotoAtIndex?(self, index: currentPageIndex)

        isPerformingLayout = false
    }

    open func prepareForClosePhotoBrowser() {
        cancelControlHiding()
        if let panGesture = panGesture {
            view.removeGestureRecognizer(panGesture)
        }
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }

    open func dismissPhotoBrowser(animated: Bool, completion: (() -> Void)? = nil) {
        prepareForClosePhotoBrowser()

        let onDismissed = {
            completion?()
            self.delegate?.didDismissAtPageIndex?(self.currentPageIndex)
        }

        // If pushed onto a nav stack, pop instead of dismiss
        if let nav = navigationController, nav.viewControllers.contains(self) {
            nav.popViewController(animated: animated)
            onDismissed()
        } else {
            dismiss(animated: animated) {
                onDismissed()
            }
        }
    }

    open func determineAndClose() {
        delegate?.willDismissAtPageIndex?(self.currentPageIndex)
        animator.willDismiss(self)
    }
}

// MARK: - Public Function For Customizing Buttons

public extension SKPhotoBrowser {
    func updateCloseButton(_ image: UIImage, size: CGSize? = nil) {
        let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(closeButtonPressed))
        item.tintColor = .white
        if let standaloneNavBar = standaloneNavBar {
            standaloneNavBar.topItem?.leftBarButtonItem = item
        } else {
            navigationItem.leftBarButtonItem = item
        }
    }
}

// MARK: - Public Function For Browser Control

public extension SKPhotoBrowser {
    func initializePageIndex(_ index: Int) {
        let i = min(index, photos.count - 1)
        currentPageIndex = i

        if isViewLoaded {
            jumpToPageAtIndex(index)
            if !isViewActive {
                pagingScrollView.tilePages()
            }
            paginationView.update(currentPageIndex)
        }
        self.initPageIndex = currentPageIndex
    }

    func jumpToPageAtIndex(_ index: Int) {
        if index < photos.count {
            if !isEndAnimationByToolBar {
                return
            }
            isEndAnimationByToolBar = false

            let pageFrame = frameForPageAtIndex(index)
            pagingScrollView.jumpToPageAtIndex(pageFrame)
        }
        hideControlsAfterDelay()
    }

    func photoAtIndex(_ index: Int) -> SKPhotoProtocol {
        return photos[index]
    }

    @objc func gotoPreviousPage() {
        jumpToPageAtIndex(currentPageIndex - 1)
    }

    @objc func gotoNextPage() {
        jumpToPageAtIndex(currentPageIndex + 1)
    }

    func cancelControlHiding() {
        if controlVisibilityTimer != nil {
            controlVisibilityTimer.invalidate()
            controlVisibilityTimer = nil
        }
    }

    func hideControlsAfterDelay() {
        guard shouldAutoHideControlls else { return }
        cancelControlHiding()
        controlVisibilityTimer = Timer.scheduledTimer(
            timeInterval: autoHideControllsfadeOutDelay,
            target: self,
            selector: #selector(SKPhotoBrowser.hideControls(_:)),
            userInfo: nil,
            repeats: false
        )
    }

    func hideControls() {
        setControlsHidden(true, animated: true, permanent: false)
    }

    @objc func hideControls(_ timer: Timer) {
        hideControls()
        delegate?.controlsVisibilityToggled?(self, hidden: true)
    }

    func toggleControls() {
        let hidden = !areControlsHidden()
        setControlsHidden(hidden, animated: true, permanent: false)
        delegate?.controlsVisibilityToggled?(self, hidden: areControlsHidden())
    }

    func areControlsHidden() -> Bool {
        return paginationView.alpha == 0.0
    }

    func getCurrentPageIndex() -> Int {
        return currentPageIndex
    }

    func addPhotos(photos: [SKPhotoProtocol]) {
        self.photos.append(contentsOf: photos)
        self.reloadData()
    }

    func insertPhotos(photos: [SKPhotoProtocol], at index: Int) {
        self.photos.insert(contentsOf: photos, at: index)
        self.reloadData()
    }
}

// MARK: - Internal Function

internal extension SKPhotoBrowser {
    func showButtons() {
        animateNavBar(hidden: false)
    }

    func pageDisplayedAtIndex(_ index: Int) -> SKZoomingScrollView? {
        return pagingScrollView.pageDisplayedAtIndex(index)
    }

    func getImageFromView(_ sender: UIView) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(sender.frame.size, true, 0.0)
        sender.layer.render(in: UIGraphicsGetCurrentContext()!)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result!
    }
}

// MARK: - Internal Function For Frame Calc

internal extension SKPhotoBrowser {
    func frameForPaginationAtOrientation() -> CGRect {
        let offset = UIDevice.current.orientation.isLandscape ? 35 : 44
        return CGRect(x: 0, y: self.view.bounds.size.height - CGFloat(offset), width: self.view.bounds.size.width, height: CGFloat(offset))
    }

    func frameForToolbarAtOrientation() -> CGRect {
        let offset: CGFloat = {
            if #available(iOS 11.0, *) {
                return view.safeAreaInsets.bottom
            } else {
                return 15
            }
        }()
        let height: CGFloat = {
            if #available(iOS 26.0, *) {
                return 48
            } else {
                return 44
            }
        }()
        return view.bounds.divided(atDistance: height, from: .maxYEdge).slice.offsetBy(dx: 0, dy: -offset)
    }

    func frameForPageAtIndex(_ index: Int) -> CGRect {
        let bounds = pagingScrollView.bounds
        var pageFrame = bounds
        pageFrame.size.width -= (2 * 10)
        pageFrame.origin.x = (bounds.size.width * CGFloat(index)) + 10
        return pageFrame
    }
}

// MARK: - Internal Function For Button Pressed, UIGesture Control

internal extension SKPhotoBrowser {
    @objc func actionButtonPressed(ignoreAndShare: Bool = false) {
        // Override via delegate if needed
    }

    @objc func panGestureRecognized(_ sender: UIPanGestureRecognizer) {
        guard let zoomingScrollView: SKZoomingScrollView = pagingScrollView.pageDisplayedAtIndex(currentPageIndex) else {
            return
        }

        animator.backgroundView.isHidden = true
        let viewHeight: CGFloat = zoomingScrollView.frame.size.height
        let viewHalfHeight: CGFloat = viewHeight / 2

        // gesture began
        if sender.state == .began {
            let sourceView = delegate?.viewForPhoto?(self, index: currentPageIndex)
            targetCornerRadius = sourceView?.layer.cornerRadius ?? 0

            if let currentFrame = animator.interruptPresent(in: self) {
                // Interrupted present animation — swap to browser content
                naturalPanCenter = zoomingScrollView.center

                let interruptedCenter = pagingScrollView.convert(
                    CGPoint(x: currentFrame.midX, y: currentFrame.midY),
                    from: nil
                )
                let scale = currentFrame.width / animator.finalImageViewFrame.width

                zoomingScrollView.center = interruptedCenter
                zoomingScrollView.transform = CGAffineTransform(scaleX: scale, y: scale)

                firstX = interruptedCenter.x
                firstY = interruptedCenter.y
                isCompletingPresent = true

                // Continue zoom-in as spring while finger controls position
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    usingSpringWithDamping: 1.0,
                    initialSpringVelocity: 0,
                    options: .allowUserInteraction
                ) {
                    zoomingScrollView.transform = .identity
                } completion: { [weak self] _ in
                    self?.isCompletingPresent = false
                }
            } else {
                firstX = zoomingScrollView.center.x
                firstY = zoomingScrollView.center.y
            }

            setNeedsStatusBarAppearanceUpdate()
        }

        let translationY = sender.translation(in: view).y
        let dragDistance = abs(translationY)
        let progress = min(dragDistance / viewHalfHeight, 1.0)

        // Move image — always follows finger
        zoomingScrollView.center = CGPoint(x: firstX, y: firstY + translationY)

        // During zoom-in completion, spring handles the scale
        if !isCompletingPresent {
            // Scale — gentle ease-in curve, shrinks to 0.8 at max drag
            let scale = 1.0 - pow(progress, 1.4) * 0.2
            zoomingScrollView.transform = CGAffineTransform(scaleX: scale, y: scale)

            // Corner radius on the imageView directly (not the scrollView —
            // the scrollView is 402x874 but the image is only ~402x268 centered inside,
            // so corner radius on the scrollView clips empty space, not the image).
            if targetCornerRadius > 0 {
                let sourceView = delegate?.viewForPhoto?(self, index: currentPageIndex)
                let sourceWidth = sourceView?.bounds.width ?? 200
                let sourceRatio = targetCornerRadius / sourceWidth
                let imageWidth = zoomingScrollView.imageView.bounds.width
                // The imageView has its own transform from zoom scale — use it
                let imageScale = zoomingScrollView.imageView.transform.a
                let currentVisualWidth = imageWidth * imageScale * scale
                let visualRadius = currentVisualWidth * sourceRatio * pow(progress, 0.8)
                // ImageView layer radius is in its own local coords (pre-transform)
                let layerRadius = visualRadius / (imageScale * scale)
                zoomingScrollView.imageView.layer.cornerRadius = layerRadius
                zoomingScrollView.imageView.clipsToBounds = true
            }
        }

        // Background — delayed start at 20%, soft ease-out, floors at 0.5 alpha
        let bgThreshold: CGFloat = 0.2
        let bgProgress = max(progress - bgThreshold, 0) / (1.0 - bgThreshold)
        let bgAlpha = 1.0 - pow(bgProgress, 2.0) * 0.5
        view.backgroundColor = bgColor.withAlphaComponent(bgAlpha)

        // Controls — delayed hide, only after 8% dragged
        if dragDistance > viewHalfHeight * 0.08 && !areControlsHidden() {
            hideControls()
        }

        let dismissThreshold: CGFloat = viewHalfHeight / 4

        // gesture end
        if sender.state == .ended {
            // Freeze zoom-in spring at current visual state if still active
            if isCompletingPresent {
                if let presentation = zoomingScrollView.layer.presentation() {
                    let t = presentation.transform
                    zoomingScrollView.layer.removeAllAnimations()
                    zoomingScrollView.transform = CATransform3DGetAffineTransform(t)
                }
            }

            let isDismissing: Bool
            if isCompletingPresent {
                // Use drag displacement for threshold when interrupted mid-present
                isDismissing = abs(translationY) > dismissThreshold
            } else {
                isDismissing = zoomingScrollView.center.y > viewHalfHeight + dismissThreshold
                    || zoomingScrollView.center.y < viewHalfHeight - dismissThreshold
            }

            let wasCompletingPresent = isCompletingPresent
            isCompletingPresent = false

            if isDismissing {
                // Check if displacement source exists
                let hasSourceView = delegate?.viewForPhoto?(self, index: currentPageIndex) != nil

                if hasSourceView {
                    // Displacement — go directly to source
                    // Don't reset transform — animator captures the visual frame as-is
                    determineAndClose()
                } else {
                    // No source — momentum exit off-screen, then dismiss
                    let velocityY = sender.velocity(in: view).y
                    let direction: CGFloat = translationY > 0 ? 1 : -1
                    let exitSpeed = max(abs(velocityY), 600)
                    let exitTarget = CGPoint(x: firstX, y: zoomingScrollView.center.y + direction * viewHeight)
                    let remaining = abs(exitTarget.y - zoomingScrollView.center.y)
                    let springVelocity = remaining > 0 ? exitSpeed / remaining : 1.0

                    UIView.animate(
                        withDuration: 0.35,
                        delay: 0,
                        usingSpringWithDamping: 1.0,
                        initialSpringVelocity: springVelocity,
                        options: [.curveEaseOut, .allowUserInteraction]
                    ) {
                        zoomingScrollView.center = exitTarget
                        zoomingScrollView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
                        self.view.backgroundColor = self.bgColor.withAlphaComponent(0)
                    } completion: { [weak self] _ in
                        self?.determineAndClose()
                    }
                }

            } else {
                // Cancelled — spring back to natural position
                let targetCenter = wasCompletingPresent
                    ? naturalPanCenter
                    : CGPoint(x: firstX, y: viewHalfHeight)

                UIView.animate(
                    withDuration: 0.5,
                    delay: 0,
                    usingSpringWithDamping: 0.78,
                    initialSpringVelocity: 0.2,
                    options: [.curveEaseOut, .allowUserInteraction]
                ) {
                    zoomingScrollView.center = targetCenter
                    zoomingScrollView.transform = .identity
                    zoomingScrollView.imageView.layer.cornerRadius = 0
                    self.view.backgroundColor = self.bgColor
                } completion: { [weak self] _ in
                    self?.setControlsHidden(false, animated: true, permanent: false)
                }
            }
        }
    }
}

// MARK: - Private Function
private extension SKPhotoBrowser {
    func configureAppearance() {
        view.backgroundColor = bgColor
        view.clipsToBounds = true
        view.isOpaque = false
        view.accessibilityIgnoresInvertColors = true
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
    }

    func configurePagingScrollView() {
        pagingScrollView.delegate = self
        view.addSubview(pagingScrollView)
        if SKPhotoBrowserOptions.protectScreenshot {
            pagingScrollView.protectScreenshot()
        }
    }

    func configureGestureControl() {
        guard !SKPhotoBrowserOptions.disableVerticalSwipe else { return }

        panGesture = UIPanGestureRecognizer(target: self, action: #selector(SKPhotoBrowser.panGestureRecognized(_:)))
        panGesture?.minimumNumberOfTouches = 1
        panGesture?.maximumNumberOfTouches = 1

        if let panGesture = panGesture {
            view.addGestureRecognizer(panGesture)
        }
    }

    func configurePaginationView() {
        paginationView = SKPaginationView(frame: view.frame, browser: self)
        view.addSubview(paginationView)
    }

    func configureToolbar() {
        toolbar = SKToolbar(frame: frameForToolbarAtOrientation(), browser: self)
        view.addSubview(toolbar)
    }

    func configureNavigationBar() {
        let closeItem = SKBarButtonItemFactory.closeBarButtonItem(target: self, action: #selector(closeButtonPressed))

        if let navController = navigationController {
            navigationItem.leftBarButtonItem = SKPhotoBrowserOptions.displayCloseButton ? closeItem : nil
            makeNavigationBarTransparent(navController.navigationBar)
        } else {
            let navBar = UINavigationBar()
            navBar.translatesAutoresizingMaskIntoConstraints = false
            makeNavigationBarTransparent(navBar)

            let navItem = UINavigationItem()
            navItem.leftBarButtonItem = SKPhotoBrowserOptions.displayCloseButton ? closeItem : nil
            navBar.setItems([navItem], animated: false)

            view.addSubview(navBar)
            NSLayoutConstraint.activate([
                navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])

            standaloneNavBar = navBar
        }
    }

    @objc func closeButtonPressed() {
        determineAndClose()
    }

    func makeNavigationBarTransparent(_ navBar: UINavigationBar) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.isTranslucent = true
        navBar.backgroundColor = .clear
        navBar.overrideUserInterfaceStyle = .dark
    }

    func animateNavBar(hidden: Bool) {
        guard hidden == true else { return }
        guard SKPhotoBrowserOptions.displayCloseButton else { return }
        let alpha: CGFloat = hidden ? 0.0 : 1.0
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            if let standaloneNavBar = self.standaloneNavBar {
                standaloneNavBar.alpha = alpha
            } else {
                self.navigationController?.navigationBar.alpha = alpha
            }
        }
    }

    func setControlsHidden(_ hidden: Bool, animated: Bool, permanent: Bool) {
        guard hidden == true else { return }
        // timer update
        cancelControlHiding()

        // scroll animation
        pagingScrollView.setControlsHidden(hidden: hidden)

        // paging animation
        paginationView.setControlsHidden(hidden: hidden)

        // nav bar animation
        animateNavBar(hidden: hidden)

        if !hidden && !permanent {
            hideControlsAfterDelay()
        }
        setNeedsStatusBarAppearanceUpdate()
    }
}

// MARK: - UIScrollView Delegate

extension SKPhotoBrowser: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard isViewActive else { return }
        guard !isPerformingLayout else { return }

        // tile page
        pagingScrollView.tilePages()

        // Calculate current page
        let previousCurrentPage = currentPageIndex
        let visibleBounds = pagingScrollView.bounds
        currentPageIndex = min(max(Int(floor(visibleBounds.midX / visibleBounds.width)), 0), photos.count - 1)

        if currentPageIndex != previousCurrentPage {
            delegate?.didShowPhotoAtIndex?(self, index: currentPageIndex)
            paginationView.update(currentPageIndex)
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        hideControlsAfterDelay()

        let currentIndex = pagingScrollView.contentOffset.x / pagingScrollView.frame.size.width
        delegate?.didScrollToIndex?(self, index: Int(currentIndex))
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isEndAnimationByToolBar = true
    }
}

// MARK: - UIViewControllerTransitioningDelegate
// Zero-duration UIKit transition so touches are not blocked during
// the custom present animation driven by SKAnimator.

extension SKPhotoBrowser: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return SKInstantPresentAnimator()
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return SKInstantPresentAnimator()
    }
}

private final class SKInstantPresentAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        return 0
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        if let toVC = transitionContext.viewController(forKey: .to),
           let toView = transitionContext.view(forKey: .to) {
            toView.frame = transitionContext.finalFrame(for: toVC)
            transitionContext.containerView.addSubview(toView)
        }
        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    }
}
