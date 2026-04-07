//
//  SKButtons.swift
//  SKPhotoBrowser
//
//  Created by 鈴木 啓司 on 2016/08/09.
//  Copyright © 2016年 suzuki_keishi. All rights reserved.
//

import UIKit

// MARK: - Close Button

class SKCloseButton: UIButton {
    init(action: Selector, target: Any) {
        super.init(frame: .zero)
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .ultraLight)
            .applying(UIImage.SymbolConfiguration(paletteColors: [.white, .white.withAlphaComponent(0.15)]))
        let image = UIImage(systemName: "xmark.circle.fill", withConfiguration: config)
        setImage(image, for: .normal)
        imageView?.contentMode = .scaleAspectFit
        contentHorizontalAlignment = .center
        contentVerticalAlignment = .center
        addTarget(target, action: action, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Bar Button Item Factory

enum SKBarButtonItemFactory {
    static func closeBarButtonItem(target: Any, action: Selector) -> UIBarButtonItem {
        if #available(iOS 26.0, *) {
            weak var weakTarget = target as AnyObject
            let item = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { _ in
                _ = weakTarget?.perform(action)
            })
            return item
        } else {
            let button = SKCloseButton(action: action, target: target)
            return UIBarButtonItem(customView: button)
        }
    }
}
