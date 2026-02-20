import SwiftUI

struct BlockColorPalette {

    struct Family {
        let shades: [Color]  // [primary, secondary, darker]
    }

    // MARK: Color Families (in assignment order)

    static let families: [Family] = [
        // Pink
        Family(shades: [
            Color(hex: "FF006E"),
            Color(hex: "FF00A8"),
            Color(hex: "FF2D55")
        ]),
        
        // PURPLE
        Family(shades: [
            Color(hex: "5A00FF"),
            Color(hex: "A100FF"),
            Color(hex: "D966FF")
        ]),
        
        // Teal
        Family(shades: [
            Color(hex: "00FFC2"),
            Color(hex: "00E5FF"),
            Color(hex: "0066FF")
        ]),

        // Lime
        Family(shades: [
            Color(hex: "AEFF00"),
            Color(hex: "FFEE00"),
            Color(hex: "DAF36B")
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
