import SwiftUI

struct BlockColorPalette {

    struct Family {
        let shades: [Color]  // [primary, secondary, darker]
    }

    // MARK: Color Families (in assignment order)

    static let families: [Family] = [

        // 1. BLUE
        Family(shades: [
            Color(hex: "0064FB"),
            Color(hex: "3D87FC"),
            Color(hex: "0050C8")
        ]),

        // 2. PURPLE
        Family(shades: [
            Color(hex: "8F00C5"),
            Color(hex: "B030E8"),
            Color(hex: "72009E")
        ]),

        // 3. PINK
        Family(shades: [
            Color(hex: "DB0070"),
            Color(hex: "F03090"),
            Color(hex: "B0005A")
        ]),

        // 4. ORANGE
        Family(shades: [
            Color(hex: "EF5B21"),
            Color(hex: "F57D4A"),
            Color(hex: "C04818")
        ])
    ]

    // MARK: API

    /// Returns the color family for a block at a given position index (sorted by creation order).
    static func family(at blockIndex: Int) -> Family {
        families[blockIndex % families.count]
    }

    /// Primary color for a block (first shade of its family).
    static func blockPrimary(blockIndex: Int) -> Color {
        family(at: blockIndex).shades[0]
    }

    /// Color for a specific template within a block.
    /// templateIndex 0 → primary shade, 1 → secondary, 2 → darker, then wraps.
    static func templateColor(blockIndex: Int, templateIndex: Int) -> Color {
        let shades = family(at: blockIndex).shades
        return shades[templateIndex % shades.count]
    }
}
