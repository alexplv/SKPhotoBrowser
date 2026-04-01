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
    fileprivate var actionView: SKActionView!
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
        modalTransitionStyle = .crossDissolve
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
        configureActionView()
        configurePaginationView()
        configureToolbar()

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

        // action
        actionView.updateFrame(frame: view.frame)

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
        actionView.updateCloseButton(image: image, size: size)
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
        controlVisibilityTimer = Timer.scheduledTimer(timeInterval: autoHideControllsfadeOutDelay, target: self, selector: #selector(SKPhotoBrowser.hideControls(_:)), userInfo: nil, repeats: false)
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
        actionView.animate(hidden: false)
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
            firstX = zoomingScrollView.center.x
            firstY = zoomingScrollView.center.y
            setNeedsStatusBarAppearanceUpdate()
        }

        let translationY = sender.translation(in: view).y
        let dragDistance = abs(translationY)
        let progress = min(dragDistance / viewHalfHeight, 1.0)

        // Move image
        zoomingScrollView.center = CGPoint(x: firstX, y: firstY + translationY)

        // Scale — gentle ease-in curve, shrinks to 0.8 at max drag
        let scale = 1.0 - pow(progress, 1.4) * 0.2
        zoomingScrollView.transform = CGAffineTransform(scaleX: scale, y: scale)

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
            let isDismissing = zoomingScrollView.center.y > viewHalfHeight + dismissThreshold
                || zoomingScrollView.center.y < viewHalfHeight - dismissThreshold

            if isDismissing {
                // Check if displacement source exists
                let hasSourceView = delegate?.viewForPhoto?(self, index: currentPageIndex) != nil

                if hasSourceView {
                    // Displacement — capture current visual frame (scaled + offset),
                    // then hand off to animator which uses it as the starting position
                    let currentScale = zoomingScrollView.transform.a // uniform scale
                    let visualWidth = zoomingScrollView.bounds.width * currentScale
                    let visualHeight = zoomingScrollView.bounds.height * currentScale
                    let visualFrame = CGRect(
                        x: zoomingScrollView.center.x - visualWidth / 2,
                        y: zoomingScrollView.center.y - visualHeight / 2,
                        width: visualWidth,
                        height: visualHeight
                    )
                    animator.dismissStartFrame = visualFrame
                    zoomingScrollView.transform = .identity
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
                        options: .curveEaseOut
                    ) {
                        zoomingScrollView.center = exitTarget
                        zoomingScrollView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
                        self.view.backgroundColor = self.bgColor.withAlphaComponent(0)
                    } completion: { [weak self] _ in
                        self?.determineAndClose()
                    }
                }

            } else {
                // Cancelled — spring back softly
                UIView.animate(
                    withDuration: 0.5,
                    delay: 0,
                    usingSpringWithDamping: 0.78,
                    initialSpringVelocity: 0.2,
                    options: .curveEaseOut
                ) {
                    zoomingScrollView.center = CGPoint(x: self.firstX, y: viewHalfHeight)
                    zoomingScrollView.transform = .identity
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

    func configureActionView() {
        actionView = SKActionView(frame: view.frame, browser: self)
        view.addSubview(actionView)
    }

    func configurePaginationView() {
        paginationView = SKPaginationView(frame: view.frame, browser: self)
        view.addSubview(paginationView)
    }

    func configureToolbar() {
        toolbar = SKToolbar(frame: frameForToolbarAtOrientation(), browser: self)
        view.addSubview(toolbar)
    }

    func setControlsHidden(_ hidden: Bool, animated: Bool, permanent: Bool) {
        // timer update
        cancelControlHiding()

        // scroll animation
        pagingScrollView.setControlsHidden(hidden: hidden)

        // paging animation
        paginationView.setControlsHidden(hidden: hidden)

        // action view animation
        actionView.animate(hidden: hidden)

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
