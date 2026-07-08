import SwiftUI

public struct LeafClinicAppRoot: View {
    @StateObject private var store: LeafClinicStore
    @State private var selectedTab: LeafClinicTab = .home
    @State private var draft = LeafIntakeDraft(plantNickname: "Pothos")
    @State private var draftSteps: [CareStep] = []
    @State private var selectedCaseId: PlantCase.ID?
    @State private var showingDeleteConfirmationFor: PlantCase?

    public init(store: LeafClinicStore = LeafClinicStore()) {
        _store = StateObject(wrappedValue: store)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ClinicHomeView(
                    cases: store.activeCases,
                    rescueInsight: store.primaryRescueInsight,
                    errorMessage: store.lastErrorMessage,
                    onStart: {
                        draft = LeafIntakeDraft(plantNickname: "")
                        draftSteps = []
                        selectedTab = .intake
                    },
                    onOpenRescue: { caseId in
                        selectedCaseId = caseId
                        selectedTab = .walkthrough
                    },
                    onCompleteRescueStep: { caseId in
                        do {
                            _ = try store.completeNextRescueStep(caseId: caseId)
                        } catch { }
                    },
                    onSelectCase: { plantCase in
                        selectedCaseId = plantCase.id
                        selectedTab = .walkthrough
                    }
                )
            }
            .tabItem { Label("Clinic", systemImage: "leaf") }
            .tag(LeafClinicTab.home)

            NavigationStack {
                LeafIntakeView(draft: $draft, onBuildPlan: {
                    draftSteps = LocalTriageEngine.recommendSteps(for: draft, caseId: UUID())
                    selectedTab = .triage
                })
            }
            .tabItem { Label("Intake", systemImage: "square.and.pencil") }
            .tag(LeafClinicTab.intake)

            NavigationStack {
                TriageResultView(draft: draft, steps: $draftSteps) {
                    do {
                        let saved = try store.createCase(from: draft, editedSteps: draftSteps.isEmpty ? nil : draftSteps)
                        selectedCaseId = saved.id
                        selectedTab = .walkthrough
                    } catch { }
                }
            }
            .tabItem { Label("Triage", systemImage: "stethoscope") }
            .tag(LeafClinicTab.triage)

            NavigationStack {
                if let plantCase = selectedCase {
                    RecoveryWalkthroughView(plantCase: plantCase, store: store, onRevisit: { selectedTab = .revisit })
                } else {
                    EmptySelectionView(title: "Choose a leaf check", message: "Start or open a case to see the recovery walkthrough.")
                }
            }
            .tabItem { Label("Recovery", systemImage: "checklist") }
            .tag(LeafClinicTab.walkthrough)

            NavigationStack {
                if let plantCase = selectedCase {
                    RevisitCompareView(plantCase: plantCase, store: store)
                } else {
                    EmptySelectionView(title: "No case selected", message: "Open a saved leaf check before adding a revisit note.")
                }
            }
            .tabItem { Label("Revisit", systemImage: "arrow.triangle.2.circlepath") }
            .tag(LeafClinicTab.revisit)

