//
//  SKButtons.swift
//  SKPhotoBrowser
//
//  Created by 鈴木 啓司 on 2016/08/09.
//  Copyright © 2016年 suzuki_keishi. All rights reserved.
//

import UIKit

// MARK: - Bar Button Item Factory

enum SKBarButtonItemFactory {
    static func closeBarButtonItem(target: Any, action: Selector) -> UIBarButtonItem {
        if #available(iOS 26.0, *) {
            let item = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { _ in
                _ = (target as AnyObject).perform(action)
            })
            return item
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
            let image = UIImage(systemName: "xmark", withConfiguration: config)
            let item = UIBarButtonItem(image: image, style: .plain, target: target, action: action)
            item.tintColor = .white
            return item
        }
    }
}
