import Foundation

public enum SymptomType: String, Codable, CaseIterable, Identifiable, Sendable {
    case yellowEdges
    case drooping
    case curling
    case spots

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .yellowEdges: "Yellow edges"
        case .drooping: "Drooping"
        case .curling: "Curling"
        case .spots: "Spots"
        }
    }
}

public enum PlantCaseStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case active
    case revisitDue
    case recovered
    case archived

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .active: "Active"
        case .revisitDue: "Revisit due"
        case .recovered: "Recovered"
        case .archived: "Archived"
        }
    }
}

public enum RevisitDecision: String, Codable, CaseIterable, Identifiable, Sendable {
    case recovered
    case watch
    case escalate

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .recovered: "Recovered"
        case .watch: "Keep watching"
        case .escalate: "Escalate care"
        }
    }
}

public struct LeafSymptomSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var caseId: UUID
    public var moistureContext: String
    public var lightContext: String
    public var soilContext: String
    public var photoPlaceholderRef: String
    public var note: String

    public init(
        id: UUID = UUID(),
        caseId: UUID,
        moistureContext: String,
        lightContext: String,
        soilContext: String,
        photoPlaceholderRef: String,
        note: String
    ) {
        self.id = id
        self.caseId = caseId
        self.moistureContext = moistureContext
        self.lightContext = lightContext
        self.soilContext = soilContext
        self.photoPlaceholderRef = photoPlaceholderRef
        self.note = note
    }
}

public struct CareStep: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var caseId: UUID
    public var actionTitle: String
    public var rationale: String
    public var dueDay: Int
    public var completedAt: Date?
    public var isSkipped: Bool

    public init(
        id: UUID = UUID(),
        caseId: UUID,
        actionTitle: String,
        rationale: String,
        dueDay: Int,
        completedAt: Date? = nil,
        isSkipped: Bool = false
    ) {
        self.id = id
        self.caseId = caseId
        self.actionTitle = actionTitle
        self.rationale = rationale
        self.dueDay = dueDay
        self.completedAt = completedAt
        self.isSkipped = isSkipped
    }
}

public struct RevisitNote: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var caseId: UUID
    public var afterStatus: String
    public var userDecision: RevisitDecision
    public var note: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        caseId: UUID,
        afterStatus: String,
        userDecision: RevisitDecision,
        note: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.caseId = caseId
        self.afterStatus = afterStatus
        self.userDecision = userDecision
        self.note = note
        self.createdAt = createdAt
    }
}

public struct PremiumEntitlement: Codable, Equatable, Sendable {
    public var isPremiumUnlocked: Bool
    public var productIds: [String]
    public var storeKitUnavailableReason: String?

    public init(
        isPremiumUnlocked: Bool = false,
        productIds: [String] = ["leafclinic.premium.monthly", "leafclinic.premium.yearly"],
        storeKitUnavailableReason: String? = "StoreKit products are not configured for this rough build. Premium remains unavailable until App Store Connect evidence is supplied."
    ) {
        self.isPremiumUnlocked = isPremiumUnlocked
        self.productIds = productIds
        self.storeKitUnavailableReason = storeKitUnavailableReason
    }
}

public struct PlantCase: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var plantNickname: String
    public var symptomType: SymptomType
    public var severity: Double
    public var createdAt: Date
    public var status: PlantCaseStatus
    public var snapshot: LeafSymptomSnapshot
    public var careSteps: [CareStep]
    public var revisitNotes: [RevisitNote]

    public init(
        id: UUID = UUID(),
        plantNickname: String,
        symptomType: SymptomType,
        severity: Double,
        createdAt: Date = Date(),
        status: PlantCaseStatus = .active,
        snapshot: LeafSymptomSnapshot? = nil,
        careSteps: [CareStep] = [],
        revisitNotes: [RevisitNote] = []
    ) {
        self.id = id
        self.plantNickname = plantNickname
        self.symptomType = symptomType
        self.severity = severity
        self.createdAt = createdAt
        self.status = status
        self.snapshot = snapshot ?? LeafSymptomSnapshot(
            caseId: id,
            moistureContext: "Not recorded yet",
            lightContext: "Not recorded yet",
            soilContext: "Not recorded yet",
            photoPlaceholderRef: "leaf-photo-placeholder",
            note: ""
        )
        self.careSteps = careSteps
        self.revisitNotes = revisitNotes
    }
}

public struct LeafIntakeDraft: Equatable, Sendable {
    public var plantNickname: String
    public var symptomType: SymptomType
    public var severity: Double
    public var moistureContext: String
    public var lightContext: String
    public var soilContext: String
    public var photoPlaceholderRef: String
    public var note: String

    public init(
        plantNickname: String = "",
        symptomType: SymptomType = .yellowEdges,
        severity: Double = 0.45,
        moistureContext: String = "Soil feels damp near the surface",
        lightContext: String = "Moved closer to a bright window this week",
        soilContext: String = "No sour smell detected",
        photoPlaceholderRef: String = "warm-leaf-card-placeholder",
        note: String = "Yellowing starts at the oldest leaf edge."
    ) {
        self.plantNickname = plantNickname
        self.symptomType = symptomType
        self.severity = severity
        self.moistureContext = moistureContext
        self.lightContext = lightContext
        self.soilContext = soilContext
        self.photoPlaceholderRef = photoPlaceholderRef
        self.note = note
    }

    public var isComplete: Bool { !plantNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