            NavigationStack {
                CaseArchiveView(
                    activeCases: store.activeCases,
                    recoveredCases: store.recoveredCases,
                    premiumEntitlement: store.premiumEntitlement,
                    onOpen: { plantCase in
                        selectedCaseId = plantCase.id
                        selectedTab = .walkthrough
                    },
                    onDelete: { plantCase in showingDeleteConfirmationFor = plantCase }
                )
                .confirmationDialog(
                    "Delete this leaf check?",
                    isPresented: Binding(
                        get: { showingDeleteConfirmationFor != nil },
                        set: { if !$0 { showingDeleteConfirmationFor = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("Cancel", role: .cancel) { showingDeleteConfirmationFor = nil }
                    Button("Delete leaf check", role: .destructive) {
                        if let deleting = showingDeleteConfirmationFor { try? store.deleteCase(id: deleting.id) }
                        showingDeleteConfirmationFor = nil
                    }
                } message: {
                    Text(showingDeleteConfirmationFor.map { "Permanently remove \($0.plantNickname) from this local archive." } ?? "")
                }
            }
            .tabItem { Label("Archive", systemImage: "tray.full") }
            .tag(LeafClinicTab.archive)
        }
        .tint(.leafAccent)
        .accessibilityLabel("Leaf Clinic Walkthrough app")
    }

    private var selectedCase: PlantCase? {
        if let selectedCaseId, let found = store.cases.first(where: { $0.id == selectedCaseId }) { return found }
        return store.cases.first
    }
}

private enum LeafClinicTab: Hashable {
    case home, intake, triage, walkthrough, revisit, archive
}

private struct ClinicHomeView: View {
    let cases: [PlantCase]
    let rescueInsight: LeafRescueInsight?
    let errorMessage: String?
    let onStart: () -> Void
    let onOpenRescue: (PlantCase.ID) -> Void
    let onCompleteRescueStep: (PlantCase.ID) -> Void
    let onSelectCase: (PlantCase) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LeafHeroCard(onStart: onStart)
                if let rescueInsight {
                    RescueFocusCard(
                        insight: rescueInsight,
                        onOpen: { onOpenRescue(rescueInsight.caseId) },
                        onComplete: { onCompleteRescueStep(rescueInsight.caseId) }
                    )
                }
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                if cases.isEmpty {
                    BotanicalEmptyState(onStart: onStart)
                } else {
                    SectionHeader(title: "Today’s leaf checks", subtitle: "Review active cases and continue the seven-day recovery path.")
                    ForEach(cases) { plantCase in
                        Button { onSelectCase(plantCase) } label: {
                            PlantCaseRow(plantCase: plantCase)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.leafBackground.ignoresSafeArea())
        .navigationTitle("Leaf Clinic")
    }
}

private struct RescueFocusCard: View {
    let insight: LeafRescueInsight
    let onOpen: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                SeverityRing(progress: Double(insight.pulseScore) / 100)
                    .frame(width: 74, height: 74)
                    .accessibilityLabel("Rescue pulse score \(insight.pulseScore) percent")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tonight’s Rescue Focus")
                        .font(.headline)
                        .foregroundStyle(Color.leafInk)
                    Text(insight.plantNickname)
                        .font(.title3.bold())
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text(insight.reassuranceCopy)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 10) {
                Button("Open Plan", action: onOpen)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Open rescue plan for \(insight.plantNickname)")
                Button {
                    onComplete()
                } label: {
                    Label("Mark Done", systemImage: "checkmark.circle")
                }
                .buttonStyle(.bordered)
                .disabled(insight.nextStepId == nil)
                .accessibilityLabel("Mark do first action done")
            }
            Divider()
            InsightLine(icon: "checkmark.seal.fill", title: "Do first", copy: insight.nextActionTitle, color: .leafAccent)
            InsightLine(icon: "hand.raised.fill", title: "Avoid tonight", copy: insight.avoidActionTitle, color: .amberWarning)
            InsightLine(icon: "calendar.badge.clock", title: "Revisit cue", copy: insight.revisitCue, color: .leafInk)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.leafCard))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.amberWarning.opacity(0.22)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tonight’s Rescue Focus for \(insight.plantNickname). Do first: \(insight.nextActionTitle). Avoid tonight: \(insight.avoidActionTitle)")
    }
}

private struct InsightLine: View {
    let icon: String
    let title: String
    let copy: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(copy)
                    .font(.callout)
                    .foregroundStyle(Color.leafInk)
            }
        }
    }
}

private struct LeafHeroCard: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                LeafLineArt()
                    .frame(width: 96, height: 96)
                    .accessibilityLabel("Leaf clinic hero illustration")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Turn one stressed leaf into a recovery plan.")
                        .font(.title2.bold())
                        .foregroundStyle(Color.leafInk)
                    Text("Record the symptom, review local suggestions, and revisit the same leaf in seven days.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Button(action: onStart) {
                Label("Start a Leaf Check", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Start a Leaf Check")
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 28).fill(Color.leafCard))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.leafAccent.opacity(0.18)))
    }
}

