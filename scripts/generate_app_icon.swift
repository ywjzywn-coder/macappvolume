import AppKit

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppVolume/Resources/Assets.xcassets/AppIcon.appiconset")
let canvasSize = NSSize(width: 1024, height: 1024)

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawIcon() -> NSImage {
    let image = NSImage(size: canvasSize)
    image.lockFocus()

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: canvasSize).fill()

    let tile = NSRect(x: 82, y: 92, width: 860, height: 860)
    let tilePath = roundedRect(tile, radius: 202)
    let tileShadow = NSShadow()
    tileShadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.28)
    tileShadow.shadowBlurRadius = 34
    tileShadow.shadowOffset = NSSize(width: 0, height: -22)
    NSGraphicsContext.current?.saveGraphicsState()
    tileShadow.set()
    NSColor(calibratedRed: 0.10, green: 0.43, blue: 0.91, alpha: 1).setFill()
    tilePath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(calibratedRed: 0.30, green: 0.68, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.38, blue: 0.88, alpha: 1),
    ])!.draw(in: tilePath, angle: 90)

    NSColor(calibratedWhite: 1, alpha: 0.24).setStroke()
    let tileHighlight = roundedRect(NSRect(x: 96, y: 106, width: 832, height: 832), radius: 187)
    tileHighlight.lineWidth = 5
    tileHighlight.stroke()

    let panelRect = NSRect(x: 202, y: 218, width: 620, height: 610)
    let panelPath = roundedRect(panelRect, radius: 112)
    let panelShadow = NSShadow()
    panelShadow.shadowColor = NSColor(calibratedRed: 0.01, green: 0.12, blue: 0.32, alpha: 0.30)
    panelShadow.shadowBlurRadius = 30
    panelShadow.shadowOffset = NSSize(width: 0, height: -16)
    NSGraphicsContext.current?.saveGraphicsState()
    panelShadow.set()
    NSColor(calibratedWhite: 0.98, alpha: 0.96).setFill()
    panelPath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(calibratedWhite: 1, alpha: 0.98),
        NSColor(calibratedRed: 0.89, green: 0.94, blue: 0.99, alpha: 0.98),
    ])!.draw(in: panelPath, angle: 90)

    NSColor(calibratedWhite: 1, alpha: 0.86).setStroke()
    panelPath.lineWidth = 4
    panelPath.stroke()

    let trackColor = NSColor(calibratedRed: 0.64, green: 0.70, blue: 0.78, alpha: 1)
    let activeColor = NSColor(calibratedRed: 0.08, green: 0.46, blue: 0.94, alpha: 1)
    let tracks: [(x: CGFloat, knobY: CGFloat)] = [
        (350, 570),
        (512, 440),
        (674, 625),
    ]

    for track in tracks {
        trackColor.setFill()
        roundedRect(NSRect(x: track.x - 9, y: 310, width: 18, height: 420), radius: 9).fill()

        activeColor.setFill()
        roundedRect(NSRect(x: track.x - 9, y: 310, width: 18, height: track.knobY - 310), radius: 9).fill()

        let knobRect = NSRect(x: track.x - 43, y: track.knobY - 43, width: 86, height: 86)
        let knob = NSBezierPath(ovalIn: knobRect)
        let knobShadow = NSShadow()
        knobShadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.24)
        knobShadow.shadowBlurRadius = 12
        knobShadow.shadowOffset = NSSize(width: 0, height: -5)
        NSGraphicsContext.current?.saveGraphicsState()
        knobShadow.set()
        NSColor.white.setFill()
        knob.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        NSColor(calibratedRed: 0.76, green: 0.82, blue: 0.89, alpha: 1).setStroke()
        knob.lineWidth = 3
        knob.stroke()
    }

    image.unlockFocus()
    return image
}

func pngData(for image: NSImage, size: Int) -> Data? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: NSRect(origin: .zero, size: canvasSize),
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

let icon = drawIcon()
let sizes = [16, 32, 64, 128, 256, 512, 1024]
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for size in sizes {
    guard let data = pngData(for: icon, size: size) else {
        fatalError("Unable to render \(size)x\(size) app icon")
    }
    try data.write(to: outputDirectory.appendingPathComponent("AppIcon-\(size).png"))
}

print("Generated AppVolume icons in \(outputDirectory.path)")
