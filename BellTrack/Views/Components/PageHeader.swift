import SwiftUI

struct PageHeader: View {
    let title: String
    let buttonText: String
    let onButtonTap: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            Button {
                onButtonTap()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text(buttonText)
                }
                .foregroundColor(Color.brand.primary)
                .font(.system(size: 16, weight: .medium))
            }
        }
        .padding(.horizontal)
        .padding(.top, 60)
        .padding(.bottom, 16)
    }
}