private struct BotanicalEmptyState: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            LeafLineArt()
                .frame(width: 120, height: 120)
                .accessibilityLabel("Empty leaf archive illustration")
            Text("No leaf checks yet.")
                .font(.title3.bold())
                .foregroundStyle(Color.leafInk)
            Text("Start with the leaf that worries you most. You can save a draft after naming the plant.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Start a Leaf Check", action: onStart)
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Start first leaf check")
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.leafCard.opacity(0.88)))
    }
}

private struct LeafIntakeView: View {
    @Binding var draft: LeafIntakeDraft
    let onBuildPlan: () -> Void
    @FocusState private var focusedField: Field?

    var body: some View {
        Form {
            Section("Plant") {
                TextField("Plant nickname", text: $draft.plantNickname)
                    .focused($focusedField, equals: .nickname)
                    .leafClinicTextInputAutocapitalization()
                    .accessibilityLabel("Plant nickname")
                Text(draft.isComplete ? "Draft ready for triage" : "Unsaved draft: add a plant nickname before saving.")
                    .font(.caption)
                    .foregroundStyle(draft.isComplete ? .green : .orange)
            }
            Section("Leaf symptom") {
                Picker("Symptom", selection: $draft.symptomType) {
                    ForEach(SymptomType.allCases) { symptom in
                        Text(symptom.label).tag(symptom)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Leaf symptom chips")
                VStack(alignment: .leading) {
                    Text("Severity")
                    Slider(value: $draft.severity, in: 0...1) {
                        Text("Leaf symptom severity")
                    }
                    Text("\(Int((draft.severity * 100).rounded()))% stressed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Water, light, and soil clues") {
                TextField("Moisture context", text: $draft.moistureContext, axis: .vertical)
                    .accessibilityLabel("Moisture context")
                TextField("Light context", text: $draft.lightContext, axis: .vertical)
                    .accessibilityLabel("Light context")
                TextField("Soil context", text: $draft.soilContext, axis: .vertical)
                    .accessibilityLabel("Soil context")
                TextField("Leaf note", text: $draft.note, axis: .vertical)
                    .accessibilityLabel("Leaf note")
            }
            Section("Photo placeholder") {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundStyle(Color.leafAccent)
                    Text("Photo stays local. This rough build records a placeholder reference instead of uploading images.")
                }
                .accessibilityLabel("Local photo placeholder")
            }
            Section {
                Button("Review Local Triage", action: onBuildPlan)
                    .disabled(!draft.isComplete)
                    .accessibilityLabel("Review local triage")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil } } }
        .navigationTitle("Leaf Intake")
    }

    private enum Field { case nickname }
}

private struct TriageResultView: View {
    let draft: LeafIntakeDraft
    @Binding var steps: [CareStep]
    let onSave: () -> Void
    @State private var highlightedStepId: CareStep.ID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Review before saving.", subtitle: LocalTriageEngine.confidenceCopy(for: draft))
                OvercorrectionGuardrailCard(copy: LocalTriageEngine.overcorrectionGuardrail(for: draft))
                HStack {
                    ForEach(LocalTriageEngine.reasonChips(for: draft), id: \.self) { chip in
                        Text(chip)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.leafAccent.opacity(0.16)))
                    }
                }
                .accessibilityLabel("Local heuristic reason chips")
                ForEach($steps) { $step in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Day \(step.dueDay)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        TextField("Care action", text: $step.actionTitle, axis: .vertical)
                            .font(.headline)
                            .accessibilityLabel("Editable care action")
                            .onChange(of: step.actionTitle) { _, _ in highlightedStepId = step.id }
                        TextField("Why this helps", text: $step.rationale, axis: .vertical)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Editable care rationale")
                            .onChange(of: step.rationale) { _, _ in highlightedStepId = step.id }
                        Toggle("Skip this step", isOn: $step.isSkipped)
                            .accessibilityLabel("Skip care step")
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(highlightedStepId == step.id ? Color.amberWarning.opacity(0.22) : Color.leafCard))
                }
                Button("Save Recovery Walkthrough", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Save Recovery Walkthrough")
                Text("Recovery plan saved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(20)
        }
        .background(Color.leafBackground.ignoresSafeArea())
        .navigationTitle("Triage Result")
        .onAppear {
            if steps.isEmpty { steps = LocalTriageEngine.recommendSteps(for: draft, caseId: UUID()) }
        }
    }
}


