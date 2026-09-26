import Foundation

/// Public links shown in Settings → About. Leftovers is free; a star or a
/// follow is the only ask, and it is never shown as a prompt.
enum AppLinks {
    static let repository = URL(string: "https://github.com/arpwal/leftovers")!
    static let website = URL(string: "https://arpwal.github.io/leftovers/")!
    static let author = URL(string: "https://x.com/arpwal")!
}
