import Foundation
func applyVariantFromEnv() {
  let v = ProcessInfo.processInfo.environment["NC_VARIANT"] ?? ""
  if v.contains("-onset") { PrompterEngine.onsetPredict = false }
}
func makeEngine() -> (PrompterEngine, PrompterSettings) {
  applyVariantFromEnv()
  let d = UserDefaults(suiteName: "openspeech.replay")!; d.removePersistentDomain(forName: "openspeech.replay")
  let s = PrompterSettings(defaults: d); s.countdown = false; s.mode = .voice; s.trackingLog = false
  s.displayStyle = .glass; s.glassChars = 12; s.glassLines = 2   // 与旧预设 E 相同的排版，结果可以和以前对比
  return (PrompterEngine(settings: s), s)
}
extension PrompterEngine { func debugJump(to p: Int) { debugSetPosition(Double(p)) } }
