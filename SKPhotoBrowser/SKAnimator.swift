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

        senderViewOriginalFrame = fullFrameInWindow
        finalImageViewFrame = calcFinalFrame(imageRatio)
        resizableImageView = UIImageView(image: imageFromView)

        if let resizableImageView = resizableImageView {
            resizableImageView.frame = senderViewOriginalFrame
            resizableImageView.clipsToBounds = true
            resizableImageView.contentMode = photo.contentMode

            // Mask to visible portion if partially clipped
            let isPartiallyClipped = !visibleInWindow.contains(fullFrameInWindow)
            if isPartiallyClipped {
                let maskRect = CGRect(
                    x: visibleInWindow.minX - fullFrameInWindow.minX,
                    y: visibleInWindow.minY - fullFrameInWindow.minY,
                    width: visibleInWindow.width,
                    height: visibleInWindow.height
                )
                let maskLayer = CAShapeLayer()
                maskLayer.path = UIBezierPath(rect: maskRect).cgPath
                resizableImageView.layer.mask = maskLayer

                // Animate mask to full bounds
                let fullPath = UIBezierPath(rect: CGRect(origin: .zero, size: finalImageViewFrame.size)).cgPath
                let maskAnimation = CABasicAnimation(keyPath: "path")
                maskAnimation.fromValue = maskLayer.path
                maskAnimation.toValue = fullPath
                maskAnimation.duration = animationDuration
                maskAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                maskLayer.path = fullPath
                maskLayer.add(maskAnimation, forKey: "maskExpand")
            }

            if sender.layer.cornerRadius != 0 {
                let duration = (animationDuration * Double(animationDamping))
                resizableImageView.layer.masksToBounds = true
                resizableImageView.addCornerRadiusAnimation(sender.layer.cornerRadius, to: 0, duration: duration)
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
            // No source view — dismiss instantly, pan animation already handled the visual exit
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
        senderViewOriginalFrame = calcOriginFrame(sender)
        
        // Calculate visible rect of target thumbnail for masking
        let targetFullFrame = senderViewOriginalFrame
        let targetVisible = visibleRect(of: sender)

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

            // Animate mask from full to visible portion if target is partially clipped
            let isTargetClipped = !targetVisible.isEmpty && !targetVisible.contains(targetFullFrame)
            if isTargetClipped {
                let fullPath = UIBezierPath(rect: CGRect(origin: .zero, size: frame.size)).cgPath
                let clippedRect = CGRect(
                    x: targetVisible.minX - targetFullFrame.minX,
                    y: targetVisible.minY - targetFullFrame.minY,
                    width: targetVisible.width,
                    height: targetVisible.height
                )
                let clippedPath = UIBezierPath(rect: clippedRect).cgPath

                let maskLayer = CAShapeLayer()
                maskLayer.path = fullPath
                resizableImageView.layer.mask = maskLayer

                let maskAnimation = CABasicAnimation(keyPath: "path")
                maskAnimation.fromValue = fullPath
                maskAnimation.toValue = clippedPath
                maskAnimation.duration = animationDuration
                maskAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                maskLayer.path = clippedPath
                maskLayer.add(maskAnimation, forKey: "maskShrink")
            }

            if let view = senderViewForAnimation, view.layer.cornerRadius != 0 {
                let duration = (animationDuration * Double(animationDamping))
                resizableImageView.layer.masksToBounds = true
                resizableImageView.addCornerRadiusAnimation(0, to: view.layer.cornerRadius, duration: duration)
            }
        }
        dismissAnimation(browser)
    }
}

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

private extension SKAnimator {
    func presentAnimation(_ browser: SKPhotoBrowser, completion: (() -> Void)? = nil) {
        let finalFrame = self.finalImageViewFrame
        let hasSourceView = resizableImageView != nil

        backgroundView.accessibilityIgnoresInvertColors = true
        resizableImageView?.accessibilityIgnoresInvertColors = true

        if hasSourceView {
            // Displacement animation — browser hidden until source image reaches final position
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
            } completion: { _ in
                browser.view.alpha = 1.0
                browser.view.isHidden = false
                self.backgroundView.isHidden = true
                self.resizableImageView?.alpha = 0.0
                browser.showButtons()
            }
        } else {
            // No source view — fade in browser directly, skip window-level backgroundView
            self.backgroundView.isHidden = true
            browser.view.isHidden = false
            browser.view.alpha = 0.0

            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                browser.view.alpha = 1.0
            } completion: { _ in
                // Delay controls slightly so the gallery content settles first
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

