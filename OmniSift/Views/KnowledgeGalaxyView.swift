import SwiftUI

struct KnowledgeGalaxyView: View {
    let galaxy: KnowledgeGalaxy
    let strings: AppStrings
    let onSelectSystem: (KnowledgeStarSystem) -> Void
    let onSelectBreadcrumb: (String?) -> Void
    let onBack: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            breadcrumbBar

            if galaxy.systems.isEmpty {
                formingState
            } else {
                GalaxySkyPanel(
                    galaxy: galaxy,
                    strings: strings,
                    reduceMotion: reduceMotion,
                    onSelectSystem: onSelectSystem
                )
            }
            constellationSummary
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.10, blue: 0.18).opacity(0.88),
                    Color(red: 0.05, green: 0.30, blue: 0.32).opacity(0.28),
                    Color(red: 0.90, green: 0.56, blue: 0.16).opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(strings.knowledgeGalaxyTitle)
                        .font(.title2.weight(.bold))
                    Text(strings.knowledgeGalaxyDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.title2)
                    .foregroundStyle(.yellow)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    GalaxyMetricPill(title: strings.galaxyConstellations, value: "\(galaxy.stats.systemCount)", color: .orange)
                    GalaxyMetricPill(title: strings.galaxyStars, value: "\(galaxy.stats.cardCount)", color: .yellow)
                    GalaxyMetricPill(title: strings.galaxyEntities, value: "\(galaxy.stats.entityCount)", color: .teal)
                    GalaxyMetricPill(title: strings.galaxyConnections, value: "\(galaxy.stats.connectionCount)", color: .blue)
                }
            }
        }
    }

    @ViewBuilder
    private var breadcrumbBar: some View {
        if galaxy.isHierarchyBacked {
            HStack(spacing: 8) {
                if galaxy.canGoBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.bold))
                            .padding(7)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(strings.backToGalaxy)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(galaxy.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            Button {
                                onSelectBreadcrumb(crumb.id)
                            } label: {
                                Text(index == 0 ? strings.galaxyRoot : crumb.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(index == galaxy.breadcrumbs.count - 1 ? 0.20 : 0.10), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var formingState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.purple)
            Text(strings.galaxyFormingTitle)
                .font(.headline)
            Text(strings.galaxyFormingDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    private var constellationSummary: some View {
        HStack(spacing: 10) {
            Label(strings.galaxyLightingRule, systemImage: "sparkle")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Text(strings.galaxyLitConstellations(count: galaxy.systems.filter { !$0.cards.isEmpty }.count))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.yellow)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.16), in: Capsule())
        }
    }
}

private struct GalaxySkyPanel: View {
    let galaxy: KnowledgeGalaxy
    let strings: AppStrings
    let reduceMotion: Bool
    let onSelectSystem: (KnowledgeStarSystem) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                skyBackground
                GalaxyBeltLines()
                if !galaxy.featuredConnections.isEmpty {
                    GalaxyConnectionLines(systems: galaxy.systems)
                }

