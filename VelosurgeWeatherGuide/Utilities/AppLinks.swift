import UIKit

enum AppLinks: String {
    case privacy = "https://velosurgeweather342guide.site/privacy/447"
    case terms = "https://velosurgeweather342guide.site/terms/447"

    var url: URL? { URL(string: rawValue) }
}
