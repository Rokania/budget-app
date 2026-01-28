import SwiftUI

struct SplashScreenView: View {
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var iconRotation: Double = -30
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var particlesVisible = false
    @State private var dismissOpacity: Double = 1
    @State private var dismissScale: CGFloat = 1

    @Environment(\.colorScheme) private var colorScheme

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            // Background
            backgroundGradient

            // Animated glow behind icon
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gold.opacity(0.3),
                            Color.gold.opacity(0.08),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .scaleEffect(glowOpacity > 0 ? 1.2 : 0.8)
                .opacity(glowOpacity)

            // Expanding ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.gold.opacity(0.4),
                            Color.gold.opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 200, height: 200)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            // Particles
            if particlesVisible {
                ForEach(0..<8, id: \.self) { i in
                    SplashParticle(index: i)
                }
            }

            // Content
            VStack(spacing: Spacing.lg) {
                // App icon
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.gold,
                                    Color(hex: "D4A832"),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        }
                        .shadow(color: Color.gold.opacity(0.4), radius: 20, y: 4)

                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                .rotationEffect(.degrees(iconRotation))

                // Title
                VStack(spacing: Spacing.xs) {
                    Text("Budget")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)

                    Text("Gerez votre argent intelligemment")
                        .font(AppFont.body(14))
                        .foregroundStyle(Color.textSecondary)
                        .opacity(subtitleOpacity)
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)
            }
        }
        .opacity(dismissOpacity)
        .scaleEffect(dismissScale)
        .onAppear {
            runAnimation()
        }
    }

    private var backgroundGradient: some View {
        ZStack {
            Color.bgSecondary

            // Subtle radial gradient overlay
            RadialGradient(
                colors: [
                    Color.gold.opacity(colorScheme == .dark ? 0.04 : 0.06),
                    Color.clear,
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }

    private func runAnimation() {
        // Phase 1: Icon bounces in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            iconScale = 1.0
            iconOpacity = 1.0
            iconRotation = 0
        }

        // Phase 2: Glow appears
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            glowOpacity = 1.0
        }

        // Phase 3: Ring expands
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.3)) {
            ringScale = 1.3
            ringOpacity = 0.6
        }

        // Phase 3b: Ring fades out
        withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
            ringOpacity = 0
        }

        // Phase 4: Particles burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            particlesVisible = true
        }

        // Phase 5: Title slides up
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.45)) {
            titleOpacity = 1.0
            titleOffset = 0
        }

        // Phase 6: Subtitle
        withAnimation(.easeOut(duration: 0.4).delay(0.65)) {
            subtitleOpacity = 1.0
        }

        // Phase 7: Dismiss splash
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(1.6)) {
            dismissOpacity = 0
            dismissScale = 1.05
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onFinished()
        }
    }
}

// MARK: - Particle

private struct SplashParticle: View {
    let index: Int
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 0
    @State private var scale: CGFloat = 0.5

    private var angle: Double {
        Double(index) * (360.0 / 8.0)
    }

    var body: some View {
        Circle()
            .fill(Color.gold)
            .frame(width: 5, height: 5)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(
                x: cos(angle * .pi / 180) * (60.0 + offset),
                y: sin(angle * .pi / 180) * (60.0 + offset)
            )
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    opacity = 0.8
                    offset = 40
                    scale = 1.0
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                    opacity = 0
                    scale = 0.2
                }
            }
    }
}