                ForEach(Array(galaxy.systems.enumerated()), id: \.element.id) { index, system in
                    let position = position(for: index, total: galaxy.systems.count, in: geometry.size)
                    GalaxyConstellationCluster(
                        system: system,
                        strings: strings,
                        reduceMotion: reduceMotion,
                        onSelect: { onSelectSystem(system) }
                    )
                    .position(position)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .accessibilityElement(children: .contain)
        }
        .frame(height: galaxy.isHierarchyBacked ? 360 : 340)
    }

    private var skyBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.01, green: 0.03, blue: 0.08).opacity(0.96),
                            Color(red: 0.03, green: 0.13, blue: 0.24).opacity(0.90),
                            Color(red: 0.02, green: 0.25, blue: 0.28).opacity(0.58)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Canvas { context, size in
                for index in 0..<72 {
                    let x = CGFloat((index * 37 + 19) % 100) / 100 * size.width
                    let y = CGFloat((index * 61 + 11) % 100) / 100 * size.height
                    let diameter = CGFloat(index.isMultiple(of: 9) ? 2.8 : 1.7)
                    let opacity = index.isMultiple(of: 4) ? 0.45 : 0.20
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
    }

    private func position(for index: Int, total: Int, in size: CGSize) -> CGPoint {
        guard total > 1 else {
            return CGPoint(x: size.width * 0.50, y: size.height * 0.52)
        }

        let center = CGPoint(x: size.width * 0.50, y: size.height * 0.52)
        let ring = index < 5 ? 0 : 1
        let ringIndex = ring == 0 ? index : index - 5
        let ringTotal = ring == 0 ? min(total, 5) : max(total - 5, 1)
        let angle = (Double(ringIndex) / Double(ringTotal)) * .pi * 2 - .pi / 2 + Double(ring) * 0.32
        let radiusX = size.width * (ring == 0 ? 0.22 : 0.32)
        let radiusY = size.height * (ring == 0 ? 0.20 : 0.29)

        return CGPoint(
            x: center.x + cos(angle) * radiusX,
            y: center.y + sin(angle) * radiusY
        )
    }
}

private struct GalaxyConnectionLines: View {
    let systems: [KnowledgeStarSystem]

    var body: some View {
        Canvas { context, size in
            let points = systems.indices.map { index in
                position(for: index, total: systems.count, in: size)
            }
            guard points.count > 1 else { return }

            for index in 0..<(points.count - 1) {
                var path = Path()
                path.move(to: points[index])
                path.addLine(to: points[index + 1])
                context.stroke(path, with: .color(.white.opacity(0.10)), lineWidth: 1)
            }
        }
    }

    private func position(for index: Int, total: Int, in size: CGSize) -> CGPoint {
        guard total > 1 else { return CGPoint(x: size.width * 0.50, y: size.height * 0.52) }
        let center = CGPoint(x: size.width * 0.50, y: size.height * 0.52)
        let ring = index < 5 ? 0 : 1
        let ringIndex = ring == 0 ? index : index - 5
        let ringTotal = ring == 0 ? min(total, 5) : max(total - 5, 1)
        let angle = (Double(ringIndex) / Double(ringTotal)) * .pi * 2 - .pi / 2 + Double(ring) * 0.32
        return CGPoint(
            x: center.x + cos(angle) * size.width * (ring == 0 ? 0.22 : 0.32),
            y: center.y + sin(angle) * size.height * (ring == 0 ? 0.20 : 0.29)
        )
    }
}

private struct GalaxyBeltLines: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<3 {
                var path = Path()
                let y = size.height * (0.30 + CGFloat(index) * 0.18)
                path.move(to: CGPoint(x: size.width * -0.06, y: y))
                path.addCurve(
                    to: CGPoint(x: size.width * 1.06, y: y + CGFloat(index - 1) * 22),
                    control1: CGPoint(x: size.width * 0.22, y: y - 72),
                    control2: CGPoint(x: size.width * 0.72, y: y + 76)
                )
                context.stroke(
                    path,
                    with: .color(.white.opacity(index == 1 ? 0.08 : 0.045)),
                    style: StrokeStyle(lineWidth: index == 1 ? 1.2 : 0.8, dash: [6, 14])
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct GalaxyConstellationCluster: View {
    let system: KnowledgeStarSystem
    let strings: AppStrings
    let reduceMotion: Bool
    let onSelect: () -> Void
    @State private var isPulsing = false

    private let constellationPoints = [
        CGPoint(x: 0.17, y: 0.44),
        CGPoint(x: 0.33, y: 0.20),
        CGPoint(x: 0.55, y: 0.30),
        CGPoint(x: 0.76, y: 0.16),
        CGPoint(x: 0.84, y: 0.48),
        CGPoint(x: 0.65, y: 0.70),
        CGPoint(x: 0.38, y: 0.80),
        CGPoint(x: 0.20, y: 0.65)
    ]

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(starColor.opacity(0.08))
                    .frame(width: clusterWidth - 12, height: clusterHeight - 10)
                    .scaleEffect(isPulsing && !reduceMotion ? 1.04 : 0.98)
                    .blur(radius: 10)

                ConstellationLineCanvas(
                    points: visiblePoints(in: CGSize(width: clusterWidth, height: clusterHeight)),
                    litCount: litStarCount,
                    color: starColor
                )

                ForEach(0..<visibleStarSlotCount, id: \.self) { index in
                    let point = point(index: index, in: CGSize(width: clusterWidth, height: clusterHeight))
                    ConstellationStarDot(
                        isLit: index < litStarCount,
                        isCore: index == 0,
                        color: starColor
                    )
                    .position(point)
                }

                if system.canDrillDown {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85), starColor)
                        .position(x: clusterWidth * 0.87, y: clusterHeight * 0.18)
                }

