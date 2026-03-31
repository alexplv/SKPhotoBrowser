//
//  SKPhotoBrowserOptions.swift
//  SKPhotoBrowser
//
//  Created by 鈴木 啓司 on 2016/08/18.
//  Copyright © 2016年 suzuki_keishi. All rights reserved.
//

import UIKit

public struct SKPhotoBrowserOptions {
    public static var displayStatusbar: Bool = false
    public static var displayCloseButton: Bool = true

    public static var displayCounterLabel: Bool = true

    public static var bounceAnimation: Bool = false
    public static var enableZoomBlackArea: Bool = true
    public static var enableSingleTapDismiss: Bool = false

    public static var backgroundColor: UIColor = .black
    public static var indicatorColor: UIColor = .white
    public static var indicatorStyle: UIActivityIndicatorView.Style = .whiteLarge

    public static var disableVerticalSwipe: Bool = false
}

public struct SKButtonOptions {
    public static var closeButtonPadding: CGPoint = CGPoint(x: 5, y: 20)
}
