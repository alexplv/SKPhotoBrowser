//
//  SKPagingScrollView.swift
//  SKPhotoBrowser
//
//  Created by 鈴木 啓司 on 2016/08/18.
//  Copyright © 2016年 suzuki_keishi. All rights reserved.
//

import UIKit

class SKPagingScrollView: UIScrollView {
    fileprivate let pageIndexTagOffset: Int = 1000
    fileprivate let sideMargin: CGFloat = 10
    fileprivate var visiblePages: [SKZoomingScrollView] = []
    fileprivate var recycledPages: [SKZoomingScrollView] = []
    fileprivate weak var browser: SKPhotoBrowser?

    var numberOfPhotos: Int {
        return browser?.photos.count ?? 0
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    convenience init(frame: CGRect, browser: SKPhotoBrowser) {
        self.init(frame: frame)
        self.browser = browser

        isPagingEnabled = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false

        updateFrame(bounds, currentPageIndex: browser.currentPageIndex)
    }

    func reload() {
        visiblePages.forEach({$0.removeFromSuperview()})
        visiblePages.removeAll()
        recycledPages.removeAll()
    }

    func loadAdjacentPhotosIfNecessary(_ photo: SKPhotoProtocol, currentPageIndex: Int) {
        guard let browser = browser, let page = pageDisplayingAtPhoto(photo) else {
            return
        }
        let pageIndex = (page.tag - pageIndexTagOffset)
        if currentPageIndex == pageIndex {
            // Previous
            if pageIndex > 0 {
                let previousPhoto = browser.photos[pageIndex - 1]
                if previousPhoto.underlyingImage == nil {
                    previousPhoto.loadUnderlyingImageAndNotify()
                }
            }
            // Next
            if pageIndex < numberOfPhotos - 1 {
                let nextPhoto = browser.photos[pageIndex + 1]
                if nextPhoto.underlyingImage == nil {
                    nextPhoto.loadUnderlyingImageAndNotify()
                }
            }
        }
    }

    func jumpToPageAtIndex(_ frame: CGRect) {
        let point = CGPoint(x: frame.origin.x - sideMargin, y: 0)
        setContentOffset(point, animated: true)
    }

    func updateFrame(_ bounds: CGRect, currentPageIndex: Int) {
        var frame = bounds
        frame.origin.x -= sideMargin
        frame.size.width += (2 * sideMargin)

        self.frame = frame

        if visiblePages.count > 0 {
            for page in visiblePages {
                let pageIndex = page.tag - pageIndexTagOffset
                page.frame = frameForPageAtIndex(pageIndex)
                page.setMaxMinZoomScalesForCurrentBounds()
            }
        }

        updateContentSize()
        updateContentOffset(currentPageIndex)
    }

    func updateContentSize() {
        contentSize = CGSize(width: bounds.size.width * CGFloat(numberOfPhotos), height: bounds.size.height)
    }

    func updateContentOffset(_ index: Int) {
        let pageWidth = bounds.size.width
        let newOffset = CGFloat(index) * pageWidth
        contentOffset = CGPoint(x: newOffset, y: 0)
    }

    func tilePages() {
        guard let browser = browser else { return }

        let firstIndex: Int = getFirstIndex()
        let lastIndex: Int = getLastIndex()

        visiblePages
            .filter({ $0.tag - pageIndexTagOffset < firstIndex || $0.tag - pageIndexTagOffset > lastIndex })
            .forEach { page in
                recycledPages.append(page)
                page.prepareForReuse()
                page.removeFromSuperview()
            }

        let visibleSet: Set<SKZoomingScrollView> = Set(visiblePages)
        let visibleSetWithoutRecycled: Set<SKZoomingScrollView> = visibleSet.subtracting(recycledPages)
        visiblePages = Array(visibleSetWithoutRecycled)

        while recycledPages.count > 2 {
            recycledPages.removeFirst()
        }

        for index: Int in firstIndex...lastIndex {
            if visiblePages.filter({ $0.tag - pageIndexTagOffset == index }).count > 0 {
                continue
            }

            let page: SKZoomingScrollView = SKZoomingScrollView(frame: frame, browser: browser)
            page.frame = frameForPageAtIndex(index)
            page.tag = index + pageIndexTagOffset
            let photo = browser.photos[index]
            page.photo = photo
            if let thumbnail = browser.animator.senderOriginImage,
                index == browser.initPageIndex,
                photo.underlyingImage == nil {
                page.displayImage(thumbnail)
            }

            visiblePages.append(page)
            addSubview(page)
        }
    }

    func pageDisplayedAtIndex(_ index: Int) -> SKZoomingScrollView? {
        for page in visiblePages where page.tag - pageIndexTagOffset == index {
            return page
        }
        return nil
    }

    func pageDisplayingAtPhoto(_ photo: SKPhotoProtocol) -> SKZoomingScrollView? {
        for page in visiblePages where page.photo === photo {
            return page
        }
        return nil
    }

    func setControlsHidden(hidden: Bool) {
        // no caption views to animate
    }
}

private extension SKPagingScrollView {
    func frameForPageAtIndex(_ index: Int) -> CGRect {
        var pageFrame = bounds
        pageFrame.size.width -= (2 * sideMargin)
        pageFrame.origin.x = (bounds.size.width * CGFloat(index)) + sideMargin
        return pageFrame
    }

    func getFirstIndex() -> Int {
        let firstIndex = Int(floor((bounds.minX + sideMargin * 2) / bounds.width))
        if firstIndex < 0 {
            return 0
        }
        if firstIndex > numberOfPhotos - 1 {
            return numberOfPhotos - 1
        }
        return firstIndex
    }

    func getLastIndex() -> Int {
        let lastIndex = Int(floor((bounds.maxX - sideMargin * 2 - 1) / bounds.width))
        if lastIndex < 0 {
            return 0
        }
        if lastIndex > numberOfPhotos - 1 {
            return numberOfPhotos - 1
        }
        return lastIndex
    }
}
