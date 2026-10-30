// 앱 아이콘(흰 8분음표)을 코드로 그려 iconutil 이 읽는 .iconset 폴더를 만든다.
// 사용법: swift scripts/make-icon.swift <출력 폴더.iconset>
// SF Symbols 는 라이선스상 앱 아이콘에 쓸 수 없어 음표를 직접 그린다.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 디자인 좌표계 한 변 — macOS 아이콘 템플릿(1024pt) 기준, 원점은 왼쪽 아래
let canvas: CGFloat = 1024

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("make-icon: \(message)\n".utf8))
    exit(1)
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat(hex >> 16 & 0xFF) / 255,
        green: CGFloat(hex >> 8 & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// macOS 아이콘 그리드: 캔버스 가운데 824pt 둥근 사각형에 대각선 그라데이션
func drawBackground(in context: CGContext) {
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    context.addPath(CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil))
    context.clip()
    let colors = [color(0xB34DFF), color(0x5B5BFF)] as CFArray
    guard let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]
    ) else { fail("그라데이션을 만들 수 없습니다") }
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: tile.minX, y: tile.maxY),
        end: CGPoint(x: tile.maxX, y: tile.minY),
        options: []
    )
}

/// 기둥 꼭대기에서 오른쪽 아래로 휘어 내려가는 깃발
func flagPath(stemTopRight top: CGPoint, stemWidth: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: top.x - stemWidth, y: top.y))
    path.addCurve(
        to: CGPoint(x: top.x + 165, y: top.y - 340),
        control1: CGPoint(x: top.x + 10, y: top.y - 120),
        control2: CGPoint(x: top.x + 215, y: top.y - 180)
    )
    path.addCurve(
        to: CGPoint(x: top.x, y: top.y - 200),
        control1: CGPoint(x: top.x + 175, y: top.y - 270),
        control2: CGPoint(x: top.x + 50, y: top.y - 225)
    )
    path.closeSubpath()
    return path
}

/// 흰 8분음표: 기울어진 머리 + 기둥 + 깃발
func drawEighthNote(in context: CGContext) {
    let head = CGPoint(x: 425, y: 315)
    let radiusX: CGFloat = 135, radiusY: CGFloat = 100, tilt = CGFloat.pi / 9
    let stemWidth: CGFloat = 46
    // 기둥을 기울어진 타원의 가장 오른쪽 점(접선이 수직인 곳)에서 시작해야 이음매에 턱이 생기지 않는다
    let rightmostX = (pow(radiusX * cos(tilt), 2) + pow(radiusY * sin(tilt), 2)).squareRoot()
    let rightmostY = (radiusX * radiusX - radiusY * radiusY) * sin(tilt) * cos(tilt) / rightmostX
    let stemRight = head.x + rightmostX
    let stemBottom = head.y + rightmostY
    let stemTop = head.y + 500

    var headTransform = CGAffineTransform(translationX: head.x, y: head.y).rotated(by: tilt)
    let parts: [CGPath] = [
        CGPath(
            ellipseIn: CGRect(x: -radiusX, y: -radiusY, width: radiusX * 2, height: radiusY * 2),
            transform: &headTransform
        ),
        CGPath(
            rect: CGRect(x: stemRight - stemWidth, y: stemBottom, width: stemWidth, height: stemTop - stemBottom),
            transform: nil
        ),
        flagPath(stemTopRight: CGPoint(x: stemRight, y: stemTop), stemWidth: stemWidth),
    ]
    // 조각마다 그림자가 서로 겹쳐 비치지 않도록 한 레이어로 묶어 그림자를 한 번만 드리운다
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: color(0x000000, alpha: 0.25))
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    context.setFillColor(color(0xFFFFFF))
    for part in parts {
        context.addPath(part)
        context.fillPath()
    }
    context.endTransparencyLayer()
}

func renderPNG(pixels: Int, to url: URL) {
    guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
              space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          )
    else { fail("\(pixels)px 비트맵을 만들 수 없습니다") }
    context.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    drawBackground(in: context)
    drawEighthNote(in: context)
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fail("PNG 를 만들 수 없습니다: \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("PNG 를 저장할 수 없습니다: \(url.path)") }
}

guard CommandLine.arguments.count == 2 else { fail("사용법: swift scripts/make-icon.swift <출력 폴더.iconset>") }
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
do {
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
} catch {
    fail("출력 폴더를 만들 수 없습니다: \(error.localizedDescription)")
}
// iconutil 이 요구하는 파일 이름과 크기 (pt 크기 + @2x)
for points in [16, 32, 128, 256, 512] {
    renderPNG(pixels: points, to: output.appending(path: "icon_\(points)x\(points).png"))
    renderPNG(pixels: points * 2, to: output.appending(path: "icon_\(points)x\(points)@2x.png"))
}