private struct OvercorrectionGuardrailCard: View {
    let copy: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.title3)
                .foregroundStyle(Color.amberWarning)
            VStack(alignment: .leading, spacing: 4) {
                Text("Overcorrection guardrail")
                    .font(.headline)
                    .foregroundStyle(Color.leafInk)
                Text(copy)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.amberWarning.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.amberWarning.opacity(0.22)))
        .accessibilityLabel("Overcorrection guardrail. \(copy)")
    }
}

private struct RecoveryWalkthroughView: View {
    let plantCase: PlantCase
    @ObservedObject var store: LeafClinicStore
    let onRevisit: () -> Void

    var body: some View {
        let insight = LocalTriageEngine.rescueInsight(for: plantCase)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 18) {
                    SeverityRing(progress: plantCase.severity)
                        .frame(width: 92, height: 92)
                        .accessibilityLabel("Seven-day recovery ring")
                    VStack(alignment: .leading) {
                        Text(plantCase.plantNickname)
                            .font(.title2.bold())
                        Text("\(plantCase.symptomType.label) • \(plantCase.status.label)")
                            .foregroundStyle(.secondary)
                        Text("Recovery plan saved.")
                            .font(.caption.bold())
                            .foregroundStyle(Color.leafAccent)
                    }
                }
                RescueRhythmCard(insight: insight)
                CaseDetailEditCard(plantCase: plantCase, store: store)
                    .id(plantCase.id)
                ForEach(plantCase.careSteps) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Button { try? store.toggleStep(caseId: plantCase.id, stepId: step.id) } label: {
                            Image(systemName: step.completedAt == nil ? "circle" : "checkmark.circle.fill")
                                .font(.title3)
                        }
                        .accessibilityLabel(step.completedAt == nil ? "Mark care step complete" : "Mark care step incomplete")
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Day \(step.dueDay)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(step.actionTitle)
                                .font(.headline)
                            Text(step.rationale)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Button(step.isSkipped ? "Use this step" : "Skip step") {
                                try? store.skipStep(caseId: plantCase.id, stepId: step.id)
                            }
                            .font(.caption.bold())
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.leafCard))
                }
                Button("Add Seven-Day Revisit", action: onRevisit)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Add seven-day revisit")
            }
            .padding(20)
        }
        .background(Color.leafBackground.ignoresSafeArea())
        .navigationTitle("Recovery")
    }
}


private struct RescueRhythmCard: View {
    let insight: LeafRescueInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Rescue rhythm", subtitle: insight.rhythmCopy)
            HStack(spacing: 10) {
                RhythmChip(label: "\(insight.pulseScore)% pulse", systemImage: "waveform.path.ecg")
                RhythmChip(label: "One action first", systemImage: "1.circle")
                RhythmChip(label: "Revisit before reset", systemImage: "arrow.triangle.2.circlepath")
            }
            Text(insight.revisitCue)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.leafCard.opacity(0.92)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rescue rhythm. \(insight.rhythmCopy). \(insight.revisitCue)")
    }
}

private struct RhythmChip: View {
    let label: String
    let systemImage: String

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.leafAccent.opacity(0.14)))
            .foregroundStyle(Color.leafInk)
    }
}

private struct CaseDetailEditCard: View {
    let plantCase: PlantCase
    @ObservedObject var store: LeafClinicStore
    @State private var plantNickname: String
    @State private var symptomType: SymptomType
    @State private var severity: Double
    @State private var moistureContext: String
    @State private var lightContext: String
    @State private var soilContext: String
    @State private var note: String
    @State private var saveCopy = "Edit symptom and context, then save changes."

