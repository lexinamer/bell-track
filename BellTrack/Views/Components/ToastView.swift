import SwiftUI

enum ToastType {
    case error
    case success

    var backgroundColor: Color {
        switch self {
        case .error: return .red
        case .success: return .green
        }
    }

    var icon: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
}

struct ToastView: View {
    let message: String
    let type: ToastType

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: type.icon)
                .font(.system(size: 18))

            Text(message)
                .font(Theme.Font.body)
                .lineLimit(2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm)
        .background(type.backgroundColor.opacity(0.95))
        .cornerRadius(Theme.Radius.md)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let type: ToastType
    let duration: Double

    func body(content: Content) -> some View {
        ZStack {
            content

            VStack {
                if isShowing {
                    ToastView(message: message, type: type)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isShowing = false
                                }
                            }
                        }
                        .padding(.top, Theme.Space.lg)
                }
                Spacer()
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowing)
        }
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, type: ToastType = .error, duration: Double = 3.0) -> some View {
        modifier(ToastModifier(isShowing: isShowing, message: message, type: type, duration: duration))
    }
}
