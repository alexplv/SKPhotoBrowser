//
//  SKButtons.swift
//  SKPhotoBrowser
//
//  Created by 鈴木 啓司 on 2016/08/09.
//  Copyright © 2016年 suzuki_keishi. All rights reserved.
//

import UIKit

class SKButton: UIButton {
    internal var showFrame: CGRect!
    internal var hideFrame: CGRect!

    fileprivate let size: CGSize = CGSize(width: 44, height: 44)
    fileprivate var marginX: CGFloat = 0
    fileprivate var marginY: CGFloat = 0
    fileprivate var extraMarginY: CGFloat = 20

    func setFrameSize(_ size: CGSize? = nil) {
        guard let size = size else { return }

        let newRect = CGRect(x: marginX, y: marginY, width: size.width, height: size.height)
        frame = newRect
        showFrame = newRect
        hideFrame = CGRect(x: marginX, y: -marginY, width: size.width, height: size.height)
    }

    func updateFrame(_ frameSize: CGSize) { }
}

class SKCloseButton: SKButton {
    private var backgroundEffectView: UIVisualEffectView?

    override var marginX: CGFloat {
        get { return SKButtonOptions.closeButtonPadding.x }
        set { super.marginX = newValue }
    }
    override var marginY: CGFloat {
        get { return SKButtonOptions.closeButtonPadding.y + extraMarginY }
        set { super.marginY = newValue }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin]

        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        setImage(UIImage(systemName: "xmark.circle.fill")?.withConfiguration(config), for: .normal)
        tintColor = .white

        showFrame = CGRect(x: marginX, y: marginY, width: size.width, height: size.height)
        hideFrame = CGRect(x: marginX, y: -marginY, width: size.width, height: size.height)
        self.frame = showFrame

        setupBackground()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundEffectView?.frame = bounds
        backgroundEffectView?.layer.cornerRadius = bounds.width / 2
    }

    private func setupBackground() {
        let effect: UIVisualEffect
        if #available(iOS 26, *) {
            effect = UIGlassEffect()
        } else if #available(iOS 18, *) {
            effect = UIBlurEffect(style: .systemChromeMaterialDark)
        } else {
            return
        }

        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        setImage(UIImage(systemName: "xmark")?.withConfiguration(config), for: .normal)

        let ev = UIVisualEffectView(effect: effect)
        ev.isUserInteractionEnabled = false
        ev.clipsToBounds = true
        ev.layer.cornerCurve = .continuous
        insertSubview(ev, at: 0)
        backgroundEffectView = ev
    }
}