                ForEach(Array(system.satellites.enumerated()), id: \.element.id) { index, satellite in
                    GalaxySatelliteDot(satellite: satellite, color: starColor)
                        .scaleEffect(0.82)
                        .position(satellitePosition(index: index, count: system.satellites.count))
                }

                VStack(spacing: 3) {
                    Text(system.name)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.82)

                    Text(countLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(width: clusterWidth * 0.84)
                .background(.black.opacity(0.28), in: Capsule())
                .overlay(Capsule().strokeBorder(starColor.opacity(0.22), lineWidth: 1))
                .position(x: clusterWidth * 0.50, y: clusterHeight * 0.93)
            }
            .frame(width: clusterWidth, height: clusterHeight)
            .contentShape(RoundedRectangle(cornerRadius: 30))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var visibleStarSlotCount: Int {
        switch system.size {
        case .small: 4
        case .medium: 5
        case .large: 7
        case .giant: 8
        }
    }

    private var litStarCount: Int {
        min(
            visibleStarSlotCount,
            max(1, max(system.cards.count, system.canDrillDown ? system.childCount : 0))
        )
    }

    private var clusterWidth: CGFloat {
        switch system.size {
        case .small: 118
        case .medium: 130
        case .large: 142
        case .giant: 154
        }
    }

    private var clusterHeight: CGFloat {
        clusterWidth * 0.92
    }

    private var starColor: Color {
        let palette: [Color] = [.yellow, .teal, .cyan, .orange, .green, .pink, .blue]
        return palette[abs(system.colorSeed) % palette.count]
    }

    private var countLabel: String {
        system.canDrillDown ? strings.subtopicCount(system.childCount) : strings.savedInsights(count: system.cards.count)
    }

    private var accessibilityText: String {
        if system.canDrillDown {
            return "\(system.name), \(strings.subtopicCount(system.childCount)), \(strings.savedInsights(count: system.cards.count))"
        }
        return "\(system.name), \(strings.savedInsights(count: system.cards.count))"
    }

    private func visiblePoints(in size: CGSize) -> [CGPoint] {
        (0..<visibleStarSlotCount).map { point(index: $0, in: size) }
    }

    private func point(index: Int, in size: CGSize) -> CGPoint {
        let source = constellationPoints[index % constellationPoints.count]
        return CGPoint(x: source.x * size.width, y: source.y * size.height)
    }

    private func satellitePosition(index: Int, count: Int) -> CGPoint {
        let angle = (Double(index) / Double(max(count, 1))) * .pi * 2 - .pi / 2
        return CGPoint(
            x: clusterWidth * 0.50 + cos(angle) * clusterWidth * 0.42,
            y: clusterHeight * 0.46 + sin(angle) * clusterHeight * 0.42
        )
    }
}

private struct ConstellationLineCanvas: View {
    let points: [CGPoint]
    let litCount: Int
    let color: Color

