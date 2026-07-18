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

    let tile = NSRect(x: 72, y: 72, width: 880, height: 880)
    let tilePath = roundedRect(tile, radius: 210)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.17, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.02, green: 0.07, blue: 0.09, alpha: 1),
    ])!.draw(in: tilePath, angle: -90)

    let inset = NSRect(x: 92, y: 92, width: 840, height: 840)
    NSColor(calibratedWhite: 1, alpha: 0.10).setStroke()
    let insetPath = roundedRect(inset, radius: 192)
    insetPath.lineWidth = 4
    insetPath.stroke()

    let trackColor = NSColor(calibratedWhite: 1, alpha: 0.70)
    let accent = NSColor(calibratedRed: 0.20, green: 0.88, blue: 0.76, alpha: 1)
    let warmAccent = NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.35, alpha: 1)
    let tracks: [(x: CGFloat, knobY: CGFloat, color: NSColor)] = [
        (330, 595, accent),
        (512, 405, warmAccent),
        (694, 650, accent),
    ]

    for track in tracks {
        trackColor.setFill()
        roundedRect(NSRect(x: track.x - 13, y: 245, width: 26, height: 534), radius: 13).fill()

        track.color.setFill()
        roundedRect(NSRect(x: track.x - 72, y: track.knobY - 48, width: 144, height: 96), radius: 38).fill()

        NSColor(calibratedWhite: 1, alpha: 0.32).setStroke()
        let knobOutline = roundedRect(NSRect(x: track.x - 68, y: track.knobY - 44, width: 136, height: 88), radius: 34)
        knobOutline.lineWidth = 4
        knobOutline.stroke()
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
