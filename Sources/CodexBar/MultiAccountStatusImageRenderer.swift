import AppKit

@MainActor
enum MultiAccountStatusImageRenderer {
    private static let imageHeight: CGFloat = 18
    private static let minimumItemWidth: CGFloat = 22
    private static let itemSpacing: CGFloat = 3
    private static let cache = NSCache<NSString, NSImage>()

    static func image(items: [MultiAccountMenuBarDisplay.Item]) -> NSImage? {
        guard !items.isEmpty else { return nil }
        let cacheKey = items.map { "\($0.indicator):\($0.percentage)" }.joined(separator: "|") as NSString
        if let cached = self.cache.object(forKey: cacheKey) {
            return cached
        }

        let indicatorAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7, weight: .semibold),
            .foregroundColor: NSColor.black,
        ]
        let percentageAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .medium),
            .foregroundColor: NSColor.black,
        ]
        let itemWidths = items.map { item in
            let indicatorWidth = (item.indicator as NSString).size(withAttributes: indicatorAttributes).width
            let percentageWidth = (item.percentage as NSString).size(withAttributes: percentageAttributes).width
            return ceil(max(self.minimumItemWidth, indicatorWidth, percentageWidth))
        }
        let width = itemWidths.reduce(0, +) + self.itemSpacing * CGFloat(max(0, items.count - 1))
        let image = NSImage(size: NSSize(width: width, height: self.imageHeight), flipped: false) { _ in
            var x: CGFloat = 0
            for (index, item) in items.enumerated() {
                let itemWidth = itemWidths[index]
                Self.draw(
                    item.indicator,
                    attributes: indicatorAttributes,
                    x: x,
                    y: 10,
                    width: itemWidth)
                Self.draw(
                    item.percentage,
                    attributes: percentageAttributes,
                    x: x,
                    y: 0,
                    width: itemWidth)
                x += itemWidth + self.itemSpacing
            }
            return true
        }
        image.isTemplate = true
        self.cache.setObject(image, forKey: cacheKey)
        return image
    }

    private static func draw(
        _ text: String,
        attributes: [NSAttributedString.Key: Any],
        x: CGFloat,
        y: CGFloat,
        width: CGFloat)
    {
        let value = text as NSString
        let textSize = value.size(withAttributes: attributes)
        value.draw(
            at: NSPoint(
                x: x + ((width - textSize.width) / 2).rounded(),
                y: y),
            withAttributes: attributes)
    }
}
