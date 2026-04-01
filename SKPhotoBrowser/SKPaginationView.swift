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
    private var capsuleContainer: UIView?
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
            if let capsule = capsuleContainer {
                if capsule.frame.contains(point) { return view }
            } else if let counterLabel = counterLabel, counterLabel.frame.contains(point) {
                return view
            }
            return nil
        }
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let capsule = capsuleContainer {
            capsule.layer.cornerRadius = capsule.bounds.height / 2
            capsule.layer.cornerCurve = .continuous
            capsule.clipsToBounds = true
        }
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

        if #available(iOS 18, *) {
            setupGlassCounterLabel()
        } else {
            setupLegacyCounterLabel()
        }
    }

    func setupLegacyCounterLabel() {
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

    @available(iOS 18, *)
    func setupGlassCounterLabel() {
        let effect: UIVisualEffect
        if #available(iOS 26, *) {
            effect = UIGlassEffect()
        } else {
            effect = UIBlurEffect(style: .systemChromeMaterialDark)
        }

        let capsule = UIView()
        capsule.translatesAutoresizingMaskIntoConstraints = false
        addSubview(capsule)

        let effectView = UIVisualEffectView(effect: effect)
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.isUserInteractionEnabled = false
        capsule.addSubview(effectView)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = SKToolbarOptions.font
        label.textColor = .white
        effectView.contentView.addSubview(label)

        NSLayoutConstraint.activate([
            capsule.centerXAnchor.constraint(equalTo: centerXAnchor),
            capsule.centerYAnchor.constraint(equalTo: centerYAnchor),

            effectView.topAnchor.constraint(equalTo: capsule.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: capsule.bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: capsule.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: capsule.trailingAnchor),

            label.topAnchor.constraint(equalTo: effectView.contentView.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -16),
        ])

        capsuleContainer = capsule
        counterLabel = label
    }
}
