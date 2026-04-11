import SwiftUI

struct TrackMapView: View {
    var circuitInfo: CircuitInfo?
    var imageURL: String?
    /// Локальный ассет трассы из Assets (Tracks). Если задан — показывается вместо отрисовки/загрузки по URL.
    var localTrackImageName: String? = nil
    var compact: Bool = false
    var compactSize: CGSize?
    /// В компактном режиме: `true` — сначала ассет из Tracks (горизонтальный Season); `false` — сначала вектор по `circuitInfo` (герой с таймером и live-точками на той же сетке координат).
    var preferRasterTrackInCompact: Bool = true
    var strokeColor: Color = .red
    var cardBackground: Color = Color(.systemGray6)

    var body: some View {
        Group {
            if compact {
                compactBody
            } else {
                fullBody
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 0 : 8))
    }

    private var fullBody: some View {
        GeometryReader { geo in
            contentView
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1.6, contentMode: .fit)
    }

    private var compactBody: some View {
        let size = compactSize ?? CGSize(width: 72, height: 44)
        return ZStack {
            cardBackground
            compactContentView(in: size)
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func compactContentView(in size: CGSize) -> some View {
        let pathPoints = circuitInfo?.normalizedPathPoints() ?? []
        let hasPath = pathPoints.count >= 2

        if preferRasterTrackInCompact {
            if let name = localTrackImageName {
                compactTrackAsset(name: name, size: size)
            } else if hasPath {
                compactTrackPath(points: pathPoints, size: size)
            } else {
                compactFallbackURLorPlaceholder(size: size)
            }
        } else {
            if hasPath {
                compactTrackPath(points: pathPoints, size: size)
            } else if let name = localTrackImageName {
                compactTrackAsset(name: name, size: size)
            } else {
                compactFallbackURLorPlaceholder(size: size)
            }
        }
    }

    private func compactTrackAsset(name: String, size: CGSize) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .renderingMode(.template)
            .foregroundStyle(strokeColor)
            .scaledToFit()
            .frame(width: size.width, height: size.height)
    }

    private func compactTrackPath(points: [(CGFloat, CGFloat)], size: CGSize) -> some View {
        CircuitPathShape(points: points)
            .stroke(strokeColor, lineWidth: compact ? 2.5 : 3)
            .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func compactFallbackURLorPlaceholder(size: CGSize) -> some View {
        if let urlString = imageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                case .failure:
                    trackPlaceholder
                case .empty:
                    Color.clear
                @unknown default:
                    trackPlaceholder
                }
            }
            .frame(width: size.width, height: size.height)
        } else {
            trackPlaceholder
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if let info = circuitInfo {
            let pts = info.normalizedPathPoints()
            if pts.count >= 2 {
                CircuitPathShape(points: pts)
                    .stroke(strokeColor, lineWidth: 3)
            } else if let name = localTrackImageName {
                trackRasterImage(name: name, maxFrame: true)
            } else if let urlString = imageURL, let url = URL(string: urlString) {
                asyncTrackImage(url: url, maxFrame: true)
            } else {
                trackPlaceholder
            }
        } else if let name = localTrackImageName {
            trackRasterImage(name: name, maxFrame: true)
        } else if let urlString = imageURL, let url = URL(string: urlString) {
            asyncTrackImage(url: url, maxFrame: true)
        } else {
            trackPlaceholder
        }
    }

    @ViewBuilder
    private func trackRasterImage(name: String, maxFrame: Bool) -> some View {
        let img = Image(name)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .renderingMode(.template)
            .foregroundStyle(strokeColor)
            .scaledToFit()
        if maxFrame {
            img.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            img
        }
    }

    @ViewBuilder
    private func asyncTrackImage(url: URL, maxFrame: Bool) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: maxFrame ? .infinity : nil, maxHeight: maxFrame ? .infinity : nil)
            case .failure:
                trackPlaceholder
            case .empty:
                ProgressView()
                    .frame(maxWidth: maxFrame ? .infinity : nil, maxHeight: maxFrame ? .infinity : nil)
            @unknown default:
                trackPlaceholder
            }
        }
    }

    private var trackPlaceholder: some View {
        Image(systemName: "map")
            .font(.title)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1.6, contentMode: .fit)
    }
}
