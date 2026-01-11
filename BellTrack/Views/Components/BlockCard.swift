import SwiftUI

// MARK: - Block Card Base (shared chrome + building blocks)

enum BlockCardTokens {
    // Keep card padding consistent across active/completed cards
    static let paddingH: CGFloat = Layout.horizontalSpacingNarrow
    static let paddingV: CGFloat = Layout.sectionSpacing
}

// MARK: - Container

/// Standard block card container: spacing + padding + shared card chrome.
struct BlockCardContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.listSpacing) {
            content()
        }
        .padding(.horizontal, BlockCardTokens.paddingH)
        .padding(.vertical, BlockCardTokens.paddingV)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardChrome()
    }
}

// MARK: - Header + Subline

/// Shared header: title + trailing content (button/menu/etc).
struct BlockCardHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
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

/// Shared “status • progress” (or date range • sessions) line.
struct BlockCardSubline: View {
    let text: String
    var style: Style = .secondary

    enum Style {
        case primary
        case secondary
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

/// Section wrapper inside a block card (sessions list, empty hint, etc).
struct BlockCardSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    // This compensates for CardChrome shadow visually shrinking spacing.
    private let shadowCompensation: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.listSpacing + shadowCompensation) {
            content()
        }
        .padding(.top, shadowCompensation)
    }
}

// MARK: - Actions

/// Standard inline link button used inside block cards (e.g., "Log Session").
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
