//
//  SKAnimator.swift
//  SKPhotoBrowser
//
//  Created by keishi suzuki on 2016/08/09.
//  Copyright © 2016 suzuki_keishi. All rights reserved.
//

import UIKit

@objc public protocol SKPhotoBrowserAnimatorDelegate {
    func willPresent(_ browser: SKPhotoBrowser)
    func willDismiss(_ browser: SKPhotoBrowser)
}

class SKAnimator: NSObject, SKPhotoBrowserAnimatorDelegate {
    fileprivate let window = UIApplication.shared.preferredApplicationWindow
    fileprivate var resizableImageView: UIImageView?
    fileprivate var finalImageViewFrame: CGRect = .zero

    internal lazy var backgroundView: UIView = {
        guard let window = UIApplication.shared.preferredApplicationWindow else { fatalError() }

        let backgroundView = UIView(frame: window.frame)
        backgroundView.backgroundColor = SKPhotoBrowserOptions.backgroundColor
        backgroundView.alpha = 0.0
        return backgroundView
    }()
    internal var senderOriginImage: UIImage!
    internal var senderViewOriginalFrame: CGRect = .zero
    internal var senderViewForAnimation: UIView?

    fileprivate var animationDuration: TimeInterval {
        if SKPhotoBrowserOptions.bounceAnimation { return 0.5 }
        return 0.35
    }
    fileprivate var animationDamping: CGFloat {
        if SKPhotoBrowserOptions.bounceAnimation { return 0.8 }
        return 1.0
    }

    fileprivate var sourceCornerRadius: CGFloat = 0

    override init() {
        super.init()
        window?.addSubview(backgroundView)
    }

    deinit {
        backgroundView.removeFromSuperview()
    }

    func willPresent(_ browser: SKPhotoBrowser) {
        guard let sender = browser.delegate?.viewForPhoto?(browser, index: browser.currentPageIndex) ?? senderViewForAnimation else {
            presentAnimation(browser)
            return
        }

        let photo = browser.photoAtIndex(browser.currentPageIndex)
        let imageFromView = (senderOriginImage ?? browser.getImageFromView(sender)).rotateImageByOrientation()
        let imageRatio = imageFromView.size.width / imageFromView.size.height

        let fullFrameInWindow = calcOriginFrame(sender)
        let visibleInWindow = visibleRect(of: sender)

        // If thumbnail is fully offscreen, fall back to fade
        guard !visibleInWindow.isEmpty else {
            presentAnimation(browser)
            return
        }

        finalImageViewFrame = calcFinalFrame(imageRatio)
        sourceCornerRadius = sender.layer.cornerRadius

        // Use visible rect as start position so the animation begins exactly
        // where the user sees the thumbnail. The full image + .scaleAspectFill
        // handles the zoom naturally — no manual cropping needed.
        let isPartiallyClipped = !visibleInWindow.contains(fullFrameInWindow)
        senderViewOriginalFrame = isPartiallyClipped ? visibleInWindow : fullFrameInWindow
        resizableImageView = UIImageView(image: imageFromView)

        if let resizableImageView = resizableImageView {
            resizableImageView.frame = senderViewOriginalFrame
            resizableImageView.clipsToBounds = true
            resizableImageView.contentMode = .scaleAspectFill

            if sourceCornerRadius != 0 {
                resizableImageView.layer.masksToBounds = true
                resizableImageView.layer.cornerRadius = sourceCornerRadius
            }

            window?.addSubview(resizableImageView)
        }

        presentAnimation(browser)
    }

    func willDismiss(_ browser: SKPhotoBrowser) {
        guard let sender = browser.delegate?.viewForPhoto?(browser, index: browser.currentPageIndex),
            let image = browser.photoAtIndex(browser.currentPageIndex).underlyingImage,
            let scrollView = browser.pageDisplayedAtIndex(browser.currentPageIndex) else {

            senderViewForAnimation?.isHidden = false
            self.resizableImageView?.removeFromSuperview()
            self.backgroundView.removeFromSuperview()
            browser.dismissPhotoBrowser(animated: false)
            return
        }

        senderViewForAnimation = sender
        browser.view.isHidden = true
        backgroundView.isHidden = false
        backgroundView.alpha = 1.0
        backgroundView.backgroundColor = .clear
        sourceCornerRadius = sender.layer.cornerRadius

        let targetFullFrame = calcOriginFrame(sender)
        let targetVisible = visibleRect(of: sender)

        // Use visible rect as the dismiss target so the frame animates
        // to where the thumbnail actually appears on screen
        let isTargetClipped = !targetVisible.isEmpty && !targetVisible.contains(targetFullFrame)
        senderViewOriginalFrame = isTargetClipped ? targetVisible : targetFullFrame

        if let resizableImageView = resizableImageView {
            let photo = browser.photoAtIndex(browser.currentPageIndex)
            let contentOffset = scrollView.contentOffset
            let scrollFrame = scrollView.imageView.frame
            let offsetY = scrollView.center.y - (scrollView.bounds.height/2)
            let frame = CGRect(
                x: scrollFrame.origin.x - contentOffset.x,
                y: scrollFrame.origin.y + contentOffset.y + offsetY - scrollView.contentOffset.y,
                width: scrollFrame.width,
                height: scrollFrame.height)

            resizableImageView.image = image.rotateImageByOrientation()
            resizableImageView.frame = frame
            resizableImageView.alpha = 1.0
            resizableImageView.clipsToBounds = true
            resizableImageView.contentMode = photo.contentMode
            resizableImageView.layer.cornerRadius = 0

            if let view = senderViewForAnimation, view.layer.cornerRadius != 0 {
                let duration = (animationDuration * Double(animationDamping))
                resizableImageView.layer.masksToBounds = true
                resizableImageView.addCornerRadiusAnimation(0, to: view.layer.cornerRadius, duration: duration)
            }
        }
        dismissAnimation(browser)
    }
}

