import Foundation

public enum LocalTriageEngine {
    public static func reasonChips(for draft: LeafIntakeDraft) -> [String] {
        var chips = [draft.symptomType.label]
        if draft.moistureContext.localizedCaseInsensitiveContains("damp") { chips.append("Moisture risk") }
        if draft.lightContext.localizedCaseInsensitiveContains("bright") { chips.append("Light shift") }
        if draft.soilContext.localizedCaseInsensitiveContains("smell") { chips.append("Soil check") }
        return chips
    }

    public static func confidenceCopy(for draft: LeafIntakeDraft) -> String {
        let severity = Int((draft.severity * 100).rounded())
        return "Local suggestion, not a professional diagnosis. Confidence is based on the \(severity)% severity entry and your moisture, light, and soil notes."
    }

    public static func recommendSteps(for draft: LeafIntakeDraft, caseId: UUID) -> [CareStep] {
        var steps: [CareStep] = []
        switch draft.symptomType {
        case .yellowEdges:
            steps.append(CareStep(caseId: caseId, actionTitle: "Pause watering for two days", rationale: "Yellow edges with damp soil often improve when roots get more air.", dueDay: 1))
            steps.append(CareStep(caseId: caseId, actionTitle: "Move to bright indirect light", rationale: "A softer light reset reduces stress while the leaf recovers.", dueDay: 2))
        case .drooping:
            steps.append(CareStep(caseId: caseId, actionTitle: "Check pot weight before watering", rationale: "Droop can mean both thirst and overwatering; pot weight helps avoid guessing.", dueDay: 1))
            steps.append(CareStep(caseId: caseId, actionTitle: "Lift leaves away from cold glass", rationale: "Drooping leaves near a window may be reacting to temperature swings.", dueDay: 3))
        case .curling:
            steps.append(CareStep(caseId: caseId, actionTitle: "Raise humidity around the plant", rationale: "Curling often appears when the leaf loses moisture faster than roots can replace it.", dueDay: 1))
            steps.append(CareStep(caseId: caseId, actionTitle: "Inspect the underside for pests", rationale: "Curling can hide early pest pressure, especially on tender leaves.", dueDay: 2))
        case .spots:
            steps.append(CareStep(caseId: caseId, actionTitle: "Keep spotted leaves dry", rationale: "Dry leaves reduce spread while you watch whether spots expand.", dueDay: 1))
            steps.append(CareStep(caseId: caseId, actionTitle: "Isolate tools and wipe shears", rationale: "Clean tools reduce accidental transfer between leaves.", dueDay: 3))
        }
        steps.append(CareStep(caseId: caseId, actionTitle: "Take a seven-day revisit note", rationale: "Compare the same leaf before changing the plan again.", dueDay: 7))
        return steps
    }
}
