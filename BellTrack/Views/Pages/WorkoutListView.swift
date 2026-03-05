import SwiftUI

struct WorkoutListView: View {

    @State private var entries: [WorkoutEntry] = []
    @State private var showForm = false
    @State private var selectedEntry: WorkoutEntry? = nil
    @State private var showSettings = false
    @State private var isLoading = true

    private let firestore = FirestoreService.shared

    private var groupedEntries: [(month: String, entries: [WorkoutEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let grouped = Dictionary(grouping: entries) { entry in
            formatter.string(from: entry.date)
        }
        return grouped
            .map { (month: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { lhs, rhs in
                let lhsDate = lhs.entries.first?.date ?? Date.distantPast
                let rhsDate = rhs.entries.first?.date ?? Date.distantPast
                return lhsDate > rhsDate
            }
    }

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()
            if isLoading {
                ProgressView()
            } else if entries.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Workout Log")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    selectedEntry = nil
                    showForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .fullScreenCover(isPresented: $showForm, onDismiss: { Task { await load() } }) {
            WorkoutFormView(entry: selectedEntry)
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .task { await load() }
    }

    private var list: some View {
        List {
            ForEach(groupedEntries, id: \.month) { group in
                Section {
                    ForEach(group.entries) { entry in
                        entryRow(entry)
                            .listRowBackground(Color.brand.background)
                            .listRowInsets(EdgeInsets(top: Theme.Space.md, leading: Theme.Space.lg, bottom: Theme.Space.md, trailing: Theme.Space.lg))
                    }
                } header: {
                    Text(group.month.components(separatedBy: " ").first ?? group.month)
                        .font(Theme.Font.sectionTitle)
                        .foregroundColor(Color.brand.textPrimary)
                        .textCase(nil)
                        .padding(.leading, Theme.Space.lg)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: Theme.Space.xs, trailing: 0))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listSectionHeaderTopPadding(0)
    }

    private func entryRow(_ entry: WorkoutEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.md) {
            Text(entry.date.shortDateString)
                .font(Theme.Font.cardCaption)
                .foregroundColor(Color.brand.textSecondary)
                .frame(width: 56, alignment: .leading)

            Text(entry.segments.filter { !$0.isEmpty }.joined(separator: "\n"))
                .font(.system(size: Theme.TypeSize.md, weight: .regular))
                .foregroundColor(Color.brand.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(Theme.Space.xs)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedEntry = entry
            showForm = true
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await delete(entry) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                duplicate(entry)
            } label: {
                Label("Duplicate", systemImage: "square.on.square.fill")
            }
            .tint(Color.brand.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.sm) {
            Text("No workouts yet")
                .font(Theme.Font.cardTitle)
                .foregroundColor(Color.brand.textSecondary)
            Text("Tap + to log your first session")
                .font(Theme.Font.cardCaption)
                .foregroundColor(Color.brand.textSecondary.opacity(0.6))
        }
    }

    private func duplicate(_ entry: WorkoutEntry) {
        selectedEntry = WorkoutEntry(id: UUID().uuidString, date: Date(), segments: entry.segments)
        showForm = true
    }

    private func delete(_ entry: WorkoutEntry) async {
        try? await firestore.deleteWorkout(id: entry.id)
        await load()
    }

    private func load() async {
        isLoading = true
        entries = (try? await firestore.fetchWorkouts()) ?? []
        isLoading = false
    }
}