    var body: some View {
        Canvas { context, _ in
            drawLines(in: &context, count: points.count, color: .white.opacity(0.12), lineWidth: 0.8)
            drawLines(in: &context, count: litCount, color: color.opacity(0.72), lineWidth: 1.6)
        }
        .allowsHitTesting(false)
    }

    private func drawLines(in context: inout GraphicsContext, count: Int, color: Color, lineWidth: CGFloat) {
        guard count > 1 else { return }
        for index in 0..<(count - 1) {
            var path = Path()
            path.move(to: points[index])
            path.addLine(to: points[index + 1])
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
    }
}

private struct ConstellationStarDot: View {
    let isLit: Bool
    let isCore: Bool
    let color: Color

    var body: some View {
        Circle()
            .fill(isLit ? .white : Color.white.opacity(0.18))
            .frame(width: diameter, height: diameter)
            .overlay(Circle().strokeBorder(isLit ? color : Color.white.opacity(0.18), lineWidth: isLit ? 2 : 1))
            .shadow(color: isLit ? color.opacity(0.80) : .clear, radius: isCore ? 14 : 8)
    }

    private var diameter: CGFloat {
        isCore ? 14 : (isLit ? 10 : 7)
    }
}

private struct GalaxyTopicStar: View {
    let system: KnowledgeStarSystem
    let strings: AppStrings
    let reduceMotion: Bool
    let onSelect: () -> Void
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Button(action: onSelect) {
                starBody
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityText)

            ForEach(Array(system.satellites.enumerated()), id: \.element.id) { index, satellite in
                GalaxySatelliteDot(satellite: satellite, color: starColor)
                    .offset(satelliteOffset(index: index, count: system.satellites.count))
            }
        }
        .frame(width: starDiameter + 72, height: starDiameter + 72)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var starBody: some View {
        ZStack {
            Circle()
                .fill(starColor.opacity(0.24))
                .frame(width: starDiameter + 28, height: starDiameter + 28)
                .scaleEffect(isPulsing && !reduceMotion ? 1.06 : 0.95)
                .blur(radius: 2)

            Circle()
                .fill(starColor.gradient)
                .frame(width: starDiameter, height: starDiameter)
                .shadow(color: starColor.opacity(0.55), radius: 14)

            VStack(spacing: 2) {
                Text(system.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(system.canDrillDown ? strings.subtopicCount(system.childCount) : strings.savedInsights(count: system.cards.count))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
            }
            .frame(width: starDiameter + 18)
        }
        .frame(width: starDiameter + 32, height: starDiameter + 32)
        .contentShape(Circle())
    }

    private var starDiameter: CGFloat {
        switch system.size {
        case .small: 76
        case .medium: 88
        case .large: 100
        case .giant: 112
        }
    }

    private var starColor: Color {
        let palette: [Color] = [.orange, .purple, .blue, .cyan, .pink, .green]
        return palette[abs(system.colorSeed) % palette.count]
    }

    private var accessibilityText: String {
        if system.canDrillDown {
            return "\(system.name), \(strings.subtopicCount(system.childCount)), \(strings.savedInsights(count: system.cards.count))"
        }
        return "\(system.name), \(strings.savedInsights(count: system.cards.count))"
    }

    private func satelliteOffset(index: Int, count: Int) -> CGSize {
        let angle = (Double(index) / Double(max(count, 1))) * .pi * 2 - .pi / 2
        let radius = starDiameter * 0.66
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }
}

private struct GalaxySatelliteDot: View {
    let satellite: KnowledgeSatellite
    let color: Color

    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(color, lineWidth: 2))
            .accessibilityLabel("\(satellite.name), \(satellite.cards.count)")
    }
}

private struct GalaxyMetricPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text(value)
                .font(.caption.weight(.bold))
            Text(title)
                .font(.caption2)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(color.opacity(0.14), in: Capsule())
        .foregroundStyle(color)
    }
}
