import Foundation

/// Sidecar notes for jobs, one JSON file per label in
/// `~/Library/Application Support/Leftovers/jobs/<label>.json`.
/// Anything that creates a LaunchAgent (Claude included) should write one,
/// so the Scheduled view can say what the job is for and when it ends.
struct JobMetadataStore {
    static let directory = (NSHomeDirectory() as NSString)
        .appendingPathComponent("Library/Application Support/Leftovers/jobs")

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func read(label: String) -> JobMetadata? {
        let url = URL(fileURLWithPath: Self.directory).appendingPathComponent("\(label).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(JobMetadata.self, from: data)
    }
}
