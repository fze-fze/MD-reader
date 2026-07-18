import SwiftUI
import UIKit

struct CachedAsyncImage<Content: View>: View {
    let url: URL
    private let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(
        url: URL,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                await loadImage()
            }
    }

    @MainActor
    private func loadImage() async {
        phase = .empty
        do {
            let image = try await RemoteImageLoader.shared.image(for: url)
            try Task.checkCancellation()
            phase = .success(Image(uiImage: image))
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            phase = .failure(error)
        }
    }
}

@MainActor
private final class RemoteImageLoader {
    static let shared = RemoteImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage, any Error>] = [:]

    private init() {
        cache.countLimit = 64
        cache.totalCostLimit = 64 * 1_024 * 1_024
    }

    func image(for url: URL) async throws -> UIImage {
        if let cachedImage = cache.object(forKey: url as NSURL) {
            return cachedImage
        }
        if let request = inFlight[url] {
            return try await request.value
        }

        let request = Task { @MainActor in
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  let decodedImage = UIImage(data: data),
                  let preparedImage = await decodedImage.byPreparingForDisplay() else {
                throw URLError(.cannotDecodeContentData)
            }
            return preparedImage
        }
        inFlight[url] = request

        do {
            let image = try await request.value
            let decodedCost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            cache.setObject(image, forKey: url as NSURL, cost: decodedCost)
            inFlight[url] = nil
            return image
        } catch {
            inFlight[url] = nil
            throw error
        }
    }
}
