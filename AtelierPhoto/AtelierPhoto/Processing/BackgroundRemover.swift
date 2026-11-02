import CoreImage
import UIKit
import Vision

enum BackgroundRemovalError: LocalizedError {
    case invalidImage
    case noSubject

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "Impossible de lire cette image."
        case .noSubject:
            "Aucun sujet détecté sur cette photo. Essaie avec une image où la personne, l’animal ou l’objet est bien visible."
        }
    }
}

/// Supprime l'arrière-plan d'une photo grâce au framework Vision (traitement local, sur l'appareil).
enum BackgroundRemover {
    static func removeBackground(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else { throw BackgroundRemovalError.invalidImage }
        let scale = image.scale

        return try await Task.detached(priority: .userInitiated) {
            let output: CGImage
            do {
                // iOS 17 : détecte tout sujet (personnes, animaux, objets).
                output = try BackgroundRemover.foregroundCutout(cgImage)
            } catch BackgroundRemovalError.noSubject {
                throw BackgroundRemovalError.noSubject
            } catch {
                // Repli (par ex. sur le simulateur) : segmentation des personnes uniquement.
                output = try BackgroundRemover.personCutout(cgImage)
            }
            return UIImage(cgImage: output, scale: scale, orientation: .up)
        }.value
    }

    private static func foregroundCutout(_ source: CGImage) throws -> CGImage {
        let handler = VNImageRequestHandler(cgImage: source, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])

        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            throw BackgroundRemovalError.noSubject
        }
        let buffer = try result.generateMaskedImage(ofInstances: result.allInstances,
                                                    from: handler,
                                                    croppedToInstancesExtent: false)
        return try makeCGImage(from: CIImage(cvPixelBuffer: buffer))
    }

    private static func personCutout(_ source: CGImage) throws -> CGImage {
        let handler = VNImageRequestHandler(cgImage: source, options: [:])
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        try handler.perform([request])

        guard let mask = request.results?.first?.pixelBuffer else {
            throw BackgroundRemovalError.noSubject
        }
        let input = CIImage(cgImage: source)
        var maskImage = CIImage(cvPixelBuffer: mask)
        maskImage = maskImage.transformed(by: CGAffineTransform(
            scaleX: input.extent.width / maskImage.extent.width,
            y: input.extent.height / maskImage.extent.height))

        let output = input.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: maskImage
        ])
        return try makeCGImage(from: output.cropped(to: input.extent))
    }

    private static func makeCGImage(from image: CIImage) throws -> CGImage {
        guard let cgImage = ImageProcessor.context.createCGImage(image, from: image.extent) else {
            throw BackgroundRemovalError.invalidImage
        }
        return cgImage
    }
}
