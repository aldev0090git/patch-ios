// Generates the app icon, so it is reproducible rather than a binary nobody
// can change. Run it from the repo root:
//
//     swift Tools/make-app-icon.swift Patch/Patch/Assets.xcassets/AppIcon.appiconset
//
// Writes the three appearances iOS asks for — light, dark and tinted — at
// 1024x1024 with no alpha, which an iOS icon must not have.
//
// The mark is a tick inside a stitched border: a patch is something small you
// sew on to mend something, and the border is what keeps the icon from being
// a generic checkmark.

import AppKit
import CoreGraphics
import Foundation

let size: CGFloat = 1024

func makeIcon(top: NSColor, bottom: NSColor, mark: NSColor, stitch: NSColor, to url: URL) {
    guard let context = CGContext(
        data: nil,
        width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { fatalError("no context") }

    // Full-bleed ground: an iOS icon must not be transparent anywhere.
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [top.cgColor, bottom.cgColor] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    // The stitched border: what makes this a *patch* rather than a tick.
    let inset: CGFloat = size * 0.145
    let stitchRect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let stitchPath = CGPath(
        roundedRect: stitchRect,
        cornerWidth: size * 0.10, cornerHeight: size * 0.10,
        transform: nil
    )
    context.saveGState()
    context.setStrokeColor(stitch.cgColor)
    context.setLineWidth(size * 0.022)
    context.setLineCap(.round)
    context.setLineDash(phase: 0, lengths: [size * 0.052, size * 0.042])
    context.addPath(stitchPath)
    context.strokePath()
    context.restoreGState()

    // The mark. Kept heavy and simple so it survives being 60 points wide.
    context.saveGState()
    context.setStrokeColor(mark.cgColor)
    context.setLineWidth(size * 0.105)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: CGPoint(x: size * 0.325, y: size * 0.515))
    context.addLine(to: CGPoint(x: size * 0.452, y: size * 0.385))
    context.addLine(to: CGPoint(x: size * 0.690, y: size * 0.625))
    context.strokePath()
    context.restoreGState()

    guard let image = context.makeImage() else { fatalError("no image") }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }
    try! data.write(to: url)
    print("wrote \(url.lastPathComponent)")
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])

makeIcon(
    top: NSColor(srgbRed: 0.22, green: 0.58, blue: 1.00, alpha: 1),
    bottom: NSColor(srgbRed: 0.04, green: 0.34, blue: 0.86, alpha: 1),
    mark: .white,
    stitch: NSColor(white: 1, alpha: 0.42),
    to: out.appendingPathComponent("icon-light.png")
)

// Dark: the same mark on a ground that sits back, rather than a different idea.
makeIcon(
    top: NSColor(srgbRed: 0.09, green: 0.17, blue: 0.33, alpha: 1),
    bottom: NSColor(srgbRed: 0.03, green: 0.07, blue: 0.16, alpha: 1),
    mark: NSColor(srgbRed: 0.42, green: 0.72, blue: 1.00, alpha: 1),
    stitch: NSColor(srgbRed: 0.42, green: 0.72, blue: 1.00, alpha: 0.32),
    to: out.appendingPathComponent("icon-dark.png")
)

// Tinted: iOS reads only the luminance here and applies the user's tint, so
// this is deliberately greyscale — any colour in it would simply be discarded.
makeIcon(
    top: NSColor(white: 0.16, alpha: 1),
    bottom: NSColor(white: 0.04, alpha: 1),
    mark: NSColor(white: 0.97, alpha: 1),
    stitch: NSColor(white: 0.97, alpha: 0.34),
    to: out.appendingPathComponent("icon-tinted.png")
)
