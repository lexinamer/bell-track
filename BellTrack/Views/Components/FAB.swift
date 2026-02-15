import SwiftUI

struct FAB: View {

    let onLogWorkout: () -> Void
    let onCreateBlock: () -> Void

    @State private var showingMenu = false

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button {
                    showingMenu = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.brand.primary)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, Theme.Space.md)
                .padding(.bottom, Theme.Space.md)
            }
        }
        .sheet(isPresented: $showingMenu) {
            FABMenu(
                onLogWorkout: {
                    showingMenu = false
                    onLogWorkout()
                },
                onCreateBlock: {
                    showingMenu = false
                    onCreateBlock()
                }
            )
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
    }
}

struct FABMenu: View {

    let onLogWorkout: () -> Void
    let onCreateBlock: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            Button {
                onLogWorkout()
            } label: {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.system(size: 20))
                        .foregroundColor(Color.brand.primary)
                        .frame(width: 32)

                    Text("Log Workout")
                        .font(Theme.Font.cardTitle)
                        .foregroundColor(Color.brand.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.md)
                .background(Color.brand.surface)
            }

            Divider()
                .padding(.leading, Theme.Space.md)

            Button {
                onCreateBlock()
            } label: {
                HStack {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 20))
                        .foregroundColor(Color.brand.primary)
                        .frame(width: 32)

                    Text("Create Block")
                        .font(Theme.Font.cardTitle)
                        .foregroundColor(Color.brand.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.md)
                .background(Color.brand.surface)
            }
        }
        .background(Color.brand.background)
    }
}
