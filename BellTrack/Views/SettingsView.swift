import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedUnit: UserSettings.WeightUnit = .kg
    @State private var isLoading = true
    @State private var userSettings: UserSettings?
    @Environment(\.dismiss) var dismiss
    private let firestoreService = FirestoreService()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Account Section
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Account")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                        
                        if let email = authService.user?.email {
                            HStack {
                                Text("Email")
                                    .foregroundColor(Color.brand.textSecondary)
                                Spacer()
                                Text(email)
                                    .foregroundColor(Color.brand.textPrimary)
                            }
                            .padding(Spacing.md)
                            .background(Color.brand.surface)
                            .cornerRadius(CornerRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .stroke(Color.brand.border, lineWidth: 1)
                            )
                        }
                    }
                    
                    // Preferences Section
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Preferences")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                        
                        HStack {
                            Text("Weight Unit")
                                .foregroundColor(Color.brand.textPrimary)
                            Spacer()
                            Picker("", selection: $selectedUnit) {
                                Text("kg").tag(UserSettings.WeightUnit.kg)
                                Text("lbs").tag(UserSettings.WeightUnit.lbs)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }
                        .padding(Spacing.md)
                        .background(Color.brand.surface)
                        .cornerRadius(CornerRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )
                        .onChange(of: selectedUnit) { _, newValue in
                            saveSettings()
                        }
                    }
                    
                    // Log Out Button
                    Button(action: logOut) {
                        Text("Log Out")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.md)
                            .background(Color.brand.destructive)
                            .cornerRadius(CornerRadius.sm)
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color.brand.surface)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color.brand.textPrimary)
                    }
                }
            }
            .task {
                await loadSettings()
            }
        }
    }
    
    private func loadSettings() async {
        guard let userId = authService.user?.uid else { return }
        
        do {
            if let settings = try await firestoreService.fetchSettings(userId: userId) {
                await MainActor.run {
                    userSettings = settings
                    selectedUnit = settings.units
                    isLoading = false
                }
            } else {
                // Create default settings
                let newSettings = UserSettings(userId: userId, units: .kg)
                try await firestoreService.saveSettings(newSettings)
                await MainActor.run {
                    userSettings = newSettings
                    selectedUnit = .kg
                    isLoading = false
                }
            }
        } catch {
            print("Error loading settings: \(error)")
            isLoading = false
        }
    }
    
    private func saveSettings() {
        guard let userId = authService.user?.uid else { return }
        
        let settings = UserSettings(
            id: userSettings?.id,
            userId: userId,
            units: selectedUnit
        )
        
        Task {
            do {
                try await firestoreService.saveSettings(settings)
            } catch {
                print("Error saving settings: \(error)")
            }
        }
    }
    
    private func logOut() {
        do {
            try authService.signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}
