import SpriteKit
import AppKit

struct CharacterSprites {
    let walk: [[SKTexture]]    // [4 directions][4 frames: 0,1,2,1]
    let typing: [[SKTexture]]  // [4 directions][2 frames]
    let reading: [[SKTexture]] // [4 directions][2 frames]
}

final class CharacterSpriteLoader {
    static let shared = CharacterSpriteLoader()

    private var basePalettes: [Int: CharacterSprites] = [:]
    private var hueShiftedCache: [String: CharacterSprites] = [:]

    private init() {}

    func loadAllPalettes() {
        for i in 0..<CharacterConstants.paletteCount {
            guard let sprites = loadPalette(i) else {
                print("[CharacterSpriteLoader] Failed to load palette \(i)")
                continue
            }
            basePalettes[i] = sprites
        }
        print("[CharacterSpriteLoader] Loaded \(basePalettes.count) palettes")
    }

    func sprites(forPalette palette: Int, hueShift: CGFloat = 0) -> CharacterSprites? {
        if hueShift == 0 {
            return basePalettes[palette]
        }

        let key = "\(palette):\(Int(hueShift))"
        if let cached = hueShiftedCache[key] {
            return cached
        }

        guard let base = loadPaletteImage(palette) else { return basePalettes[palette] }

        let color = FloorColor(h: hueShift, s: 0, b: 0, c: 0, colorize: false)
        guard let shifted = colorizeImage(base, color: color) else { return basePalettes[palette] }

        let sprites = sliceSpriteSheet(shifted)
        hueShiftedCache[key] = sprites
        return sprites
    }

    // MARK: - Private

    private func loadPalette(_ index: Int) -> CharacterSprites? {
        guard let cgImage = loadPaletteImage(index) else { return nil }
        return sliceSpriteSheet(cgImage)
    }

    private func loadPaletteImage(_ index: Int) -> CGImage? {
        guard let url = Bundle.main.url(forResource: "char_\(index)", withExtension: "png"),
              let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return cgImage
    }

    private func sliceSpriteSheet(_ sheet: CGImage) -> CharacterSprites {
        let frameW = Int(CharacterConstants.spriteWidth)
        let frameH = Int(CharacterConstants.spriteFrameHeight)

        // Extract all frames: 7 cols x 3 rows
        // Row 0 = down, Row 1 = up, Row 2 = right
        // Cols: walk1(0), walk2/idle(1), walk3(2), type1(3), type2(4), read1(5), read2(6)
        var frames: [[CGImage]] = [] // [row][col]
        for row in 0..<3 {
            var rowFrames: [CGImage] = []
            for col in 0..<7 {
                let rect = CGRect(x: col * frameW, y: row * frameH, width: frameW, height: frameH)
                if let cropped = sheet.cropping(to: rect) {
                    rowFrames.append(cropped)
                } else {
                    rowFrames.append(sheet)
                }
            }
            frames.append(rowFrames)
        }

        func texture(_ img: CGImage) -> SKTexture {
            let t = SKTexture(cgImage: img)
            t.filteringMode = .nearest
            return t
        }

        // Build textures per direction
        // Direction indices: down=0, up=1, right=2, left=3
        // Sheet rows: down=0, up=1, right=2. Left = right (flipped at render time via xScale)
        var walk: [[SKTexture]] = []    // [4][4]
        var typing: [[SKTexture]] = []  // [4][2]
        var reading: [[SKTexture]] = [] // [4][2]

        for dir in 0..<4 {
            let sheetRow = dir < 3 ? dir : 2  // left reuses right row

            let walkFrames = [
                texture(frames[sheetRow][0]),
                texture(frames[sheetRow][1]),
                texture(frames[sheetRow][2]),
                texture(frames[sheetRow][1]),  // walk cycle: 0,1,2,1
            ]
            walk.append(walkFrames)

            let typeFrames = [
                texture(frames[sheetRow][3]),
                texture(frames[sheetRow][4]),
            ]
            typing.append(typeFrames)

            let readFrames = [
                texture(frames[sheetRow][5]),
                texture(frames[sheetRow][6]),
            ]
            reading.append(readFrames)
        }

        return CharacterSprites(walk: walk, typing: typing, reading: reading)
    }
}
