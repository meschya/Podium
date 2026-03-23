//
//  WidgetBundledImage.swift
//  PodiumWidget
//
//  Только через UIImage. Не использовать `Image(_:)` по строке без UIImage — в виджете это даёт «перечёркнутый круг».
//

import SwiftUI
import UIKit

private final class PodiumWidgetBundleToken {}

enum WidgetBundledImage {
    static func image(named name: String) -> Image {
        let bundles: [Bundle] = [Bundle.main, Bundle(for: PodiumWidgetBundleToken.self)]
        for bundle in bundles {
            if let ui = UIImage(named: name, in: bundle, compatibleWith: nil)?
                .withRenderingMode(.alwaysOriginal) {
                return Image(uiImage: ui)
            }
        }
        return Image(uiImage: WidgetBundledImage.transparent1px())
    }

    /// Кроп верхней части фото гонщика (`widget_max_face_lockscreen`) — в слоте 52×40 полный рост выглядел как «силуэт машины».
    /// Грузим только из бандла расширения, затем main — не смешивать с `*_bolid`.
    static func maxVerstappenPortrait() -> Image {
        let name = "widget_max_face_lockscreen"
        for bundle in [Bundle(for: PodiumWidgetBundleToken.self), Bundle.main] {
            if let ui = UIImage(named: name, in: bundle, compatibleWith: nil)?
                .withRenderingMode(.alwaysOriginal) {
                return Image(uiImage: ui)
            }
        }
        return Image(uiImage: WidgetBundledImage.transparent1px())
    }

    private static func transparent1px() -> UIImage {
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContext(size)
        UIColor.clear.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return img
    }
}
