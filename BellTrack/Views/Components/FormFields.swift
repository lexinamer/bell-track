import SwiftUI

// MARK: - Form Tokens

enum FormTokens {
    static let inputHeight: CGFloat = 52
    static let editorMinHeight: CGFloat = 140
}

// MARK: - Label

struct FormLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(TextStyles.bodySmall)
            .foregroundColor(Color.brand.textSecondary)
    }
}

// MARK: - Box Style

struct FormBox: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.brand.surface)
            .cornerRadius(CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(Color.brand.border, lineWidth: 1)
            )
    }
}

extension View {
    func formBox() -> some View { modifier(FormBox()) }
}

// MARK: - Text Field (boxed, fixed height)

struct FormTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .font(TextStyles.body)
            .foregroundColor(Color.brand.textPrimary)
            .padding(.horizontal, Layout.horizontalSpacingNarrow)
            .frame(height: FormTokens.inputHeight)
            .formBox()
    }
}

// MARK: - Date Field (boxed row + sheet picker)

struct FormDateField: View {
    let label: String
    @Binding var date: Date

    @State private var isPresented: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            FormLabel(text: label)

            Button {
                isPresented = true
            } label: {
                HStack(spacing: Layout.contentSpacing) {
                    Text(date.formatted(date: .numeric, time: .omitted))
                        .font(TextStyles.body)
                        .foregroundColor(Color.brand.textPrimary)

                    Spacer()

                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.brand.textSecondary)
                }
                .padding(.horizontal, Layout.horizontalSpacingNarrow)
                .frame(height: FormTokens.inputHeight)
                .formBox()
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                ZStack {
                    Color.brand.surface.ignoresSafeArea()

                    DatePicker(
                        "",
                        selection: $date,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(Color.brand.primary)
                    .padding(.horizontal, Layout.horizontalSpacing)
                    .padding(.top, Layout.sectionSpacing)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(label)
                            .font(TextStyles.title)
                            .foregroundColor(Color.brand.textPrimary)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { isPresented = false }
                            .buttonStyle(.plain) 
                            .foregroundColor(Color.brand.primary)
                            .font(TextStyles.link)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Outlined Chip (boxed height)

struct FormChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TextStyles.body)
                .frame(maxWidth: .infinity)
                .frame(height: FormTokens.inputHeight)
                .foregroundColor(
                    isSelected ? Color.brand.surface : Color.brand.textPrimary
                )
                .background(
                    isSelected ? Color.brand.primary : Color.brand.surface
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(
                            isSelected ? Color.brand.primary : Color.brand.border,
                            lineWidth: 1
                        )
                )
                .cornerRadius(CornerRadius.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Text Editor (boxed with placeholder)

struct FormTextEditor: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(TextStyles.body)
                    .foregroundColor(Color.brand.textSecondary)
                    .padding(.top, 12)
                    .padding(.horizontal, 12)
            }

            TextEditor(text: $text)
                .font(TextStyles.body)
                .foregroundColor(Color.brand.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: FormTokens.editorMinHeight)
        }
        .formBox()
    }
}

// MARK: - Save Button
struct FormSaveButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button("Save", action: action)
            .buttonStyle(.borderedProminent)
            .disabled(!isEnabled)
    }
}

