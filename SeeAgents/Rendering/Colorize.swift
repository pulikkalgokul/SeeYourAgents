import CoreGraphics
import AppKit

// MARK: - HSL Helpers

func rgbToHSL(r: CGFloat, g: CGFloat, b: CGFloat) -> (h: CGFloat, s: CGFloat, l: CGFloat) {
    let maxC = max(r, g, b)
    let minC = min(r, g, b)
    let l = (maxC + minC) / 2

    if maxC == minC {
        return (0, 0, l)
    }

    let d = maxC - minC
    let s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)

    var h: CGFloat = 0
    if maxC == r {
        h = ((g - b) / d + (g < b ? 6 : 0)) * 60
    } else if maxC == g {
        h = ((b - r) / d + 2) * 60
    } else {
        h = ((r - g) / d + 4) * 60
    }

    return (h, s, l)
}

func hslToRGB(h: CGFloat, s: CGFloat, l: CGFloat) -> (r: UInt8, g: UInt8, b: UInt8) {
    let c = (1 - abs(2 * l - 1)) * s
    let hp = h / 60
    let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))

    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0

    if hp < 1 { r1 = c; g1 = x; b1 = 0 }
    else if hp < 2 { r1 = x; g1 = c; b1 = 0 }
    else if hp < 3 { r1 = 0; g1 = c; b1 = x }
    else if hp < 4 { r1 = 0; g1 = x; b1 = c }
    else if hp < 5 { r1 = x; g1 = 0; b1 = c }
    else { r1 = c; g1 = 0; b1 = x }

    let m = l - c / 2
    return (
        clamp255(r1 + m),
        clamp255(g1 + m),
        clamp255(b1 + m)
    )
}

private func clamp255(_ v: CGFloat) -> UInt8 {
    UInt8(max(0, min(255, (v * 255).rounded())))
}

// MARK: - Colorize (grayscale -> HSL)

func colorizeImage(_ image: CGImage, color: FloorColor) -> CGImage? {
    let width = image.width
    let height = image.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let data = context.data else { return nil }
    let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

    let h = color.h
    let s = color.s
    let b = color.b
    let c = color.c
    let useColorize = color.colorize ?? true

    for i in 0..<(width * height) {
        let offset = i * bytesPerPixel
        let a = pixels[offset + 3]
        if a == 0 { continue }

        let rVal = CGFloat(pixels[offset]) / 255.0
        let gVal = CGFloat(pixels[offset + 1]) / 255.0
        let bVal = CGFloat(pixels[offset + 2]) / 255.0

        let newR: UInt8
        let newG: UInt8
        let newB: UInt8

        if useColorize {
            // Colorize mode: grayscale -> luminance -> contrast/brightness -> HSL
            var lightness = 0.299 * rVal + 0.587 * gVal + 0.114 * bVal

            if c != 0 {
                let factor = (100 + c) / 100
                lightness = 0.5 + (lightness - 0.5) * factor
            }
            if b != 0 {
                lightness = lightness + b / 200
            }
            lightness = max(0, min(1, lightness))

            let satFrac = s / 100
            let rgb = hslToRGB(h: h, s: satFrac, l: lightness)
            newR = rgb.r; newG = rgb.g; newB = rgb.b
        } else {
            // Adjust mode: shift original pixel HSL values
            let (origH, origS, origL) = rgbToHSL(r: rVal, g: gVal, b: bVal)
            let newH = ((origH + h).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            let newS = max(0, min(1, origS + s / 100))

            var lightness = origL
            if c != 0 {
                let factor = (100 + c) / 100
                lightness = 0.5 + (lightness - 0.5) * factor
            }
            if b != 0 {
                lightness = lightness + b / 200
            }
            lightness = max(0, min(1, lightness))

            let rgb = hslToRGB(h: newH, s: newS, l: lightness)
            newR = rgb.r; newG = rgb.g; newB = rgb.b
        }

        // Handle premultiplied alpha
        if a < 255 {
            let af = CGFloat(a) / 255.0
            pixels[offset] = UInt8(CGFloat(newR) * af)
            pixels[offset + 1] = UInt8(CGFloat(newG) * af)
            pixels[offset + 2] = UInt8(CGFloat(newB) * af)
        } else {
            pixels[offset] = newR
            pixels[offset + 1] = newG
            pixels[offset + 2] = newB
        }
    }

    return context.makeImage()
}

// MARK: - Wall base color computation

func wallColorToNSColor(_ color: FloorColor) -> NSColor {
    var lightness: CGFloat = 0.5

    if color.c != 0 {
        let factor = (100 + color.c) / 100
        lightness = 0.5 + (lightness - 0.5) * factor
    }
    if color.b != 0 {
        lightness = lightness + color.b / 200
    }
    lightness = max(0, min(1, lightness))

    let satFrac = color.s / 100
    let rgb = hslToRGB(h: color.h, s: satFrac, l: lightness)
    return NSColor(red: CGFloat(rgb.r) / 255, green: CGFloat(rgb.g) / 255, blue: CGFloat(rgb.b) / 255, alpha: 1)
}
