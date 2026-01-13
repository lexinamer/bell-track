import SwiftUI

// MARK: - Block Card Base (shared chrome + building blocks)

enum BlockCardTokens {
    // Controls the padding INSIDE the card (distance from card edge to content).
    static let paddingH: CGFloat = Layout.horizontalSpacingNarrow
    static let paddingV: CGFloat = Layout.sectionSpacing
}

// MARK: - Container

struct BlockCardContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        // Controls spacing between major card rows (header - progress - sessions)
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            content()
        }
        // Controls padding inside the card.
        .padding(.horizontal, BlockCardTokens.paddingH)
        .padding(.vertical, BlockCardTokens.paddingV)
        .frame(maxWidth: .infinity, alignment: .leading)

        // Controls the shared card styling (surface + radius + shadows).
        .cardChrome()
    }
}

// MARK: - Header + Subline

struct BlockCardHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        // Controls spacing INSIDE the header row (Title ↔ trailing action).
        HStack(alignment: .firstTextBaseline, spacing: Layout.contentSpacing) {
            Text(title)
                .font(TextStyles.cardTitle)
                .foregroundColor(Color.brand.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            trailing()
        }
    }
}

struct BlockCardSubline: View {
    let text: String
    var style: Style = .secondary

    enum Style {
        case primary   // used when you want this line to read as main content
        case secondary // default muted subline
    }

    var body: some View {
        Text(text)
            .font(style == .primary ? TextStyles.body : TextStyles.bodySmall)
            .foregroundColor(
                style == .primary
                ? Color.brand.textPrimary
                : Color.brand.textSecondary
            )
            .lineLimit(1)
    }
}

// MARK: - Sections

struct BlockCardSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    // Breathing room to match the Figma visual rhythm.
    private let shadowCompensation: CGFloat = 6

    var body: some View {
        // Controls spacing BETWEEN session rows (Session 1 ↔ Session 2, etc.)
        VStack(alignment: .leading, spacing: 12 + shadowCompensation) {
            content()
        }
        // Adds separation between the subline and the first session row
        .padding(.top, shadowCompensation + 8)
    }
}

// MARK: - Actions

struct BlockCardLinkButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TextStyles.linkSmall)
                .foregroundColor(Color.brand.primary)
        }
        .buttonStyle(.plain)
    }
}
