import Foundation
/// GIF 路径解析顺序：
///   ① --gif 显式参数（.app 分发的入口——launcher 传入）
///   ② CWD (当前工作目录)
///   ③ #filePath 同级目录（源码树）
///   ④ #filePath 祖父目录（Package 根，编译时定位 cat.gif）
///   ⑤ Assets/ 目录（Xcode 项目资源文件夹）
///   ⑥ (未来可加 Bundle.main.resourcePath 但不依赖——launcher 传 --gif 已覆盖)
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

        let assetsDir = packageRoot.appendingPathComponent("Assets")
        for name in ["cat.gif", "cat.GIF", "CAT.GIF"] {
            let candidate = assetsDir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        fputs("cat.gif not found. Pass --gif /path/to/cat.gif\n", stderr)
        exit(1)
    }
}
