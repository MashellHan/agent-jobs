import Foundation

final class TipsService {
    static let shared = TipsService()

    private let allTips: [EyeCareTip]
    private var shownTipIDs: Set<String> = []
    private var lastTipIndex: Int = -1

    init() {
        allTips = Self.loadAllTips()
    }

    // MARK: - Public API

    /// Get next tip, rotating through all tips and avoiding recent repeats.
    func nextTip() -> EyeCareTip {
        let availableTips = allTips.filter { !shownTipIDs.contains($0.id) }

        // Reset shown set if we've cycled through all tips
        if availableTips.isEmpty {
            shownTipIDs.removeAll()
            return pickRandom(from: allTips)
        }

        return pickRandom(from: availableTips)
    }

    /// Get a contextual tip based on current hour and eye health score.
    func contextualTip(hour: Int, score: Int) -> EyeCareTip {
        let preferredCategory: EyeCareTip.TipCategory

        switch (hour, score) {
        // Late night — rest and lighting tips
        case (22...23, _), (0...5, _):
            preferredCategory = .rest
        // Morning — posture and environment setup
        case (6...9, _):
            preferredCategory = .posture
        // Mid-morning — exercise and hydration
        case (10...11, _):
            preferredCategory = Bool.random() ? .exercise : .hydration
        // Lunch time — nutrition tips
        case (12...13, _):
            preferredCategory = .nutrition
        // Afternoon — varies by score
        case (14...17, 0..<60):
            preferredCategory = .rest
        case (14...17, 60..<80):
            preferredCategory = .exercise
        case (14...17, _):
            preferredCategory = .hydration
        // Evening — lighting and rest
        case (18...21, _):
            preferredCategory = .lighting
        default:
            preferredCategory = EyeCareTip.TipCategory.allCases.randomElement() ?? .rest
        }

        let categoryTips = tips(for: preferredCategory)
        let available = categoryTips.filter { !shownTipIDs.contains($0.id) }

        if available.isEmpty {
            // Fall back to any tip if category exhausted
            return nextTip()
        }

        return pickRandom(from: available)
    }

    /// All tips for a specific category.
    func tips(for category: EyeCareTip.TipCategory) -> [EyeCareTip] {
        allTips.filter { $0.category == category }
    }

    /// Get a random tip without tracking (for display-only contexts like menu).
    func randomTip() -> EyeCareTip {
        allTips.randomElement() ?? allTips[0]
    }

    /// Total number of tips available.
    var tipCount: Int { allTips.count }

    // MARK: - Private

    private func pickRandom(from tips: [EyeCareTip]) -> EyeCareTip {
        guard let tip = tips.randomElement() else {
            return allTips[0]
        }
        shownTipIDs.insert(tip.id)
        return tip
    }

    // MARK: - Tip Library

