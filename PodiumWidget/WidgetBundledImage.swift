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
    /// Рендер в @3x (или фактический scale экрана), иначе при `format.scale = image.scale` (@2x) картинка слишком «редкая» по пикселям и выглядит размытой на iPhone.
    private static var rasterScale: CGFloat {
        max(UIScreen.main.scale, 2.0)
    }

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

    /// Aspect-fill + **верх** исходного PNG = верх слота.
    ///
    /// Важно: `widget_max_face_lockscreen` (440×400) — часто **лицо по центру кадра**; при узком слоте top-crop даёт **грудь/плечи** («туловище»).
    /// Полноформатный портрет `driver_widget_max_portrait` (440×1265) — **голова у верхнего края**, top-fill показывает лицо.
    static func maxVerstappenPortraitTopAlignedFill(width: CGFloat, height: CGFloat) -> Image {
        let preferredNames = [
            "driver_widget_max_portrait",
            "widget_max_driver_photo",
            "widget_max_face_lockscreen",
        ]
        var source: UIImage?
        outer: for name in preferredNames {
            for bundle in [Bundle(for: PodiumWidgetBundleToken.self), Bundle.main] {
                if let ui = UIImage(named: name, in: bundle, compatibleWith: nil) {
                    source = ui
                    break outer
                }
            }
        }
        guard let raw = source else { return Image(uiImage: transparent1px()) }
        let img = normalizedUp(raw)
        let w = max(width, 1)
        let h = max(height, 1)
        let cropped = Self.aspectFillTopCenterAligned(img, targetSize: CGSize(width: w, height: h))
        return Image(uiImage: cropped.withRenderingMode(.alwaysOriginal))
    }

    /// Generic top-aligned aspect-fill portrait from widget/app bundle asset name.
    static func portraitTopAlignedFill(assetName: String, width: CGFloat, height: CGFloat) -> Image {
        var source: UIImage?
        for bundle in [Bundle(for: PodiumWidgetBundleToken.self), Bundle.main] {
            if let ui = UIImage(named: assetName, in: bundle, compatibleWith: nil) {
                source = ui
                break
            }
        }
        guard let raw = source else { return Image(uiImage: transparent1px()) }
        let img = normalizedUp(raw)
        let w = max(width, 1)
        let h = max(height, 1)
        let cropped = Self.aspectFillTopCenterAligned(img, targetSize: CGSize(width: w, height: h))
        return Image(uiImage: cropped.withRenderingMode(.alwaysOriginal))
    }

    /// Рисуем «как в Preview»: ориентация `.up`, без сюрпризов с `imageOrientation` при кропе.
    private static func normalizedUp(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = Self.rasterScale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// Uniform scale = max(w/iw, h/ih); якорь по **верху** (y=0), по горизонтали по центру.
    private static func aspectFillTopCenterAligned(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let iw = image.size.width
        let ih = image.size.height
        guard iw > 0, ih > 0, targetSize.width > 0, targetSize.height > 0 else { return image }

        let s = max(targetSize.width / iw, targetSize.height / ih)
        let dw = iw * s
        let dh = ih * s
        let x = (targetSize.width - dw) / 2
        let y: CGFloat = 0

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = Self.rasterScale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { ctx in
            ctx.cgContext.interpolationQuality = .high
            ctx.cgContext.setAllowsAntialiasing(true)
            ctx.cgContext.clip(to: CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(x: x, y: y, width: dw, height: dh))
        }
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
