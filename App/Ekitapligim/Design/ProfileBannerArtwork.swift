import SwiftUI

/// Each image fills the banner's measured bounds independently. Images with different aspect
/// ratios must not enlarge one another through the surrounding ZStack's ideal size.
struct ProfileBannerArtwork: View {
    let image: Image

    var body: some View {
        GeometryReader { geometry in
            image
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
