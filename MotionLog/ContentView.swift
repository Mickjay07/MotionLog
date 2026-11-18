import SwiftUI

struct ActivityEntry: Identifiable, Codable {
    var id = UUID()
    var kind: String
    var date: Date
    var minutes: Int
    var distance: Double
    var calories: Int
    var note: String

    var symbol: String {
        switch kind {
        case "Běh": return "figure.run"
        case "Chůze": return "figure.walk"
        case "Cyklistika": return "bicycle"
        case "Turistika": return "figure.hiking"
        default: return "figure.mixed.cardio"
        }
    }
}

@MainActor final class ActivityStore: ObservableObject {
    @Published var entries: [ActivityEntry] = [] { didSet { save() } }
    private let key = "motionlog.activities.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([ActivityEntry].self, from: data) {
            entries = saved
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct ContentView: View {
    @StateObject private var store = ActivityStore()
    @State private var showingEditor = false
    @State private var editing: ActivityEntry?

    private var sorted: [ActivityEntry] { store.entries.sorted { $0.date > $1.date } }
    private var totalDistance: Double { store.entries.reduce(0) { $0 + $1.distance } }
    private var totalMinutes: Int { store.entries.reduce(0) { $0 + $1.minutes } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tvoje aktivity").font(.largeTitle.bold())
                        Text("Osobní deník pohybu").foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        metric("Vzdálenost", value: totalDistance.formatted(.number.precision(.fractionLength(1))) + " km", symbol: "point.topleft.down.curvedto.point.bottomright.up")
                        metric("Čas", value: "\(totalMinutes) min", symbol: "clock")
                    }
                    HStack(spacing: 12) {
                        metric("Aktivity", value: "\(store.entries.count)", symbol: "figure.run")
                        metric("Kalorie", value: "\(store.entries.reduce(0) { $0 + $1.calories }) kcal", symbol: "flame")
                    }
                    HStack {
                        Text("Historie").font(.title2.bold())
                        Spacer()
                        Button { editing = nil; showingEditor = true } label: {
                            Label("Přidat", systemImage: "plus.circle.fill")
                        }.fontWeight(.semibold)
                    }
                    if sorted.isEmpty {
                        ContentUnavailableView("Zatím žádné aktivity", systemImage: "figure.walk", description: Text("Klepni na Přidat a vytvoř svůj první záznam."))
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(sorted) { entry in
                                Button {
                                    editing = entry
                                    showingEditor = true
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: entry.symbol)
                                            .font(.title2).frame(width: 46, height: 46)
                                            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.kind).font(.headline)
                                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption).foregroundStyle(.secondary)
                                            if !entry.note.isEmpty { Text(entry.note).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(entry.distance.formatted(.number.precision(.fractionLength(2))) + " km").fontWeight(.semibold)
                                            Text("\(entry.minutes) min · \(entry.calories) kcal")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(14)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    Text("Záznamy jsou zadávané ručně a nepředstavují ověřená měření.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button { editing = nil; showingEditor = true } label: { Image(systemName: "plus") }
            }}
            .sheet(isPresented: $showingEditor) {
                ActivityEditor(entry: editing) { result in
                    if let index = store.entries.firstIndex(where: { $0.id == result.id }) {
                        store.entries[index] = result
                    } else { store.entries.append(result) }
                } onDelete: { id in
                    store.entries.removeAll { $0.id == id }
                }
            }
            .tint(.green)
        }
    }

    private func metric(_ label: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.green).font(.title3)
            Text(value).font(.title3.bold()).minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ActivityEditor: View {
    @Environment(\.dismiss) private var dismiss
    let entry: ActivityEntry?
    let onSave: (ActivityEntry) -> Void
    let onDelete: (UUID) -> Void

    @State private var kind: String
    @State private var date: Date
    @State private var minutes: Int
    @State private var distance: Double
    @State private var calories: Int
    @State private var note: String
    private let kinds = ["Běh", "Chůze", "Cyklistika", "Turistika", "Ostatní"]

    init(entry: ActivityEntry?, onSave: @escaping (ActivityEntry) -> Void, onDelete: @escaping (UUID) -> Void) {
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        _kind = State(initialValue: entry?.kind ?? "Chůze")
        _date = State(initialValue: entry?.date ?? Date())
        _minutes = State(initialValue: entry?.minutes ?? 30)
        _distance = State(initialValue: entry?.distance ?? 2.5)
        _calories = State(initialValue: entry?.calories ?? 150)
        _note = State(initialValue: entry?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Aktivita") {
                    Picker("Typ", selection: $kind) { ForEach(kinds, id: \.self) { Text($0) } }
                    DatePicker("Datum a čas", selection: $date)
                }
                Section("Údaje") {
                    HStack { Text("Délka (min)"); Spacer(); TextField("30", value: $minutes, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Vzdálenost (km)"); Spacer(); TextField("2,5", value: $distance, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Kalorie (kcal)"); Spacer(); TextField("150", value: $calories, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    TextField("Poznámka (volitelné)", text: $note, axis: .vertical)
                }
                if let entry {
                    Section {
                        Button("Smazat aktivitu", role: .destructive) {
                            onDelete(entry.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(entry == nil ? "Nová aktivita" : "Upravit aktivitu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zrušit") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uložit") {
                        onSave(ActivityEntry(id: entry?.id ?? UUID(), kind: kind, date: date, minutes: max(0, minutes), distance: max(0, distance), calories: max(0, calories), note: note))
                        dismiss()
                    }.fontWeight(.bold())
                }
            }
        }
        .tint(.green)
    }
}
