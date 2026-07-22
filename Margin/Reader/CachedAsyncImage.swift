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
            let image = try await ReaderImageLoader.shared.image(for: url)
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
final class ReaderImageLoader {
    static let shared = ReaderImageLoader()

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
            let data: Data
            if url.isFileURL {
                // Reading and decoding a document-relative image used to happen
                // inline in the view body, stalling the scroll on every render.
                data = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: url, options: .mappedIfSafe)
                }.value
            } else {
                let (remoteData, response) = try await URLSession.shared.data(from: url)
                guard let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                data = remoteData
            }

            guard let decodedImage = UIImage(data: data),
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
