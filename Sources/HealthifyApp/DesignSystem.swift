import SwiftUI
import UIKit
import HealthifyCore

// House motion, translated from the Apple-design skill into native SwiftUI:
// critically-damped springs by default; bounce only for flick-driven motion;
// reduced-motion users get short cross-fades instead of springs.

// MARK: - Animation presets

extension Animation {
    /// Critically damped default. No overshoot, graceful settle.
    static var uiSpring: Animation {
        .spring(response: 0.35, dampingFraction: 1.0)
    }
    /// Only for momentum-driven motion (flicks, throws, drag releases).
    static var uiFlick: Animation {
        .spring(response: 0.3, dampingFraction: 0.8)
    }
    /// Press feedback and other instant-feeling transitions.
    static var uiQuick: Animation {
        .spring(response: 0.2, dampingFraction: 1.0)
    }
}

/// Reduced-motion-aware animation picker. Springs become fades.
enum Motion {
    static func adaptive(_ base: Animation = .uiSpring,
                         reduce: Bool) -> Animation {
        reduce ? .easeOut(duration: 0.2) : base
    }
}

// MARK: - Press feedback (respond on press-down, never only at the end)

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.body
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.uiQuick, value: configuration.isPressed)
    }
}

// MARK: - Haptics (fire on the causal frame, only where earned)

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func commit() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Surfaces

/// Translucent floating layer; content scrolls underneath, never an opaque bar.
struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Ring + bars

struct RingView: View {
    var progress: Double
    var size: CGFloat = 128
    var center: String
    var caption: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Color.accentColor.gradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.adaptive(reduce: reduceMotion),
                           value: progress)
            VStack(spacing: 0) {
                Text(center).font(.title2.bold())
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct MacroBar: View {
    var label: String
    var grams: Double
    var target: Double
    var unit = "g"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(fmt(grams)) / \(fmt(target))\(unit)")
                    .font(.caption).monospacedDigit()
            }
            GeometryReader { geo in
                Capsule().fill(.quaternary)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color.accentColor)
                            .frame(width: geo.size.width
                                * min(grams / max(target, 1), 1))
                    }
            }
            .frame(height: 6)
            .animation(Motion.adaptive(reduce: reduceMotion), value: grams)
        }
    }
}

// MARK: - Small helpers

func fmt(_ v: Double, _ digits: Int = 0) -> String {
    String(format: "%.\(digits)f", v)
}

/// Full exercise library: bundled seeds plus the user's own.
func libraryExercises(custom: [Exercise]) -> [Exercise] {
    custom + seedExercises
}

func foodLookup(custom: [FoodItem]) -> [UUID: FoodItem] {
    Dictionary(uniqueKeysWithValues: (seedFoods + custom).map { ($0.id, $0) })
}
