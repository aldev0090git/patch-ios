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
// Output matches the captures exactly, whatever size they are. App Store
// Connect requires the size of the device tab it shows — currently "iPhone
// with Dynamic Island (medium display)", 1206x2622 — and rejects anything
// else as "File dimensions are invalid". Shoot on a 6.3" device.
//
// Exactness is why this draws into an explicit bitmap rather than using
// NSImage.lockFocus, which adopts the screen's backing scale and silently
// doubles everything.

import AppKit

let dir = "/private/tmp/claude-501/-Users-user/6945ba16-d070-41b5-ac33-8750d4ff8cdd/scratchpad/store"
let out = "\(dir)/final"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

struct Slot {
    let file: String
    let caption: String
    let bg: NSColor
    let ink: NSColor
    /// Crop the source to this fraction of its height before placing — used
    /// to keep the test runner's icon off the home screen shot. A fraction,
    /// not a pixel count, so it survives a change of device.
    var cropTop: CGFloat? = nil
}

func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
}
let paper = rgb(236, 237, 242), ink = rgb(28, 28, 30)
let night = rgb(11, 11, 13), chalk = rgb(245, 245, 247)

let slots: [Slot] = [
    // Four light, four dark, and nothing shown twice: the dark half wears a
    // different theme on each screen, so the set covers both appearances and
    // all three themes without repeating a screen.
    Slot(file: "light-paper-1-today", caption: "Today, at a glance", bg: paper, ink: ink),
    Slot(file: "light-paper-2-calendar", caption: "Forgot a day?\nLog it whenever",
         bg: paper, ink: ink),
    Slot(file: "light-paper-3-statistics", caption: "Watch the pattern build",
         bg: paper, ink: ink),
    Slot(file: "light-paper-4-overall-goal", caption: "Work toward\na bigger total",
         bg: paper, ink: ink),
    Slot(file: "dark-gold-1-today", caption: "Five themes\nto choose from",
         bg: rgb(42, 32, 21), ink: chalk),
    Slot(file: "dark-roseGold-2-calendar", caption: "Every screen wears it",
         bg: rgb(43, 26, 26), ink: chalk),
    Slot(file: "dark-platinum-3-statistics", caption: "Warm or cool,\nyour call",
         bg: rgb(24, 32, 40), ink: chalk),
    Slot(file: "dark-paper-4-overall-goal", caption: "At home in the dark",
         bg: night, ink: chalk),
    // Cropped above the test runner's icon, which has no business on a
    // product page. 0.537 of the height keeps both widgets and the rows
    // short of the icon row below — a fraction, so it survives a change of device.
    Slot(file: "widget-home-screen", caption: "Progress on\nyour Home Screen",
         bg: night, ink: chalk, cropTop: 0.55)
]

// Taken from the captures rather than hardcoded. Apple's required size is a
// property of the device tab in App Store Connect, not a constant — the
// listing wants the "medium display" iPhone, 1206 x 2622, and a set shot on
// a Pro Max is rejected outright as "File dimensions are invalid".
let probe = NSImage(contentsOfFile: "\(dir)/\(slots[0].file).png")!
let W = probe.size.width, H = probe.size.height
let capTop: CGFloat = H * 0.052
let deviceW: CGFloat = W * 0.788

for (index, slot) in slots.enumerated() {
    guard let src = NSImage(contentsOfFile: "\(dir)/\(slot.file).png") else {
        print("missing \(slot.file)"); continue
    }
    guard let srcCG = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    let cg = slot.cropTop.flatMap { fraction -> CGImage? in
        let height = (CGFloat(srcCG.height) * fraction).rounded()
        return srcCG.cropping(to: CGRect(x: 0, y: 0, width: CGFloat(srcCG.width), height: height))
    } ?? srcCG
    let shot = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))

    // An explicit bitmap, not `NSImage.lockFocus`, which adopts the screen's
    // backing scale and silently produces a 2x image.
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
        .font: NSFont.systemFont(ofSize: H * 0.030, weight: .bold),
        .foregroundColor: slot.ink,
        .paragraphStyle: style
    ]
    let text = slot.caption as NSString
    let capH = text.boundingRect(with: NSSize(width: W - W * 0.12, height: H * 0.21),
                                 options: [.usesLineFragmentOrigin], attributes: attrs).height
    text.draw(in: NSRect(x: W * 0.06, y: H - capTop - capH, width: W - W * 0.12, height: capH),
              withAttributes: attrs)

    // A full device shot is taller than the space left under the caption, so
    // it hangs off the bottom and is clipped — which is the look wanted, the
    // screen continuing past the frame. A cropped strip is shorter than the
    // space, so it is centred in it instead of stranded at the top.
    let top = H - capTop - capH - H * 0.031
    let available = top - H * 0.028
    let scale = deviceW / shot.size.width
    let dh = shot.size.height * scale
    let drawY = dh >= available ? top - dh : top - available / 2 - dh / 2
    let frameH = min(dh, available)
    let frame = NSRect(x: (W - deviceW) / 2, y: drawY + dh - frameH,
                       width: deviceW, height: frameH)

    NSGraphicsContext.saveGraphicsState()
    let radius: CGFloat = W * (slot.cropTop == nil ? 0.047 : 0.021)
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
