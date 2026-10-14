import Foundation
func applyVariantFromEnv() {
  let v = ProcessInfo.processInfo.environment["NC_VARIANT"] ?? ""
  if v.contains("-onset") { PrompterEngine.onsetPredict = false }
}
func makeEngine() -> (PrompterEngine, PrompterSettings) {
  applyVariantFromEnv()
  let d = UserDefaults(suiteName: "openpitch.replay")!; d.removePersistentDomain(forName: "openpitch.replay")
  let s = PrompterSettings(defaults: d); s.countdown = false; s.mode = .voice; s.trackingLog = false
  s.apply(PlacementPreset.all[4])   // E
  return (PrompterEngine(settings: s), s)
}
extension PrompterEngine { func debugJump(to p: Int) { debugSetPosition(Double(p)) } }