// MARK: - Helpers

private extension SKAnimator {
    /// Returns the visible portion of the view in window coordinates,
    /// accounting for all clipping ancestors (scroll views, sheets, etc.).
    func visibleRect(of view: UIView) -> CGRect {
        guard let window = view.window else { return .zero }
        var rect = view.convert(view.bounds, to: window)
        var current: UIView? = view.superview
        while let ancestor = current {
            if ancestor.clipsToBounds || ancestor.layer.masksToBounds {
                let ancestorRect = ancestor.convert(ancestor.bounds, to: window)
                rect = rect.intersection(ancestorRect)
                if rect.isEmpty { return .zero }
            }
            current = ancestor.superview
        }
        return rect
    }

    func calcOriginFrame(_ sender: UIView) -> CGRect {
        if let senderViewOriginalFrameTemp = sender.superview?.convert(sender.frame, to: nil) {
            return senderViewOriginalFrameTemp
        } else if let senderViewOriginalFrameTemp = sender.layer.superlayer?.convert(sender.frame, to: nil) {
            return senderViewOriginalFrameTemp
        } else {
            return .zero
        }
    }

    func calcFinalFrame(_ imageRatio: CGFloat) -> CGRect {
        guard !imageRatio.isNaN else { return .zero }

        if SKMesurement.screenRatio < imageRatio {
            let width = SKMesurement.screenWidth
            let height = width / imageRatio
            let yOffset = (SKMesurement.screenHeight - height) / 2
            return CGRect(x: 0, y: yOffset, width: width, height: height)

        } else {
            let height = SKMesurement.screenHeight
            let width = height * imageRatio
            let xOffset = (SKMesurement.screenWidth - width) / 2
            return CGRect(x: xOffset, y: 0, width: width, height: height)
        }
    }
}

// MARK: - Animations

private extension SKAnimator {
    func presentAnimation(_ browser: SKPhotoBrowser, completion: (() -> Void)? = nil) {
        let finalFrame = self.finalImageViewFrame
        let hasSourceView = resizableImageView != nil

        backgroundView.accessibilityIgnoresInvertColors = true
        resizableImageView?.accessibilityIgnoresInvertColors = true

        if hasSourceView {
            browser.view.isHidden = true
            browser.view.alpha = 0.0

            UIView.animate(
                withDuration: animationDuration,
                delay: 0,
                usingSpringWithDamping: animationDamping,
                initialSpringVelocity: 0
            ) {
                self.backgroundView.alpha = 1.0
                self.resizableImageView?.frame = finalFrame
                self.resizableImageView?.layer.cornerRadius = 0
            } completion: { _ in
                browser.view.alpha = 1.0
                browser.view.isHidden = false
                self.backgroundView.isHidden = true
                self.resizableImageView?.alpha = 0.0
                browser.showButtons()
            }
        } else {
            self.backgroundView.isHidden = true
            browser.view.isHidden = false
            browser.view.alpha = 0.0

            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                browser.view.alpha = 1.0
            } completion: { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    browser.showButtons()
                }
            }
        }
    }

    func dismissAnimation(_ browser: SKPhotoBrowser, completion: (() -> Void)? = nil) {
        let finalFrame = self.senderViewOriginalFrame

        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            usingSpringWithDamping: animationDamping,
            initialSpringVelocity: 0
        ) {
            self.backgroundView.alpha = 0.0
            self.resizableImageView?.layer.frame = finalFrame
            self.resizableImageView?.layer.cornerRadius = self.sourceCornerRadius
        } completion: { _ in
            browser.dismissPhotoBrowser(animated: false) {
                self.resizableImageView?.removeFromSuperview()
                self.backgroundView.removeFromSuperview()
            }
        }
    }
}
