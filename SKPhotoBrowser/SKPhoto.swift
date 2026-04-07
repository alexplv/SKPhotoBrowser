//
//  SKPhoto.swift
//  SKViewExample
//
//  Created by suzuki_keishi on 2015/10/01.
//  Copyright © 2015 suzuki_keishi. All rights reserved.
//

import UIKit

@objc public protocol SKPhotoProtocol: NSObjectProtocol {
    var index: Int { get set }
    var underlyingImage: UIImage! { get }
    var caption: String? { get }
    var contentMode: UIView.ContentMode { get set }
    /// Whether the full-resolution image requires a remote fetch.
    /// Return `false` when the image is already cached or available locally
    /// so the browser skips the loading indicator entirely.
    @objc optional var needsRemoteLoad: Bool { get }
    func loadUnderlyingImageAndNotify()
    func checkCache()
}

// MARK: - SKPhoto
open class SKPhoto: NSObject, SKPhotoProtocol {
    /// Set this to let `needsRemoteLoad` check a third-party image cache
    /// (e.g. Kingfisher, SDWebImage). Return `true` if the URL is cached.
    /// Usage: `SKPhoto.imageCacheCheck = { ImageCache.default.isCached(forKey: $0) }`
    public static var imageCacheCheck: ((String) -> Bool)?

    open var index: Int = 0
    open var underlyingImage: UIImage!
    open var caption: String?
    open var contentMode: UIView.ContentMode = .scaleAspectFill
    open var needsRemoteLoad: Bool {
        guard let url = photoURL else { return false }
        if underlyingImage != nil { return false }
        if let check = SKPhoto.imageCacheCheck, check(url) { return false }
        return true
    }
    open var photoURL: String!

    override init() {
        super.init()
    }

    convenience init(image: UIImage) {
        self.init()
        underlyingImage = image
    }

    convenience init(url: String) {
        self.init()
        photoURL = url
    }

    convenience init(url: String, holder: UIImage?) {
        self.init()
        photoURL = url
        underlyingImage = holder
    }

    open func checkCache() {
        // no-op: caching removed
    }

    open func loadUnderlyingImageAndNotify() {
        guard photoURL != nil, let url = URL(string: photoURL) else { return }

        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            defer { session.finishTasksAndInvalidate() }

            guard error == nil, let data = data else {
                DispatchQueue.main.async { self.loadUnderlyingImageComplete() }
                return
            }

            let image = UIImage(data: data)
            DispatchQueue.main.async {
                self.underlyingImage = image
                self.loadUnderlyingImageComplete()
            }
        }
        task.resume()
    }

    open func loadUnderlyingImageComplete() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: SKPHOTO_LOADING_DID_END_NOTIFICATION), object: self)
    }
}

// MARK: - Static Function

extension SKPhoto {
    public static func photoWithImage(_ image: UIImage) -> SKPhoto {
        return SKPhoto(image: image)
    }

    public static func photoWithImageURL(_ url: String) -> SKPhoto {
        return SKPhoto(url: url)
    }

    public static func photoWithImageURL(_ url: String, holder: UIImage?) -> SKPhoto {
        return SKPhoto(url: url, holder: holder)
    }
}
