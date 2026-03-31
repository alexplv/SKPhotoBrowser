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
    public static var displayAction: Bool = true
    public static var displayBackAndForwardButton: Bool = true
    public static var displayHorizontalScrollIndicator: Bool = true
    public static var displayVerticalScrollIndicator: Bool = true
    public static var displayPagingHorizontalScrollIndicator: Bool = true

    public static var displayCounterLabel: Bool = true

    public static var bounceAnimation: Bool = false
    public static var enableZoomBlackArea: Bool = true
    public static var enableSingleTapDismiss: Bool = false

    public static var backgroundColor: UIColor = .black
    public static var indicatorColor: UIColor = .white
    public static var indicatorStyle: UIActivityIndicatorView.Style = .whiteLarge

    public static var disableVerticalSwipe: Bool = false
    public static var longPhotoWidthMatchScreen: Bool = false
    public static var protectScreenshot: Bool = false
}

public struct SKButtonOptions {
    public static var closeButtonPadding: CGPoint = CGPoint(x: 5, y: 20)
}

public struct SKCaptionOptions {
    public enum CaptionLocation {
        case basic
        case bottom
    }
    public static var textColor: UIColor = .white
    public static var textAlignment: NSTextAlignment = .center
    public static var numberOfLine: Int = 3
    public static var lineBreakMode: NSLineBreakMode = .byTruncatingTail
    public static var font: UIFont = .systemFont(ofSize: 17.0)
    public static var backgroundColor: UIColor = .clear
    public static var captionLocation: CaptionLocation = .basic
}

public struct SKToolbarOptions {
    public static var textColor: UIColor = .white
    public static var font: UIFont = .systemFont(ofSize: 17.0)
    public static var textShadowColor: UIColor = .black
}
