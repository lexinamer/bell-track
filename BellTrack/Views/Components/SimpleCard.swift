import SwiftUI

struct SimpleCard<Content: View>: View {
    let content: Content
    let onTap: (() -> Void)?
    
    init(onTap: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.onTap = onTap
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}
