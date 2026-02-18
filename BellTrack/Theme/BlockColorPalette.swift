import SwiftUI

struct BlockColorPalette {

    struct Family {
        let shades: [Color]  // [primary, secondary, darker]
    }

    // MARK: Color Families (in assignment order)

    static let families: [Family] = [
        
        // PURPLE
        Family(shades: [
            Color(hex: "6600FF"),
            Color(hex: "8F00C5"),
            Color(hex: "C14DFF")
        ]),
        
        // BLUE
        Family(shades: [
            Color(hex: "0064FB"),
            Color(hex: "00A0C1"),
            Color(hex: "2EB1E0")
        ]),

        // GREEN
        Family(shades: [
            Color(hex: "299C12"),
            Color(hex: "85A906"),
            Color(hex: "5A750D")
        ]),
        
        // RED ORANGE
        Family(shades: [
            Color(hex: "CF2900"),
            Color(hex: "FF6200"),
            Color(hex: "EF6F58")
        ]),
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
