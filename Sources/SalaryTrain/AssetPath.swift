import Foundation
import SalaryTrainCore
enum AssetPath {
    static func resolveGif(_ explicit: String?) -> URL {
        if let p = explicit {
            let url = URL(fileURLWithPath: p)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            fputs("GIF not found: \(p)\n", stderr)
            exit(1)
        }

        let cwd = FileManager.default.currentDirectoryPath
        for name in ["cat.gif", "cat.GIF", "CAT.GIF"] {
            let candidate = URL(fileURLWithPath: cwd).appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        let sourceDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        for name in ["cat.gif", "cat.GIF", "CAT.GIF"] {
            let candidate = sourceDir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        let packageRoot = sourceDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for name in ["cat.gif", "cat.GIF", "CAT.GIF"] {
            let candidate = packageRoot.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        fputs("cat.gif not found. Pass --gif /path/to/cat.gif\n", stderr)
        exit(1)
    }
}
