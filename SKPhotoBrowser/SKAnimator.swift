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
    fileprivate var presentAnimator: UIViewPropertyAnimator?
    internal var finalImageViewFrame: CGRect = .zero

    internal lazy var backgroundView: UIView = {
        guard let window = UIApplication.shared.preferredApplicationWindow else { fatalError() }

        let backgroundView = UIView(frame: window.frame)
        backgroundView.backgroundColor = SKPhotoBrowserOptions.backgroundColor
        backgroundView.alpha = 0.0
        backgroundView.isUserInteractionEnabled = false
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

        senderViewOriginalFrame = calcOriginFrame(sender)
        finalImageViewFrame = calcFinalFrame(imageRatio)
        resizableImageView = UIImageView(image: imageFromView)

        if let resizableImageView = resizableImageView {
            resizableImageView.frame = senderViewOriginalFrame
            resizableImageView.clipsToBounds = true
            resizableImageView.layer.masksToBounds = true
            resizableImageView.contentMode = .scaleAspectFill

            let sourceRadius = sender.layer.cornerRadius
            resizableImageView.layer.cornerRadius = sourceRadius
            resizableImageView.layer.cornerCurve = .continuous
            window?.addSubview(resizableImageView)
        }

        presentAnimation(browser)
    }

    func willDismiss(_ browser: SKPhotoBrowser) {
        guard let sender = browser.delegate?.viewForPhoto?(browser, index: browser.currentPageIndex),
            let image = browser.photoAtIndex(browser.currentPageIndex).underlyingImage,
            let scrollView = browser.pageDisplayedAtIndex(browser.currentPageIndex) else {

            senderViewForAnimation?.isHidden = false
            // No source view — dismiss instantly, pan animation already handled the visual exit
            self.resizableImageView?.removeFromSuperview()
            self.backgroundView.removeFromSuperview()
            browser.dismissPhotoBrowser(animated: false)
            return
        }

        senderViewForAnimation = sender
        // Carry over the current visual background alpha from the drag state
        // so the handoff from browser.view to window-level backgroundView is seamless.
        let currentBgAlpha = browser.view.backgroundColor?.cgColor.alpha ?? 1.0
        browser.view.isHidden = true
        backgroundView.isHidden = false
        backgroundView.backgroundColor = SKPhotoBrowserOptions.backgroundColor
        backgroundView.alpha = currentBgAlpha
        senderViewOriginalFrame = calcOriginFrame(sender)

        if let resizableImageView = resizableImageView {
            let photo = browser.photoAtIndex(browser.currentPageIndex)

            // Capture the visual frame and current corner radius from the drag state.
            // The imageView's cornerRadius is in its local (unscaled) coordinate space.
            // Multiply by the imageView's scale transform to get the visual radius.
            let frame = scrollView.convert(scrollView.imageView.frame, to: nil)
            let imageScale = scrollView.imageView.transform.a * scrollView.transform.a
            let currentCornerRadius = scrollView.imageView.layer.cornerRadius * imageScale

            // Reset transform and corner radius now that we've captured the visual state
            scrollView.transform = .identity
            scrollView.imageView.layer.cornerRadius = 0

            resizableImageView.image = image.rotateImageByOrientation()
            resizableImageView.frame = frame
            resizableImageView.alpha = 1.0
            resizableImageView.clipsToBounds = true
            resizableImageView.contentMode = photo.contentMode
            if let view = senderViewForAnimation, view.layer.cornerRadius != 0 {
                let duration = (animationDuration * Double(animationDamping))
                resizableImageView.layer.masksToBounds = true
                resizableImageView.layer.cornerRadius = currentCornerRadius
                resizableImageView.addCornerRadiusAnimation(currentCornerRadius, to: view.layer.cornerRadius, duration: duration)
            }
        }
        dismissAnimation(browser)
    }

    func interruptPresent(in browser: SKPhotoBrowser) -> CGRect? {
        guard let animator = presentAnimator, animator.isRunning else { return nil }

        // Capture visual frame from presentation layer before stopping
        let currentFrame = resizableImageView?.layer.presentation()?.frame
            ?? resizableImageView?.frame ?? .zero

        // Stop animation (completion fires with .current, skips final setup)
        animator.stopAnimation(true)
        presentAnimator = nil

        // Visual swap: browser content takes over from window-level views
        browser.view.backgroundColor = SKPhotoBrowserOptions.backgroundColor
        browser.pagingScrollView.alpha = 1.0
        backgroundView.isHidden = true
        resizableImageView?.alpha = 0.0

        return currentFrame
    }
}

private extension SKAnimator {
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

private extension SKAnimator {
    func presentAnimation(_ browser: SKPhotoBrowser, completion: (() -> Void)? = nil) {
        let finalFrame = self.finalImageViewFrame
        let hasSourceView = resizableImageView != nil

        backgroundView.accessibilityIgnoresInvertColors = true
        resizableImageView?.accessibilityIgnoresInvertColors = true

        if hasSourceView {
            // Displacement animation — browser view stays interactive throughout.
            // Hide content via subview alpha so the view itself remains touchable
            // (UIView.hitTest returns nil when alpha < 0.01).
            browser.view.isHidden = false
            browser.view.backgroundColor = .clear
            for subview in browser.view.subviews {
                subview.alpha = 0.0
            }

            let presentAnim = UIViewPropertyAnimator(
                duration: animationDuration,
                dampingRatio: animationDamping
            ) {
                self.backgroundView.alpha = 1.0
                self.resizableImageView?.frame = finalFrame
                self.resizableImageView?.layer.cornerRadius = 0
            }
            presentAnim.addCompletion { [weak self] position in
                self?.presentAnimator = nil
                guard position == .end else { return }
                print("[SKPhotoBrowser] image stabilized after present animation")
                browser.view.backgroundColor = SKPhotoBrowserOptions.backgroundColor
                browser.pagingScrollView.alpha = 1.0
                self?.backgroundView.isHidden = true
                self?.resizableImageView?.alpha = 0.0
                browser.showButtons()
            }
            self.presentAnimator = presentAnim
            presentAnim.startAnimation()
        } else {
            // No source view — fade in browser directly, skip window-level backgroundView
            self.backgroundView.isHidden = true
            browser.view.isHidden = false
            browser.view.alpha = 0.0

            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                browser.view.alpha = 1.0
            } completion: { _ in
                print("[SKPhotoBrowser] image stabilized after present animation")
                browser.showButtons()
            }
        }
    }

    func dismissAnimation(_ browser: SKPhotoBrowser, completion: (() -> Void)? = nil) {
        let finalFrame = self.senderViewOriginalFrame

        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            usingSpringWithDamping: animationDamping,
            initialSpringVelocity: 0,
            options: UIView.AnimationOptions(),
            animations: {
                self.backgroundView.alpha = 0.0
                self.resizableImageView?.layer.frame = finalFrame
            },
            completion: { (_) -> Void in
                browser.dismissPhotoBrowser(animated: false) {
                    self.resizableImageView?.removeFromSuperview()
                    self.backgroundView.removeFromSuperview()
                }
            })
    }
}
