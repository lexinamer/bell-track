import SwiftUI

struct SessionCard: View {

    enum DateStyle {
        case compact    // Jan 10
        case full       // Jan 10, 2026
    }

    let session: Session
    var dateStyle: DateStyle = .compact

    /// Optional actions. If all are nil, the menu won’t show.
    var onEdit: (() -> Void)? = nil
    var onDuplicate: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    // MARK: - Derived

    private var hasMenu: Bool {
        onEdit != nil || onDuplicate != nil || onDelete != nil
    }

    private var dateText: String {
        switch dateStyle {
        case .compact:
            return session.date.formatted(.dateTime.month(.abbreviated).day())
        case .full:
            return session.date.formatted(.dateTime.month(.abbreviated).day().year())
        }
    }

    private var detailsText: String? {
        let trimmed = (session.details ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - View

    var body: some View {
        HStack(alignment: .center, spacing: Layout.contentSpacing) {

            // Date
            Text(dateText)
                .font(TextStyles.bodySmall)
                .foregroundColor(Color.brand.textSecondary)
                .frame(minWidth: 50, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineLimit(dateStyle == .full ? 2 : 1)

            // Details
            Text(detailsText ?? "No details")
                .font(TextStyles.bodySmall)
                .foregroundColor(detailsText == nil ? Color.brand.textSecondary : Color.brand.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Menu (keeps behavior identical everywhere)
            if hasMenu {
                menu
            } else {
                // Keeps right edge alignment consistent vs cards that do have a menu
                Spacer()
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, Layout.horizontalSpacingNarrow)
        .padding(.vertical, Layout.cardSpacing)
        .cardChrome()
    }

    private var menu: some View {
        Menu {
            if let onEdit {
                Button("Edit", action: onEdit)
            }
            if let onDuplicate {
                Button("Duplicate", action: onDuplicate)
            }
            if let onDelete {
                Button("Delete", role: .destructive, action: onDelete)
            }
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.brand.textSecondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
