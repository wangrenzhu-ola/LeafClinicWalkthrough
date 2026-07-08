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

    public static func overcorrectionGuardrail(for draft: LeafIntakeDraft) -> String {
        switch draft.symptomType {
        case .yellowEdges:
            "Do not add fertilizer tonight. First protect the roots from extra water and watch the same leaf for two days."
        case .drooping:
            "Do not water on autopilot. Check pot weight and leaf position before changing the care rhythm."
        case .curling:
            "Do not prune the curled leaf yet. Stabilize humidity and inspect the underside before removing growth."
        case .spots:
            "Do not mist spotted leaves. Keep the surface dry and isolate tools while you watch for spread."
        }
    }

    public static func rescueInsight(for plantCase: PlantCase) -> LeafRescueInsight {
        let actionableSteps = plantCase.careSteps
            .filter { $0.completedAt == nil && !$0.isSkipped }
            .sorted { $0.dueDay < $1.dueDay }
        let completedCount = plantCase.careSteps.filter { $0.completedAt != nil }.count
        let skippedCount = plantCase.careSteps.filter(\.isSkipped).count
        let nextStep = actionableSteps.first ?? plantCase.careSteps.sorted { $0.dueDay < $1.dueDay }.last
        let pulseScore = min(100, max(12, Int((plantCase.severity * 72).rounded()) + completedCount * 9 - skippedCount * 4))
        let rhythmCopy: String
        if completedCount == 0 && skippedCount == 0 {
            rhythmCopy = "Start with one safe care move before changing water, light, and soil at the same time."
        } else if skippedCount > 0 {
            rhythmCopy = "\(completedCount) done · \(skippedCount) skipped. The plan is still useful because skipped steps are explicit."
        } else {
            rhythmCopy = "\(completedCount) completed. Keep the rhythm steady until the seven-day revisit."
        }

        return LeafRescueInsight(
            caseId: plantCase.id,
            nextStepId: nextStep?.id,
            plantNickname: plantCase.plantNickname,
            pulseScore: pulseScore,
            nextActionTitle: nextStep?.actionTitle ?? "Record one calm leaf observation",
            avoidActionTitle: avoidAction(for: plantCase.symptomType),
            reassuranceCopy: reassurance(for: plantCase),
            rhythmCopy: rhythmCopy,
            revisitCue: revisitCue(for: plantCase)
        )
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

    public static func revisitGuidance(afterStatus: String, decision: RevisitDecision) -> String {
        let status = afterStatus.lowercased()
        switch decision {
        case .recovered:
            return "Keep the winning rhythm for one more week before adding new care experiments."
        case .watch:
            if status.contains("worse") || status.contains("yellow") || status.contains("soft") {
                return "Stay with the safest step and compare the same leaf again in two days."
            }
            return "Hold the current routine and look for one visible change before adjusting again."
        case .escalate:
            return "Escalate carefully: isolate the plant, avoid fertilizer, and consider expert help if spread continues."
        }
    }

    private static func avoidAction(for symptom: SymptomType) -> String {
        switch symptom {
        case .yellowEdges: "Avoid fertilizer or a big watering change tonight."
        case .drooping: "Avoid guessing with extra water until pot weight is checked."
        case .curling: "Avoid pruning before humidity and pest checks are complete."
        case .spots: "Avoid misting or touching other plants with the same tools."
        }
    }

    private static func reassurance(for plantCase: PlantCase) -> String {
        switch plantCase.severity {
        case 0..<0.35:
            "This looks like a low-pressure check. A light touch is safer than a dramatic reset."
        case 0.35..<0.7:
            "This is a medium-pressure rescue. One consistent action tonight matters more than doing everything."
        default:
            "This is a high-pressure case. Slow down, isolate risky variables, and follow the plan step by step."
        }
    }

    private static func revisitCue(for plantCase: PlantCase) -> String {
        if plantCase.status == .revisitDue || plantCase.careSteps.contains(where: { $0.dueDay >= 7 }) {
            "Compare the same leaf at day seven before changing the plan again."
        } else {
            "Save one after-note when the leaf feels firmer, flatter, or less yellow."
        }
    }
}