    init(plantCase: PlantCase, store: LeafClinicStore) {
        self.plantCase = plantCase
        self.store = store
        _plantNickname = State(initialValue: plantCase.plantNickname)
        _symptomType = State(initialValue: plantCase.symptomType)
        _severity = State(initialValue: plantCase.severity)
        _moistureContext = State(initialValue: plantCase.snapshot.moistureContext)
        _lightContext = State(initialValue: plantCase.snapshot.lightContext)
        _soilContext = State(initialValue: plantCase.snapshot.soilContext)
        _note = State(initialValue: plantCase.snapshot.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Edit case details", subtitle: "Update the plant, symptom, and context without losing the saved recovery path.")
            TextField("Plant nickname", text: $plantNickname)
                .leafClinicTextInputAutocapitalization()
                .accessibilityLabel("Edit plant nickname")
            Picker("Symptom", selection: $symptomType) {
                ForEach(SymptomType.allCases) { symptom in
                    Text(symptom.label).tag(symptom)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Edit leaf symptom")
            VStack(alignment: .leading) {
                Text("Severity")
                Slider(value: $severity, in: 0...1) { Text("Edit leaf severity") }
                Text("\(Int((severity * 100).rounded()))% stressed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField("Moisture context", text: $moistureContext, axis: .vertical)
                .accessibilityLabel("Edit moisture context")
            TextField("Light context", text: $lightContext, axis: .vertical)
                .accessibilityLabel("Edit light context")
            TextField("Soil context", text: $soilContext, axis: .vertical)
                .accessibilityLabel("Edit soil context")
            TextField("Leaf note", text: $note, axis: .vertical)
                .accessibilityLabel("Edit leaf note")
            Button("Save Case Changes", action: saveChanges)
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Save case changes")
            Text(saveCopy)
                .font(.caption)
                .foregroundStyle(saveCopy == "Case changes saved." ? Color.leafAccent : .secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.leafCard.opacity(0.92)))
    }

    private func saveChanges() {
        var updated = plantCase
        updated.plantNickname = plantNickname
        updated.symptomType = symptomType
        updated.severity = severity
        updated.snapshot.moistureContext = moistureContext
        updated.snapshot.lightContext = lightContext
        updated.snapshot.soilContext = soilContext
        updated.snapshot.note = note
        do {
            try store.updateCase(updated)
            saveCopy = "Case changes saved."
        } catch {
            saveCopy = store.lastErrorMessage ?? "The case could not be saved. Check the plant nickname and try again."
        }
    }
}

private struct RevisitCompareView: View {
    let plantCase: PlantCase
    @ObservedObject var store: LeafClinicStore
    @State private var afterStatus = "Leaf edge is less yellow and firmer than day one."
    @State private var decision: RevisitDecision = .watch
    @State private var note = "Keep indirect light and check soil again in two days."

    var body: some View {
        Form {
            Section("Before") {
                Text(plantCase.snapshot.note.isEmpty ? "No starting note was recorded." : plantCase.snapshot.note)
                Text("Original symptom: \(plantCase.symptomType.label)")
            }
            Section("After") {
                TextField("After status", text: $afterStatus, axis: .vertical)
                    .accessibilityLabel("After leaf status")
                Picker("Decision", selection: $decision) {
                    ForEach(RevisitDecision.allCases) { decision in Text(decision.label).tag(decision) }
                }
                RevisitGuidanceCard(guidance: LocalTriageEngine.revisitGuidance(afterStatus: afterStatus, decision: decision))
                TextField("Next care note", text: $note, axis: .vertical)
                    .accessibilityLabel("Next care note")
                Button("Save Revisit Note") {
                    try? store.addRevisitNote(caseId: plantCase.id, afterStatus: afterStatus, decision: decision, note: note)
                }
                .accessibilityLabel("Save Revisit Note")
            }
        }
        .navigationTitle("Revisit Compare")
    }
}

private struct RevisitGuidanceCard: View {
    let guidance: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Before/after read", systemImage: "leaf.arrow.triangle.circlepath")
                .font(.headline)
            Text(guidance)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .accessibilityLabel("Before and after guidance. \(guidance)")
    }
}

private struct CaseArchiveView: View {
    let activeCases: [PlantCase]
    let recoveredCases: [PlantCase]
    let premiumEntitlement: PremiumEntitlement
    let onOpen: (PlantCase) -> Void
    let onDelete: (PlantCase) -> Void

    var body: some View {
        List {
            Section("Active") {
                ForEach(activeCases) { plantCase in ArchiveRow(plantCase: plantCase, onOpen: onOpen, onDelete: onDelete) }
            }
            Section("Recovered") {
                ForEach(recoveredCases) { plantCase in ArchiveRow(plantCase: plantCase, onOpen: onOpen, onDelete: onDelete) }
            }
            Section("Premium and privacy") {
                PremiumPrivacyCard(entitlement: premiumEntitlement)
            }
        }
        .navigationTitle("Case Archive")
        .accessibilityLabel("Case Archive and Premium")
    }
}

private struct ArchiveRow: View {
    let plantCase: PlantCase
    let onOpen: (PlantCase) -> Void
    let onDelete: (PlantCase) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(plantCase.plantNickname).font(.headline)
                Text("\(plantCase.symptomType.label) • \(plantCase.careSteps.count) care steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open") { onOpen(plantCase) }
            Button("Delete", role: .destructive) { onDelete(plantCase) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Leaf check for \(plantCase.plantNickname)")
    }
}

private struct PremiumPrivacyCard: View {
    let entitlement: PremiumEntitlement

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Premium case history", systemImage: "crown")
                .font(.headline)
            Text("Premium will unlock more active cases, revisit trends, and custom care templates.")
            Text(entitlement.storeKitUnavailableReason ?? "Premium is ready.")
                .font(.caption)
                .foregroundStyle(.orange)
            Divider()
            Label("Local privacy boundary", systemImage: "lock.shield")
                .font(.headline)
            Text("Plant photos and notes stay on this device by default. No network upload is used in this version. Future cloud or Kimi help must be opt-in before anything leaves the app.")
                .font(.callout)
        }
        .accessibilityLabel("Premium unavailable and local privacy notice")
    }
}

private struct PlantCaseRow: View {
    let plantCase: PlantCase