    private static func loadAllTips() -> [EyeCareTip] {
        var tips: [EyeCareTip] = []

        // ── Hydration (5 tips) ──

        tips.append(EyeCareTip(
            id: "hydration-01",
            category: .hydration,
            title: "Blink Consciously",
            content: "Your blink rate drops 60% during screen use. Try 5 deliberate blinks every 5 minutes.",
            source: "AAO",
            icon: "eye"
        ))
        tips.append(EyeCareTip(
            id: "hydration-02",
            category: .hydration,
            title: "Keep Eye Drops Nearby",
            content: "Preservative-free artificial tears can relieve dry eyes from prolonged screen use.",
            source: "Mayo Clinic",
            icon: "drop.fill"
        ))
        tips.append(EyeCareTip(
            id: "hydration-03",
            category: .hydration,
            title: "Stay Hydrated",
            content: "Drink 8 glasses of water daily. Dehydration worsens dry eye symptoms significantly.",
            source: "NHS",
            icon: "cup.and.saucer.fill"
        ))
        tips.append(EyeCareTip(
            id: "hydration-04",
            category: .hydration,
            title: "Use a Humidifier",
            content: "If your room humidity is below 40%, use a humidifier. Dry air increases tear evaporation.",
            source: "AAO",
            icon: "humidity.fill"
        ))
        tips.append(EyeCareTip(
            id: "hydration-05",
            category: .hydration,
            title: "Avoid Direct Airflow",
            content: "Don't let fans or AC blow directly on your face — it accelerates tear evaporation.",
            source: "AOA",
            icon: "wind"
        ))

        // ── Exercise (5 tips) ──

        tips.append(EyeCareTip(
            id: "exercise-01",
            category: .exercise,
            title: "Try Palming",
            content: "Cover your eyes with warm palms for 30 seconds. The warmth relaxes eye muscles and reduces strain.",
            source: "Ophthalmology journals",
            icon: "hand.raised.fill"
        ))
        tips.append(EyeCareTip(
            id: "exercise-02",
            category: .exercise,
            title: "Eye Rolling",
            content: "Slowly roll your eyes in a circle — 5 times clockwise, then 5 times counter-clockwise.",
            source: "Vision therapy",
            icon: "arrow.clockwise"
        ))
        tips.append(EyeCareTip(
            id: "exercise-03",
            category: .exercise,
            title: "Near-Far Focus",
            content: "Hold a pen at arm's length, focus 10s, then look far away 10s. Repeat 5 times to exercise focus muscles.",
            source: "AOA",
            icon: "arrow.left.and.right"
        ))
        tips.append(EyeCareTip(
            id: "exercise-04",
            category: .exercise,
            title: "Figure-8 Tracing",
            content: "Imagine a giant figure-8 on the floor 10 feet away. Trace it with your eyes for 30 seconds.",
            source: "AAO",
            icon: "infinity"
        ))
        tips.append(EyeCareTip(
            id: "exercise-05",
            category: .exercise,
            title: "Temple Massage",
            content: "Gently massage your temples in circular motions for 20 seconds to relieve eye tension.",
            source: "Traditional Chinese Medicine",
            icon: "hands.sparkles.fill"
        ))

        // ── Posture (5 tips) ──

        tips.append(EyeCareTip(
            id: "posture-01",
            category: .posture,
            title: "Arm's Length Distance",
            content: "Your screen should be an arm's length away (20-26 inches) and 15-20 degrees below eye level.",
            source: "AAO",
            icon: "desktopcomputer"
        ))
        tips.append(EyeCareTip(
            id: "posture-02",
            category: .posture,
            title: "Sit Up Straight",
            content: "Forward head posture strains your neck and increases eye fatigue. Keep your back against the chair.",
            source: "Ergonomics research",
            icon: "figure.stand"
        ))
        tips.append(EyeCareTip(
            id: "posture-03",
            category: .posture,
            title: "Tilt Screen Back",
            content: "Tilt your screen slightly back (10-15 degrees) to reduce glare and maintain proper viewing angle.",
            source: "OSHA guidelines",
            icon: "rectangle.landscape.rotate"
        ))
        tips.append(EyeCareTip(
            id: "posture-04",
            category: .posture,
            title: "Align Keyboard & Eyes",
            content: "Position your keyboard so forearms are parallel to the floor — this naturally aligns head and eyes.",
            source: "Ergonomics",
            icon: "keyboard"
        ))
        tips.append(EyeCareTip(
            id: "posture-05",
            category: .posture,
            title: "Bifocal Monitor Height",
            content: "If you wear bifocals, lower your monitor so you look through the reading portion without tilting your head.",
            source: "AOA",
            icon: "eyeglasses"
        ))

        // ── Lighting (5 tips) ──

        tips.append(EyeCareTip(
            id: "lighting-01",
            category: .lighting,
            title: "Match Screen Brightness",
            content: "Match your screen brightness to ambient light. If your screen looks like a light source, it's too bright.",
            source: "AAO",
            icon: "sun.max.fill"
        ))
        tips.append(EyeCareTip(
            id: "lighting-02",
            category: .lighting,
            title: "Use Indirect Lighting",
            content: "Avoid having a window directly behind or in front of your screen. Side lighting reduces glare.",
            source: "OSHA",
            icon: "light.recessed"
        ))
        tips.append(EyeCareTip(
            id: "lighting-03",
            category: .lighting,
            title: "Reduce Room Brightness",
            content: "Ideal room illumination for computer work is half as bright as typical office lighting.",
            source: "Ergonomics studies",
            icon: "light.min"
        ))
        tips.append(EyeCareTip(
            id: "lighting-04",
            category: .lighting,
            title: "Warm Desk Lamps",
            content: "Reduce overhead fluorescent lighting. Desk lamps with warm bulbs are much easier on the eyes.",
            source: "Vision Council",
            icon: "lamp.desk.fill"
        ))
        tips.append(EyeCareTip(
            id: "lighting-05",
            category: .lighting,
            title: "Dark Mode at Night",
            content: "Enable Dark Mode at night — bright interfaces in dark rooms force your pupils to constantly adjust.",
            source: "Sleep research",
            icon: "moon.stars.fill"
        ))

        // ── Nutrition (5 tips) ──

        tips.append(EyeCareTip(
            id: "nutrition-01",
            category: .nutrition,
            title: "Eat Leafy Greens",
            content: "Spinach and kale contain lutein and zeaxanthin, which protect the retina from blue light damage.",
            source: "AAO",
            icon: "leaf.fill"
        ))
        tips.append(EyeCareTip(
            id: "nutrition-02",
            category: .nutrition,
            title: "Omega-3 Fatty Acids",
            content: "Salmon, walnuts, and flaxseed help maintain the oily layer of your tear film, preventing dry eyes.",
            source: "NEI",
            icon: "fish.fill"
        ))
        tips.append(EyeCareTip(
            id: "nutrition-03",
            category: .nutrition,
            title: "Vitamin A Foods",
            content: "Carrots, sweet potatoes, and eggs provide vitamin A that supports eye health and night vision.",
            source: "WHO",
            icon: "carrot.fill"
        ))
        tips.append(EyeCareTip(
            id: "nutrition-04",
            category: .nutrition,
            title: "Blueberries for Eyes",
            content: "Blueberries contain anthocyanins that may improve night vision and reduce eye fatigue.",
            source: "Nutrition research",
            icon: "circle.fill"
        ))
        tips.append(EyeCareTip(
            id: "nutrition-05",
            category: .nutrition,
            title: "Zinc-Rich Foods",
            content: "Zinc from oysters, beef, and pumpkin seeds helps vitamin A travel from your liver to your retina.",
            source: "NEI",
            icon: "bolt.fill"
        ))

        // ── Rest (5 tips) ──

        tips.append(EyeCareTip(
            id: "rest-01",
            category: .rest,
            title: "Look Out the Window",
            content: "During breaks, look at distant objects outside. Natural scenery is the most relaxing for your eyes.",
            source: "Nature research",
            icon: "cloud.sun.fill"
        ))
        tips.append(EyeCareTip(
            id: "rest-02",
            category: .rest,
            title: "Close Your Eyes",
            content: "Close your eyes completely for 20 seconds — this gives your cornea a full moisture coating.",
            source: "Ophthalmology",
            icon: "eye.slash.fill"
        ))
        tips.append(EyeCareTip(
            id: "rest-03",
            category: .rest,
            title: "Deliberate Yawning",
            content: "Yawning deliberately during breaks increases tear production and relaxes facial muscles.",
            source: "Physiology",
            icon: "face.smiling"
        ))
        tips.append(EyeCareTip(
            id: "rest-04",
            category: .rest,
            title: "Stand Up and Stretch",
            content: "Stand up and stretch during long breaks. Poor circulation worsens eye strain significantly.",
            source: "OSHA",
            icon: "figure.arms.open"
        ))
        tips.append(EyeCareTip(
            id: "rest-05",
            category: .rest,
            title: "No Phone During Breaks",
            content: "Don't switch to your phone during eye breaks — that's still near-focus screen time!",
            source: "AAO",
            icon: "iphone.slash"
        ))

        // ── Environment (5 tips) ──

        tips.append(EyeCareTip(
            id: "environment-01",
            category: .environment,
            title: "Monitor Room Humidity",
            content: "Keep room humidity between 40-60%. Use a hygrometer to check — dry air causes eye irritation.",
            source: "AAO",
            icon: "humidity.fill"
        ))
        tips.append(EyeCareTip(
            id: "environment-02",
            category: .environment,
            title: "Clean Your Screen",
            content: "Dust and smudges on your screen cause glare and force your eyes to work harder to focus.",
            source: "Vision Council",
            icon: "sparkles"
        ))
        tips.append(EyeCareTip(
            id: "environment-03",
            category: .environment,
            title: "Plants Improve Air",
            content: "Indoor plants increase humidity and air quality, reducing eye dryness and irritation.",
            source: "NASA Clean Air Study",
            icon: "leaf.arrow.triangle.circlepath"
        ))
        tips.append(EyeCareTip(
            id: "environment-04",
            category: .environment,
            title: "Anti-Glare Screen",
            content: "Consider an anti-glare screen filter if you can't control the lighting in your workspace.",
            source: "AOA",
            icon: "rectangle.on.rectangle"
        ))
        tips.append(EyeCareTip(
            id: "environment-05",
            category: .environment,
            title: "Blue Light Filters",
            content: "Use built-in blue light filters (Night Shift / Night Light) especially in the evening hours.",
            source: "Sleep Foundation",
            icon: "shield.fill"
        ))

        return tips
    }
}
