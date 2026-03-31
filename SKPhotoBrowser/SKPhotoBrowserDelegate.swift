//
//  SKPhotoBrowserDelegate.swift
//  SKPhotoBrowser
//
//  Created by 鈴木 啓司 on 2016/08/09.
//  Copyright © 2016年 suzuki_keishi. All rights reserved.
//

import UIKit

@objc public protocol SKPhotoBrowserDelegate {

    /**
     Tells the delegate that the browser started displaying a new photo

     - Parameter index: the index of the new photo
     */
    @objc optional func didShowPhotoAtIndex(_ browser: SKPhotoBrowser, index: Int)

    /**
     Tells the delegate the browser will start to dismiss

     - Parameter index: the index of the current photo
     */
    @objc optional func willDismissAtPageIndex(_ index: Int)

    /**
     Tells the delegate that the browser has been dismissed

     - Parameter index: the index of the current photo
     */
    @objc optional func didDismissAtPageIndex(_ index: Int)

    /**
     Tells the delegate that the browser did scroll to index

     - Parameter index: the index of the photo where the user had scroll
     */
    @objc optional func didScrollToIndex(_ browser: SKPhotoBrowser, index: Int)

    /**
     Asks the delegate for the view for a certain photo. Needed to determine the animation when presenting/closing the browser.

     - Parameter browser: reference to the calling SKPhotoBrowser
     - Parameter index: the index of the photo

     - Returns: the view to animate to
     */
    @objc optional func viewForPhoto(_ browser: SKPhotoBrowser, index: Int) -> UIView?

    /**
     Tells the delegate that the controls view toggled visibility

     - Parameter browser: reference to the calling SKPhotoBrowser
     - Parameter hidden: the status of visibility control
     */
    @objc optional func controlsVisibilityToggled(_ browser: SKPhotoBrowser, hidden: Bool)

    /**
     Asks the delegate for a custom caption view for a photo at a given index.

     - Parameter index: the index of the photo

     - Returns: a custom SKCaptionView, or nil to use the default
     */
    @objc optional func captionViewForPhotoAtIndex(index: Int) -> SKCaptionView?
}
