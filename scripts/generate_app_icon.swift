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
        NSColor(calibratedRed: 0.38, green: 0.72, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.40, blue: 0.90, alpha: 1),
    ])!.draw(in: tilePath, angle: 90)

    NSColor(calibratedWhite: 1, alpha: 0.24).setStroke()
    let tileHighlight = roundedRect(NSRect(x: 96, y: 106, width: 832, height: 832), radius: 187)
    tileHighlight.lineWidth = 5
    tileHighlight.stroke()

    let symbolConfig = NSImage.SymbolConfiguration(pointSize: 470, weight: .medium)
        .applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))
    guard let speaker = NSImage(
        systemSymbolName: "speaker.wave.2.fill",
        accessibilityDescription: nil
    )?.withSymbolConfiguration(symbolConfig) else {
        fatalError("Unable to load speaker symbol")
    }

    let symbolRect = NSRect(x: 244, y: 276, width: 536, height: 536)
    let symbolShadow = NSShadow()
    symbolShadow.shadowColor = NSColor(calibratedRed: 0.01, green: 0.18, blue: 0.48, alpha: 0.32)
    symbolShadow.shadowBlurRadius = 18
    symbolShadow.shadowOffset = NSSize(width: 0, height: -10)
    NSGraphicsContext.current?.saveGraphicsState()
    symbolShadow.set()
    speaker.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.current?.restoreGraphicsState()

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
