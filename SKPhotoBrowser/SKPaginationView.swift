//
//  SKPaginationView.swift
//  SKPhotoBrowser
//
//  Created by keishi_suzuki on 2017/12/20.
//  Copyright © 2017年 suzuki_keishi. All rights reserved.
//

import UIKit

class SKPaginationView: UIView {
    var counterLabel: UILabel?
    private var margin: CGFloat = 100
    private var extraMargin: CGFloat = SKMesurement.isPhoneX ? 40 : 0

    fileprivate weak var browser: SKPhotoBrowser?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    convenience init(frame: CGRect, browser: SKPhotoBrowser?) {
        self.init(frame: frame)
        self.frame = CGRect(x: 0, y: frame.height - margin - extraMargin, width: frame.width, height: 100)
        self.browser = browser

        setupApperance()
        setupCounterLabel()

        update(browser?.currentPageIndex ?? 0)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let view = super.hitTest(point, with: event) {
            if let counterLabel = counterLabel, counterLabel.frame.contains(point) {
                return view
            }
            return nil
        }
        return nil
    }

    func updateFrame(frame: CGRect) {
        self.frame = CGRect(x: 0, y: frame.height - margin, width: frame.width, height: 100)
    }

    func update(_ currentPageIndex: Int) {
        guard let browser = browser else { return }

        if browser.photos.count > 1 {
            counterLabel?.text = "\(currentPageIndex + 1) / \(browser.photos.count)"
        } else {
            counterLabel?.text = nil
        }
    }

    func setControlsHidden(hidden: Bool) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            self.alpha = hidden ? 0.0 : 1.0
        }
    }
}

private extension SKPaginationView {
    func setupApperance() {
        backgroundColor = .clear
        clipsToBounds = true
    }

    func setupCounterLabel() {
        guard SKPhotoBrowserOptions.displayCounterLabel else { return }

        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        label.center = CGPoint(x: frame.width / 2, y: frame.height / 2)
        label.textAlignment = .center
        label.backgroundColor = .clear
        label.shadowColor = SKToolbarOptions.textShadowColor
        label.shadowOffset = CGSize(width: 0.0, height: 1.0)
        label.font = SKToolbarOptions.font
        label.textColor = SKToolbarOptions.textColor
        label.translatesAutoresizingMaskIntoConstraints = true
        label.autoresizingMask = [.flexibleBottomMargin,
                                  .flexibleLeftMargin,
                                  .flexibleRightMargin,
                                  .flexibleTopMargin]
        addSubview(label)
        counterLabel = label
    }
}
