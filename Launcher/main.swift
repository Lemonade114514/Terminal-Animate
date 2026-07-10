import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let rp = Bundle.main.resourcePath else { NSApp.terminate(nil); return }
        let bin = "\(rp)/SalaryTrain"
        let gif = "\(rp)/cat.gif"
        let extraArgs = CommandLine.arguments.dropFirst().joined(separator: " ")

        var env = ProcessInfo.processInfo.environment
        env["APP_BINARY"] = bin
        env["APP_GIF"] = gif
        env["APP_ARGS"] = extraArgs

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.environment = env
        task.arguments = [
            "-e", "tell application \"Terminal\" to activate",
            "-e", "tell application \"Terminal\" to do script (system attribute \"APP_BINARY\") & \" --gif \" & (system attribute \"APP_GIF\") & \" \" & (system attribute \"APP_ARGS\") & \"; exit\""
        ]
        try? task.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
