// Regenerate the app's functional register icon on macOS:
// swift scripts/generate_icons.swift
import Foundation
import CoreGraphics
import ImageIO

func writeIcon(size: Int, to output: String) throws {
    let context = CGContext(data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.scaleBy(x: CGFloat(size) / 192, y: CGFloat(size) / 192)
    context.setFillColor(CGColor(red: 23/255, green: 47/255, blue: 56/255, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 192, height: 192))
    context.setFillColor(CGColor(red: 244/255, green: 175/255, blue: 69/255, alpha: 1))
    context.addPath(CGPath(roundedRect: CGRect(x: 44, y: 114, width: 104, height: 31),
        cornerWidth: 6, cornerHeight: 6, transform: nil))
    context.fillPath()
    context.setStrokeColor(CGColor(gray: 1, alpha: 1))
    context.setLineWidth(9)
    context.addPath(CGPath(roundedRect: CGRect(x: 51, y: 48, width: 90, height: 49),
        cornerWidth: 6, cornerHeight: 6, transform: nil))
    context.strokePath()
    context.setLineCap(.round)
    context.setLineWidth(7)
    context.move(to: CGPoint(x: 71, y: 79))
    context.addLine(to: CGPoint(x: 121, y: 79))
    context.move(to: CGPoint(x: 71, y: 64))
    context.addLine(to: CGPoint(x: 99, y: 64))
    context.strokePath()
    let url = URL(fileURLWithPath: output)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

let iosFolder = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
let contents = try Data(contentsOf: URL(fileURLWithPath: "\(iosFolder)/Contents.json"))
let catalog = try JSONSerialization.jsonObject(with: contents) as! [String: Any]
for image in catalog["images"] as! [[String: String]] {
    let points = Double(image["size"]!.split(separator: "x")[0])!
    let scale = Double(image["scale"]!.dropLast())!
    try writeIcon(size: Int(points * scale), to: "\(iosFolder)/\(image["filename"]!)")
}
for (density, size) in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)] {
    try writeIcon(size: size, to: "android/app/src/main/res/mipmap-\(density)/ic_launcher.png")
}
print("Generated iOS and Android register icons.")
