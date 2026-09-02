import AppKit
import Foundation
import UniformTypeIdentifiers

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: 0, space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

let lacquer = CGColor(srgbRed: 0.086, green: 0.078, blue: 0.067, alpha: 1)
let gold = CGColor(srgbRed: 0.925, green: 0.722, blue: 0.275, alpha: 1)
ctx.setFillColor(lacquer)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

ctx.setStrokeColor(gold)
ctx.setLineWidth(56)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
let loop = CGMutablePath()
let inset: CGFloat = 210
loop.addEllipse(in: CGRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2))
ctx.addPath(loop)
ctx.replacePathWithStrokedPath()
ctx.clip()
ctx.clear(CGRect(x: CGFloat(size) * 0.62, y: CGFloat(size) * 0.62, width: 280, height: 280))

let ctx2 = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: 0, space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
ctx2.setFillColor(lacquer)
ctx2.fill(CGRect(x: 0, y: 0, width: size, height: size))
ctx2.setStrokeColor(gold)
ctx2.setLineWidth(56)
ctx2.setLineCap(.round)
let ring = CGMutablePath()
ring.addArc(
    center: CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2 - 12),
    radius: 270,
    startAngle: 0.35,
    endAngle: 5.6,
    clockwise: false
)
ctx2.addPath(ring)
ctx2.strokePath()
ctx2.setLineWidth(42)
let tail = CGMutablePath()
tail.move(to: CGPoint(x: 690, y: 250))
tail.addQuadCurve(to: CGPoint(x: 820, y: 180), control: CGPoint(x: 780, y: 260))
ctx2.addPath(tail)
ctx2.strokePath()

let image = ctx2.makeImage()!
let dest = URL(fileURLWithPath: CommandLine.arguments[1])
let out = CGImageDestinationCreateWithURL(dest as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(out, image, nil)
CGImageDestinationFinalize(out)
