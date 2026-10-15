import AppKit

let args = CommandLine.arguments

if let i = args.firstIndex(of: "--export-icon"), i + 1 < args.count {
    AppIcon.exportIconset(to: args[i + 1])
    exit(0)
}

if let i = args.firstIndex(of: "--replay"), i + 1 < args.count {
    ReplayTool.run(path: args[i + 1])
    exit(0)
}

let app = NSApplication.shared

if let i = args.firstIndex(of: "--asr-bench"), i + 2 < args.count,
   let data = try? Data(contentsOf: URL(fileURLWithPath: args[i + 2])),
   let list = try? JSONSerialization.jsonObject(with: data) as? [[String]] {
    ASRBench.run(outDir: args[i + 1], scripts: list.map { ($0[0], $0[1]) })
    exit(0)
}

if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
    MainActor.assumeIsolated { SnapshotRenderer.run(dir: args[i + 1]) }
    exit(0)
}

if let i = args.firstIndex(of: "--snapshot-readme"), i + 1 < args.count {
    MainActor.assumeIsolated { ReadmeSnapshot.run(dir: args[i + 1]) }
    exit(0)
}

if let i = args.firstIndex(of: "--video-readme"), i + 1 < args.count {
    MainActor.assumeIsolated { ReadmeVideo.run(dir: args[i + 1]) }
    exit(0)
}

if let i = args.firstIndex(of: "--snapshot-updates"), i + 1 < args.count {
    MainActor.assumeIsolated { UpdateSnapshot.run(dir: args[i + 1]) }
    exit(0)
}

Migration.runIfNeeded()
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
