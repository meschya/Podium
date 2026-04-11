//
//  HomeDriverCroppedPhotoView.swift
//  Podium
//

import SwiftUI
import UIKit

/// Кроп пилота для карточек на главной — без `.task` (иначе один кадр пустой и блок Leader «мигает»).
private enum HomeDriverCroppedPhotoCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(assetName: String, width: CGFloat, height: CGFloat) -> UIImage? {
        let key = "\(assetName)|\(Int(width * 10))|\(Int(height * 10))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let img = DriverCupBannerPhotoCrop.uiImageTopAspectFill(named: assetName, width: width, height: height)
        if let img { cache.setObject(img, forKey: key) }
        return img
    }
}

/// Кроп пилота для карточек на главной — UIImage из кэша или синхронно при первом показе.
struct HomeDriverCroppedPhotoView: View {
    let assetName: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let ui = HomeDriverCroppedPhotoCache.image(assetName: assetName, width: width, height: height) {
                Image(uiImage: ui)
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(width: width, height: height, alignment: .top)
            } else {
                Color.clear.frame(width: width, height: height)
            }
        }
    }
}
