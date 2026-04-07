//
//  SKIndicatorView.swift
//  SKPhotoBrowser
//
//  Created by suzuki_keishi on 2015/10/09.
//  Copyright © 2015 suzuki_keishi. All rights reserved.
//

import UIKit

/// Delays an action by a grace period. If cancelled before the delay
/// elapses, the action never fires. Avoids brief flashes of UI elements
/// that appear and disappear too quickly (e.g. activity spinners).
class DelayedShow {
    private let delay: TimeInterval
    private var pending = false

    init(_ delay: TimeInterval) {
        self.delay = delay
    }

    func schedule(action: @escaping () -> Void) {
        pending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.pending else { return }
            self.pending = false
            action()
        }
    }

    func cancel() {
        pending = false
    }
}

class SKIndicatorView: UIActivityIndicatorView {
    private let delayedShow = DelayedShow(0.5)

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        center = CGPoint(x: frame.width / 2, y: frame.height / 2)
        style = SKPhotoBrowserOptions.indicatorStyle
        color = SKPhotoBrowserOptions.indicatorColor
    }

    override func startAnimating() {
        delayedShow.schedule { [weak self] in
            self?.performSuperStartAnimating()
        }
    }

    override func stopAnimating() {
        delayedShow.cancel()
        if isAnimating {
            performSuperStopAnimating()
        }
    }

    private func performSuperStartAnimating() {
        super.startAnimating()
    }

    private func performSuperStopAnimating() {
        super.stopAnimating()
    }
}
