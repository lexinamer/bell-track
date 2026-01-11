import SwiftUI

struct BlockCardActive: View {
    let block: Block

    /// All sessions for the block (newest-first preferred; we still sort defensively).
    let sessions: [Session]

    /// Precomputed by caller: "\(block.statusText) • N sessions"
    let statusLine: String

    /// Tap the card anywhere (except internal controls) to open block detail.
    let onOpen: () -> Void

    /// Log a new session for this block.
    let onLogSession: () -> Void

    /// Session menu actions (invoked via SessionCard ellipsis).
    let onEditSession: (Session) -> Void
    let onDuplicateSession: (Session) -> Void
    let onDeleteSession: (Session) -> Void

    // MARK: - Derived

    private var recentSessions: [Session] {
        Array(sessions.sorted { $0.date > $1.date }.prefix(2))
    }

    // MARK: - View

    var body: some View {
        Button(action: onOpen) {
            BlockCardContainer {
                BlockCardHeader(title: block.name) {
                    // Important: don’t let the trailing button tap open the card.
                    BlockCardLinkButton(title: "+ Log Session", action: onLogSession)
                        .contentShape(Rectangle())
                }

                BlockCardSubline(text: statusLine)

                BlockCardSection {
                    if recentSessions.isEmpty {
                        Text("No sessions yet. Log a session.")
                            .font(TextStyles.bodySmall)
                            .foregroundColor(Color.brand.textSecondary)
                    } else {
                        ForEach(recentSessions) { session in
                            SessionCard(
                                session: session,
                                dateStyle: .compact,
                                onEdit: { onEditSession(session) },
                                onDuplicate: { onDuplicateSession(session) },
                                onDelete: { onDeleteSession(session) }
                            )
                            // Prevent session interactions (ellipsis menu) from triggering the parent Button.
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
