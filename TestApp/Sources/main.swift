import SKPhotoBrowser
import UIKit

// Just verify it compiles — exercise the public API surface
let photo = SKPhoto.photoWithImageURL("https://example.com/image.jpg")
print("SKPhoto created: index=\(photo.index)")

let browser = SKPhotoBrowser(photos: [photo], initialPageIndex: 0)
print("SKPhotoBrowser created: currentPage=\(browser.currentPageIndex)")

SKPhotoBrowserOptions.displayCloseButton = true
SKPhotoBrowserOptions.displayCounterLabel = false
SKPhotoBrowserOptions.displayAction = false
SKPhotoBrowserOptions.disableVerticalSwipe = false
print("Options configured")

print("BUILD OK ✓")
