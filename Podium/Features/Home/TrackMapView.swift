import SwiftUI

struct TrackMapView: View {
    var circuitInfo: CircuitInfo?
    var imageURL: String?
    /// Локальный ассет трассы из Assets (Tracks). Если задан — показывается вместо отрисовки/загрузки по URL.
    var localTrackImageName: String? = nil
    var compact: Bool = false
    var compactSize: CGSize?
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
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        if let name = localTrackImageName {
            Image(name)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(strokeColor)
                .scaledToFit()
                .frame(width: size.width, height: size.height)
        } else {
            let pathPoints = circuitInfo?.normalizedPathPoints() ?? []
            if pathPoints.count >= 2 {
                CircuitPathShape(points: pathPoints)
                    .stroke(strokeColor, lineWidth: 3)
            } else if let urlString = imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        trackPlaceholder
                    case .empty:
                        ProgressView()
                    @unknown default:
                        trackPlaceholder
                    }
                }
                .frame(width: size.width, height: size.height)
            } else {
                trackPlaceholder
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if let name = localTrackImageName {
            Image(name)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(strokeColor)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let info = circuitInfo {
            CircuitPathShape(points: info.normalizedPathPoints())
                .stroke(strokeColor, lineWidth: 3)
        } else if let urlString = imageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    trackPlaceholder
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    trackPlaceholder
                }
            }
        } else {
            trackPlaceholder
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
