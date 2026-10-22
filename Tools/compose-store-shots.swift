// Composes the App Store screenshots: a caption over a device capture, on a
// background tinted to suit the slot.
//
//   1. Capture:  xcodebuild test -scheme Patch \
//                  -destination 'id=<a 6.9" device>' \
//                  -only-testing:PatchUITests/AppStoreShotsUITests
//      and, for the themed slots,
//                  -only-testing:PatchUITests/ThemePrototypeUITests
//      Both are skipped in the shared scheme, and `-only-testing` does NOT
//      override that — lift the <SkippedTests> entry for the run.
//   2. Export the attachments to `dir` below.
//   3. swift Tools/compose-store-shots.swift
//
// Output is exactly 1320x2868, the only iPhone size App Store Connect still
// requires. That exactness is why this draws into an explicit bitmap rather
// than using NSImage.lockFocus, which adopts the screen's backing scale and
// silently doubles everything.

import AppKit

let dir = "/private/tmp/claude-501/-Users-user/6945ba16-d070-41b5-ac33-8750d4ff8cdd/scratchpad/store"
let out = "\(dir)/final"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

struct Slot {
    let file: String
    let caption: String
    let bg: NSColor
    let ink: NSColor
    /// Crop the source to its top N pixels before placing — used to keep the
    /// test runner's icon off the home screen shot.
    var cropTop: CGFloat? = nil
}

func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
}
let paper = rgb(236, 237, 242), ink = rgb(28, 28, 30)
let night = rgb(11, 11, 13), chalk = rgb(245, 245, 247)

let slots: [Slot] = [
    Slot(file: "light-1-today", caption: "Today, at a glance", bg: paper, ink: ink),
    Slot(file: "light-2-calendar", caption: "Forgot a day?\nLog it whenever", bg: paper, ink: ink),
    Slot(file: "light-3-statistics", caption: "Watch the pattern build", bg: paper, ink: ink),
    Slot(file: "light-4-overall-goal", caption: "Work toward\na bigger total", bg: paper, ink: ink),
    Slot(file: "gold-1-today", caption: "Five themes\nto choose from", bg: rgb(243, 233, 210), ink: ink),
    Slot(file: "roseGold-1-today", caption: "Every screen wears it", bg: rgb(246, 229, 225), ink: ink),
    Slot(file: "platinum-1-today", caption: "Warm or cool,\nyour call", bg: rgb(228, 236, 243), ink: ink),
    Slot(file: "dark-1-today", caption: "At home in the dark", bg: night, ink: chalk),
    Slot(file: "widget-home-screen", caption: "Progress on\nyour Home Screen",
         bg: paper, ink: ink, cropTop: 930)
]

let W: CGFloat = 1320, H: CGFloat = 2868
let capTop: CGFloat = 150, deviceW: CGFloat = 1040

for (index, slot) in slots.enumerated() {
    guard let src = NSImage(contentsOfFile: "\(dir)/\(slot.file).png") else {
        print("missing \(slot.file)"); continue
    }
    guard let srcCG = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    let cg = slot.cropTop.flatMap { top -> CGImage? in
        srcCG.cropping(to: CGRect(x: 0, y: 0, width: CGFloat(srcCG.width), height: top))
    } ?? srcCG
    let shot = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))

    // An explicit bitmap, not `NSImage.lockFocus`, which adopts the screen's
    // backing scale and silently produces a 2x image — App Store Connect
    // wants exactly 1320x2868.
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { continue }
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    slot.bg.setFill()
    NSRect(x: 0, y: 0, width: W, height: H).fill()

    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineSpacing = 10
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 86, weight: .bold),
        .foregroundColor: slot.ink,
        .paragraphStyle: style
    ]
    let text = slot.caption as NSString
    let capH = text.boundingRect(with: NSSize(width: W - 160, height: 600),
                                 options: [.usesLineFragmentOrigin], attributes: attrs).height
    text.draw(in: NSRect(x: 80, y: H - capTop - capH, width: W - 160, height: capH),
              withAttributes: attrs)

    // A full device shot is taller than the space left under the caption, so
    // it hangs off the bottom and is clipped — which is the look wanted, the
    // screen continuing past the frame. A cropped strip is shorter than the
    // space, so it is centred in it instead of stranded at the top.
    let top = H - capTop - capH - 90
    let available = top - 80
    let scale = deviceW / shot.size.width
    let dh = shot.size.height * scale
    let drawY = dh >= available ? top - dh : top - available / 2 - dh / 2
    let frameH = min(dh, available)
    let frame = NSRect(x: (W - deviceW) / 2, y: drawY + dh - frameH,
                       width: deviceW, height: frameH)

    NSGraphicsContext.saveGraphicsState()
    let radius: CGFloat = slot.cropTop == nil ? 62 : 28
    NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius).addClip()
    shot.draw(in: NSRect(x: frame.minX, y: drawY, width: deviceW, height: dh))
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    if let png = rep.representation(using: .png, properties: [:]) {
        let name = String(format: "%02d-%@.png", index + 1, slot.file)
        try? png.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
        print("wrote \(name)")
    }
}