    var body: some View {
        HStack(spacing: 14) {
            SeverityRing(progress: plantCase.severity)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text(plantCase.plantNickname)
                    .font(.headline)
                Text("\(plantCase.symptomType.label) • Day \(plantCase.careSteps.map(\.dueDay).max() ?? 1) path")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.leafCard))
        .accessibilityLabel("Open recovery walkthrough for \(plantCase.plantNickname)")
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(Color.amberWarning)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.amberWarning.opacity(0.12)))
            .accessibilityLabel("Recoverable save problem: \(message)")
    }
}

private struct EmptySelectionView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            LeafLineArt().frame(width: 100, height: 100)
            Text(title).font(.title3.bold())
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.leafBackground)
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.bold()).foregroundStyle(Color.leafInk)
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
    }
}

private struct LeafLineArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [.leafAccent.opacity(0.22), .creamCard], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "leaf.fill")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(Color.leafAccent)
            Image(systemName: "line.diagonal")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

private struct SeverityRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.leafAccent.opacity(0.18), lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0.05, min(progress, 1)))
                .stroke(Color.amberWarning, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((progress * 100).rounded()))%")
                .font(.caption.bold())
                .foregroundStyle(Color.leafInk)
        }
    }
}

private extension Color {
    static let leafBackground = Color(red: 0.93, green: 0.95, blue: 0.88)
    static let leafCard = Color(red: 1.0, green: 0.98, blue: 0.91)
    static let creamCard = Color(red: 1.0, green: 0.96, blue: 0.84)
    static let leafAccent = Color(red: 0.22, green: 0.48, blue: 0.34)
    static let leafInk = Color(red: 0.12, green: 0.19, blue: 0.15)
    static let amberWarning = Color(red: 0.82, green: 0.46, blue: 0.16)
}
private extension View {
    @ViewBuilder
    func leafClinicTextInputAutocapitalization() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.words)
        #else
        self
        #endif
    }
}
