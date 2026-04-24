import SwiftUI

struct WorkoutListView: View {

    @State private var entries: [WorkoutEntry] = []
    @State private var formEntry: WorkoutEntry? = nil
    @State private var showSettings = false
    @State private var isLoading = true
    @State private var searchText = ""

    private let firestore = FirestoreService.shared

    private var filteredEntries: [WorkoutEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { entry in
            entry.segments.contains { $0.localizedCaseInsensitiveContains(searchText) }
            || entry.date.shortDateString.localizedCaseInsensitiveContains(searchText)
            || entry.date.mediumDateString.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedEntries: [(month: String, entries: [WorkoutEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let grouped = Dictionary(grouping: filteredEntries) { entry in
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
            } else if filteredEntries.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .searchable(text: $searchText, prompt: "Search workouts")
        .navigationTitle("Workout Log")
        .navigationBarTitleDisplayMode(.inline)
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
                    formEntry = WorkoutEntry()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $formEntry, onDismiss: { Task { await reload() } }) { entry in
            WorkoutFormView(entry: entry)
        }
        .sheet(isPresented: $showSettings) {
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
                            .listRowInsets(EdgeInsets(top: 20, leading: Theme.Space.lg, bottom: 20, trailing: Theme.Space.lg))
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
        .padding(.top, Theme.Space.lg)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
            formEntry = entry
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await delete(entry) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                formEntry = WorkoutEntry(date: Date(), segments: entry.segments)
            } label: {
                Label("Duplicate", systemImage: "square.on.square.fill")
            }
            .tint(Color.brand.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.sm) {
            Text(searchText.isEmpty ? "No workouts yet" : "No results for \"\(searchText)\"")
                .font(Theme.Font.cardTitle)
                .foregroundColor(Color.brand.textSecondary)
            if searchText.isEmpty {
                Text("Tap + to log your first session")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary.opacity(0.6))
            }
        }
    }

    private func delete(_ entry: WorkoutEntry) async {
        try? await firestore.deleteWorkout(id: entry.id)
        entries.removeAll { $0.id == entry.id }
    }

    private func reload() async {
        entries = (try? await firestore.fetchWorkouts()) ?? []
    }

    private func load() async {
        isLoading = true
        entries = (try? await firestore.fetchWorkouts()) ?? []
        isLoading = false
    }
}
