import CoreImage
import UIKit

/// Traitements d'image : réglages, filtres, esquisses, recadrage, rotation.
enum ImageProcessor {
    static let context = CIContext(options: [.cacheIntermediates: false])

    // MARK: - Rendu des réglages et filtres

    static func render(_ item: ImageItem) -> UIImage {
        guard let input = CIImage(image: item.original) else { return item.original }
        let extent = input.extent

        let adjusted = applyAdjustments(item.adjustments, to: input, extent: extent)
        var result = apply(item.filter, to: adjusted, extent: extent, detail: item.sketchDetail)

        if item.filter != .none && item.filterIntensity < 1 {
            result = result.applyingFilter("CIDissolveTransition", parameters: [
                kCIInputImageKey: adjusted,
                kCIInputTargetImageKey: result,
                kCIInputTimeKey: item.filterIntensity
            ])
        }

        result = result.cropped(to: extent)
        guard let cgImage = context.createCGImage(result, from: extent) else { return item.original }
        return UIImage(cgImage: cgImage, scale: item.original.scale, orientation: .up)
    }

    private static func applyAdjustments(_ a: Adjustments, to image: CIImage, extent: CGRect) -> CIImage {
        guard !a.isNeutral else { return image }
        var image = image.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: a.brightness,
            kCIInputContrastKey: a.contrast,
            kCIInputSaturationKey: a.saturation
        ])
        if a.exposure != 0 {
            image = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: a.exposure])
        }
        if a.temperature != 0 {
            image = image.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500 + a.temperature * 3000, y: 0),
                "inputTargetNeutral": CIVector(x: 6500, y: 0)
            ])
        }
        if a.sharpness > 0 {
            image = image.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: a.sharpness])
        }
        if a.vignette > 0 {
            image = image.applyingFilter("CIVignette", parameters: [
                kCIInputIntensityKey: a.vignette,
                kCIInputRadiusKey: 1.5
            ])
        }
        return image.cropped(to: extent)
    }

    private static func apply(_ filter: PhotoFilter, to image: CIImage, extent: CGRect, detail: Double) -> CIImage {
        switch filter {
        case .none:
            return image
        case .noir:
            return image.applyingFilter("CIPhotoEffectNoir")
        case .mono:
            return image.applyingFilter("CIPhotoEffectMono")
        case .sepia:
            return image.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.9])
        case .vintage:
            return image.applyingFilter("CIPhotoEffectTransfer")
        case .chrome:
            return image.applyingFilter("CIPhotoEffectChrome")
        case .fade:
            return image.applyingFilter("CIPhotoEffectFade")
        case .instant:
            return image.applyingFilter("CIPhotoEffectInstant")
        case .posterize:
            return image
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.4])
                .applyingFilter("CIColorPosterize", parameters: ["inputLevels": 6])
        case .blur:
            let radius = max(extent.width, extent.height) / 120
            return image.clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
                .cropped(to: extent)
        case .pencil:
            return keepAlpha(of: image, on: pencilSketch(image, extent: extent, detail: detail, contrast: 1.1, darkness: 1.2))
        case .coloredPencil:
            let sketch = pencilSketch(image, extent: extent, detail: detail, contrast: 1.0, darkness: 1.0)
            let colors = image.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.3,
                kCIInputBrightnessKey: 0.08
            ])
            return keepAlpha(of: image, on: sketch.applyingFilter("CIMultiplyBlendMode", parameters: [
                kCIInputBackgroundImageKey: colors
            ]))
        case .charcoal:
            return keepAlpha(of: image, on: pencilSketch(image, extent: extent, detail: min(1, detail + 0.35), contrast: 1.5, darkness: 2.4))
        case .outline:
            let lines = image.applyingFilter("CILineOverlay", parameters: [
                "inputEdgeIntensity": 0.5 + detail * 2,
                "inputThreshold": 0.1,
                "inputContrast": 50
            ])
            let paper = CIImage(color: .white).cropped(to: extent)
            return keepAlpha(of: image, on: lines.composited(over: paper))
        case .comic:
            return keepAlpha(of: image, on: image.applyingFilter("CIComicEffect"))
        }
    }

    /// Effet « dessin au crayon » : niveaux de gris + densité couleur sur l'inverse flouté.
    private static func pencilSketch(_ image: CIImage, extent: CGRect, detail: Double, contrast: Double, darkness: Double) -> CIImage {
        let gray = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0,
            kCIInputContrastKey: contrast
        ])
        let inverted = gray.applyingFilter("CIColorInvert")
        let divisor = 220 - detail * 170
        let radius = max(extent.width, extent.height) / divisor
        let blurred = inverted.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: extent)
        let sketch = blurred.applyingFilter("CIColorDodgeBlendMode", parameters: [
            kCIInputBackgroundImageKey: gray
        ])
        return sketch
            .applyingFilter("CIGammaAdjust", parameters: ["inputPower": darkness])
            .cropped(to: extent)
    }

    /// Garde la transparence de l'image source (utile après un détourage).
    private static func keepAlpha(of source: CIImage, on image: CIImage) -> CIImage {
        image.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: source
        ])
    }

    // MARK: - Géométrie

    /// Redessine l'image orientée vers le haut, à l'échelle 1, et limite sa taille.
    static func resized(_ image: UIImage, maxDimension: CGFloat = 2048) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let factor = min(1, maxDimension / max(pixelSize.width, pixelSize.height))
        let target = CGSize(width: (pixelSize.width * factor).rounded(), height: (pixelSize.height * factor).rounded())
        return draw(size: target) { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    static func solidImage(color: UIColor, size: CGSize) -> UIImage {
        draw(size: size) { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func rotated(_ image: UIImage, clockwise: Bool) -> UIImage {
        let size = CGSize(width: image.size.height, height: image.size.width)
        return draw(size: size) { context in
            let cg = context.cgContext
            cg.translateBy(x: size.width / 2, y: size.height / 2)
            cg.rotate(by: clockwise ? .pi / 2 : -.pi / 2)
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2,
                                  width: image.size.width, height: image.size.height))
        }
    }

    static func flippedHorizontally(_ image: UIImage) -> UIImage {
        draw(size: image.size) { context in
            let cg = context.cgContext
            cg.translateBy(x: image.size.width, y: 0)
            cg.scaleBy(x: -1, y: 1)
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// Recadre selon un rectangle normalisé (0…1).
    static func cropped(_ image: UIImage, normalizedRect r: CGRect) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let rect = CGRect(x: r.minX * width, y: r.minY * height, width: r.width * width, height: r.height * height)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !rect.isEmpty, let output = cgImage.cropping(to: rect) else { return image }
        return UIImage(cgImage: output, scale: image.scale, orientation: .up)
    }

    /// Aplatit l'image sur un fond uni (pour le JPEG, qui ne gère pas la transparence).
    static func flattened(_ image: UIImage, background: UIColor) -> UIImage {
        draw(size: image.size, opaque: true) { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func draw(size: CGSize, opaque: Bool = false, actions: (UIGraphicsImageRendererContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: size, format: format).image(actions: actions)
    }
}
