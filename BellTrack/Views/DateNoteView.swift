import SwiftUI

struct DateNoteView: View {
    @Environment(\.dismiss) var dismiss
    let userId: String
    let date: Date
    let existingNote: DateNote?
    
    @State private var noteText: String = ""
    @State private var isSaving = false
    private let firestoreService = FirestoreService()
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: Typography.lg, weight: .bold))
                    .foregroundColor(Color.brand.textPrimary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                
                Text("Add a note about this day's workouts")
                    .font(.system(size: Typography.sm))
                    .foregroundColor(Color.brand.textSecondary)
                    .padding(.horizontal, Spacing.lg)
                
                TextEditor(text: $noteText)
                    .font(.system(size: Typography.md))
                    .frame(minHeight: 120)
                    .padding(Spacing.sm)
                    .background(Color.brand.surface)
                    .cornerRadius(CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(Color.brand.border, lineWidth: 1)
                    )
                    .padding(.horizontal, Spacing.lg)
                
                if existingNote != nil && !noteText.isEmpty {
                    Button(action: deleteNote) {
                        Text("Delete Note")
                            .font(.system(size: Typography.md, weight: .semibold))
                            .foregroundColor(Color.brand.destructive)
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.md)
                            .background(Color.brand.surface)
                            .cornerRadius(CornerRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .stroke(Color.brand.destructive, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, Spacing.lg)
                }
                
                Spacer()
            }
            .background(Color.brand.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(Color.brand.textPrimary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveNote()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brand.secondary)
                    .font(.system(size: Typography.md, weight: .bold))
                    .disabled(isSaving || noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                noteText = existingNote?.note ?? ""
            }
        }
    }
    
    private func saveNote() {
        isSaving = true
        
        let note = DateNote(
            id: existingNote?.id,
            userId: userId,
            date: Calendar.current.startOfDay(for: date),
            note: noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        Task {
            do {
                try await firestoreService.saveDateNote(note)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error saving note: \(error)")
                isSaving = false
            }
        }
    }
    
    private func deleteNote() {
        guard let id = existingNote?.id else { return }
        
        Task {
            do {
                try await firestoreService.deleteDateNote(id: id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error deleting note: \(error)")
            }
        }
    }
}
