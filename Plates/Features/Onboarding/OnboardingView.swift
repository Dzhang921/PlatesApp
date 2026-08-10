import SwiftUI

/// Three-page welcome flow shown on first launch: the lit-up globe, the receipt
/// as proof of visit, and the lifetime Michelin star count. `onDone` is called
/// when the user finishes or skips.
struct OnboardingView: View {
    private let onDone: () -> Void

    init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }

    @State private var selection = 0
    private let pageCount = 3

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $selection) {
                    OnboardingPageScaffold(
                        isActive: selection == 0,
                        headline: "Every meal, collected.",
                        message: "Plates turns the restaurants you visit into a collection. Your world map lights up, one meal at a time."
                    ) { revealed in
                        OnboardingGlobeMotif(revealed: revealed)
                    }
                    .tag(0)

                    OnboardingPageScaffold(
                        isActive: selection == 1,
                        headline: "The receipt is the proof.",
                        message: "Scan the receipt at the table. Plates reads it, finds the restaurant, and adds it to your collection — all on your iPhone."
                    ) { revealed in
                        OnboardingReceiptMotif(revealed: revealed)
                    }
                    .tag(1)

                    OnboardingPageScaffold(
                        isActive: selection == 2,
                        headline: "Michelin stars, yours now.",
                        message: "Eat at a starred restaurant and its stars join your lifetime count. How many can you collect?"
                    ) { revealed in
                        OnboardingStarsMotif(revealed: revealed)
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.top, 6)

                controls
                    .padding(.top, 26)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 18)
            }
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                Haptics.tap()
                onDone()
            } label: {
                Text("Skip")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.plTextSecondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .contentShape(Capsule())
            }
            .opacity(selection < pageCount - 1 ? 1 : 0)
            .allowsHitTesting(selection < pageCount - 1)
            .animation(.easeInOut(duration: 0.2), value: selection)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == selection
                          ? AnyShapeStyle(LinearGradient.plGold)
                          : AnyShapeStyle(Color.plStroke))
                    .frame(width: index == selection ? 24 : 7, height: 7)
                    .shadow(color: index == selection ? Color.plGold.opacity(0.5) : .clear,
                            radius: 6)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selection)
        .accessibilityHidden(true)
    }

    private var controls: some View {
        ZStack {
            Button {
                advance()
            } label: {
                HStack(spacing: 7) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.plText.opacity(0.9))
                .padding(.vertical, 13)
                .padding(.horizontal, 28)
                .background(Capsule().strokeBorder(Color.plStroke, lineWidth: 1))
                .contentShape(Capsule())
            }
            .opacity(selection < pageCount - 1 ? 1 : 0)
            .allowsHitTesting(selection < pageCount - 1)

            Button("Start collecting") {
                Haptics.success()
                onDone()
            }
            .buttonStyle(PlPrimaryButtonStyle())
            .plGlow(radius: 18)
            .opacity(selection == pageCount - 1 ? 1 : 0)
            .allowsHitTesting(selection == pageCount - 1)
        }
        .frame(height: 54)
        .animation(.easeInOut(duration: 0.25), value: selection)
    }

    private func advance() {
        Haptics.tap()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.9)) {
            selection = min(selection + 1, pageCount - 1)
        }
    }
}

// MARK: - Background

private struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            Color.plBackground
            RadialGradient(
                colors: [Color.plGold.opacity(0.08), Color.plGold.opacity(0.02), .clear],
                center: UnitPoint(x: 0.5, y: 0.34),
                startRadius: 40,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Page scaffold

/// Shared layout for one onboarding page: motif, serif headline, body copy —
/// each entering with a staggered opacity + y-offset spring once the page is active.
private struct OnboardingPageScaffold<Motif: View>: View {
    let isActive: Bool
    let headline: String
    let message: String
    let motif: (Bool) -> Motif

    @State private var revealed = false

    init(isActive: Bool,
         headline: String,
         message: String,
         @ViewBuilder motif: @escaping (Bool) -> Motif) {
        self.isActive = isActive
        self.headline = headline
        self.message = message
        self.motif = motif
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            motif(revealed)
                .frame(height: 250)
                .onboardingReveal(revealed, delay: 0.05)

            Text(headline)
                .font(.plDisplay(30))
                .foregroundStyle(Color.plText)
                .multilineTextAlignment(.center)
                .padding(.top, 44)
                .onboardingReveal(revealed, delay: 0.18)

            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(Color.plTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 14)
                .onboardingReveal(revealed, delay: 0.3)

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 34)
        .onAppear {
            if isActive { revealed = true }
        }
        .onChange(of: isActive) { _, nowActive in
            if nowActive { revealed = true }
        }
    }
}

// MARK: - Entrance reveal

private struct OnboardingRevealModifier: ViewModifier {
    var revealed: Bool
    var delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 28)
            .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(delay), value: revealed)
    }
}

private extension View {
    func onboardingReveal(_ revealed: Bool, delay: Double) -> some View {
        modifier(OnboardingRevealModifier(revealed: revealed, delay: delay))
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onDone: {})
        .preferredColorScheme(.dark)
}
