// Generates the Plates app icon: a glowing gold plate on a near-black tile.
// Run: swift scripts/generate_icon.swift
import AppKit
import CoreGraphics

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size,
                    bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgba(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: a)
}

let center = CGPoint(x: 512, y: 512)

// Background: deep vertical gradient with a faint blue-black cast.
let bg = CGGradient(colorsSpace: space,
                    colors: [rgba(0x15151F), rgba(0x07070C)] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 1024), end: CGPoint(x: 512, y: 0), options: [])

// Soft central ambience behind the plate.
let ambience = CGGradient(colorsSpace: space,
                          colors: [rgba(0xE8B84B, 0.14), rgba(0xE8B84B, 0.0)] as CFArray,
                          locations: [0, 1])!
ctx.drawRadialGradient(ambience, startCenter: center, startRadius: 0,
                       endCenter: center, endRadius: 470, options: [])

// Halo glow hugging the rim (annular radial gradient).
let halo = CGGradient(colorsSpace: space,
                      colors: [rgba(0xE8B84B, 0.0), rgba(0xE8B84B, 0.30),
                               rgba(0xE8B84B, 0.0)] as CFArray,
                      locations: [0.52, 0.66, 0.82])!
ctx.drawRadialGradient(halo, startCenter: center, startRadius: 0,
                       endCenter: center, endRadius: 460, options: [])

// Gold gradient used for the rings.
let gold = CGGradient(colorsSpace: space,
                      colors: [rgba(0xF6DA8A), rgba(0xE8B84B), rgba(0xB98A28)] as CFArray,
                      locations: [0, 0.45, 1])!

func strokeRingWithGold(radius: CGFloat, lineWidth: CGFloat, alpha: CGFloat = 1) {
    ctx.saveGState()
    ctx.setAlpha(alpha)
    let path = CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                        width: radius * 2, height: radius * 2), transform: nil)
    ctx.addPath(path)
    ctx.setLineWidth(lineWidth)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(gold,
                           start: CGPoint(x: center.x - radius, y: center.y + radius),
                           end: CGPoint(x: center.x + radius, y: center.y - radius),
                           options: [])
    ctx.restoreGState()
}

// The plate: outer rim + inner well.
strokeRingWithGold(radius: 300, lineWidth: 18)
strokeRingWithGold(radius: 196, lineWidth: 7, alpha: 0.85)

// Four-point sparkle sitting on the rim, upper right.
func sparkle(at p: CGPoint, r: CGFloat, waist: CGFloat) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: p.x, y: p.y + r))
    path.addQuadCurve(to: CGPoint(x: p.x + r, y: p.y), control: CGPoint(x: p.x + waist, y: p.y + waist))
    path.addQuadCurve(to: CGPoint(x: p.x, y: p.y - r), control: CGPoint(x: p.x + waist, y: p.y - waist))
    path.addQuadCurve(to: CGPoint(x: p.x - r, y: p.y), control: CGPoint(x: p.x - waist, y: p.y - waist))
    path.addQuadCurve(to: CGPoint(x: p.x, y: p.y + r), control: CGPoint(x: p.x - waist, y: p.y + waist))
    path.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 40, color: rgba(0xF6DA8A, 0.9))
    ctx.addPath(path)
    ctx.setFillColor(rgba(0xFBEBB8))
    ctx.fillPath()
    ctx.restoreGState()
}

let angle = CGFloat.pi / 4
sparkle(at: CGPoint(x: center.x + cos(angle) * 300, y: center.y + sin(angle) * 300),
        r: 64, waist: 13)

// Tiny counterpoint glint, lower left inside the well.
sparkle(at: CGPoint(x: center.x - 118, y: center.y - 132), r: 26, waist: 6)

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
let out = URL(fileURLWithPath: "Plates/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try! png.write(to: out)
print("wrote \(out.path) (\(png.count) bytes)")
