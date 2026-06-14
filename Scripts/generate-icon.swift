#!/usr/bin/env swift

import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")
let previewURL = resourcesURL.appendingPathComponent("AppIcon.png")

let fileManager = FileManager.default
try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
if fileManager.fileExists(atPath: iconsetURL.path) {
    try fileManager.removeItem(at: iconsetURL)
}
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawPill(_ rect: CGRect, radius: CGFloat, fill: NSColor) {
    fill.setFill()
    roundedRect(rect, radius: radius).fill()
}

func drawIcon(size: Int) -> NSImage {
    let scale = CGFloat(size) / 1024
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.shouldAntialias = true

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let canvas = CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))
    let outerRect = canvas.insetBy(dx: 78 * scale, dy: 78 * scale)
    let outerPath = roundedRect(outerRect, radius: 216 * scale)

    let baseShadow = NSShadow()
    baseShadow.shadowOffset = NSSize(width: 0, height: -24 * scale)
    baseShadow.shadowBlurRadius = 44 * scale
    baseShadow.shadowColor = color(24, 70, 120, 0.24)
    NSGraphicsContext.saveGraphicsState()
    baseShadow.set()
    color(94, 166, 245, 0.55).setFill()
    outerPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    let backgroundGradient = NSGradient(colors: [
        color(239, 249, 255),
        color(197, 229, 255),
        color(102, 179, 248)
    ])!
    backgroundGradient.draw(in: outerPath, angle: -38)

    color(255, 255, 255, 0.44).setStroke()
    outerPath.lineWidth = 3 * scale
    outerPath.stroke()

    let panelRect = CGRect(x: 170 * scale, y: 236 * scale, width: 684 * scale, height: 520 * scale)
    let panelPath = roundedRect(panelRect, radius: 104 * scale)

    let panelShadow = NSShadow()
    panelShadow.shadowOffset = NSSize(width: 0, height: -20 * scale)
    panelShadow.shadowBlurRadius = 34 * scale
    panelShadow.shadowColor = color(42, 103, 158, 0.22)
    NSGraphicsContext.saveGraphicsState()
    panelShadow.set()
    color(255, 255, 255, 0.92).setFill()
    panelPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    color(255, 255, 255, 0.70).setFill()
    panelPath.fill()
    color(111, 178, 235, 0.22).setStroke()
    panelPath.lineWidth = 2 * scale
    panelPath.stroke()

    let badgeRect = CGRect(x: 236 * scale, y: 608 * scale, width: 150 * scale, height: 102 * scale)
    let badgeGradient = NSGradient(colors: [
        color(86, 169, 249),
        color(50, 139, 235)
    ])!
    badgeGradient.draw(in: roundedRect(badgeRect, radius: 38 * scale), angle: -35)

    let cAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 80 * scale, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    let cString = NSString(string: "C")
    let cSize = cString.size(withAttributes: cAttributes)
    cString.draw(
        at: CGPoint(x: badgeRect.midX - cSize.width / 2, y: badgeRect.midY - cSize.height / 2 - 3 * scale),
        withAttributes: cAttributes
    )

    drawPill(CGRect(x: 422 * scale, y: 662 * scale, width: 250 * scale, height: 28 * scale), radius: 14 * scale, fill: color(215, 225, 231))
    drawPill(CGRect(x: 422 * scale, y: 662 * scale, width: 146 * scale, height: 28 * scale), radius: 14 * scale, fill: color(96, 177, 248))
    drawPill(CGRect(x: 422 * scale, y: 604 * scale, width: 326 * scale, height: 28 * scale), radius: 14 * scale, fill: color(215, 225, 231))
    drawPill(CGRect(x: 422 * scale, y: 604 * scale, width: 218 * scale, height: 28 * scale), radius: 14 * scale, fill: color(96, 177, 248))

    let heatmapStartX = 268 * scale
    let heatmapStartY = 318 * scale
    let cell = 54 * scale
    let gap = 22 * scale
    let blues = [
        color(236, 238, 240),
        color(203, 226, 247),
        color(152, 204, 250),
        color(104, 181, 248),
        color(56, 148, 242)
    ]
    let levels = [
        [0, 1, 0, 2, 0],
        [1, 0, 2, 4, 2],
        [0, 2, 3, 0, 1]
    ]

    for row in 0..<levels.count {
        for column in 0..<levels[row].count {
            let rect = CGRect(
                x: heatmapStartX + CGFloat(column) * (cell + gap),
                y: heatmapStartY + CGFloat(levels.count - row - 1) * (cell + gap),
                width: cell,
                height: cell
            )
            drawPill(rect, radius: 14 * scale, fill: blues[levels[row][column]])
        }
    }

    drawPill(CGRect(x: 690 * scale, y: 332 * scale, width: 54 * scale, height: 54 * scale), radius: 27 * scale, fill: color(49, 197, 91))

    return image
}

func writePNG(size: Int, name: String) throws {
    let image = drawIcon(size: size)
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render \(name)"])
    }

    try pngData.write(to: iconsetURL.appendingPathComponent(name))
}

let icons: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for icon in icons {
    try writePNG(size: icon.0, name: icon.1)
}

if fileManager.fileExists(atPath: icnsURL.path) {
    try fileManager.removeItem(at: icnsURL)
}

try Data(contentsOf: iconsetURL.appendingPathComponent("icon_512x512@2x.png")).write(to: previewURL)

func fourCharacterData(_ value: String) -> Data {
    Data(value.utf8)
}

func bigEndianUInt32(_ value: Int) -> Data {
    var number = UInt32(value).bigEndian
    return Data(bytes: &number, count: MemoryLayout<UInt32>.size)
}

let icnsEntries: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

var entryData = Data()
for entry in icnsEntries {
    let pngData = try Data(contentsOf: iconsetURL.appendingPathComponent(entry.1))
    entryData.append(fourCharacterData(entry.0))
    entryData.append(bigEndianUInt32(pngData.count + 8))
    entryData.append(pngData)
}

var icnsData = Data()
icnsData.append(fourCharacterData("icns"))
icnsData.append(bigEndianUInt32(entryData.count + 8))
icnsData.append(entryData)
try icnsData.write(to: icnsURL)

print("Generated \(icnsURL.path)")
