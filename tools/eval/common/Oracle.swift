func oracle(_ t: [SpeechUnit], _ s: [SpeechUnit]) -> (Int, Double)? {
  let a = Array(t.suffix(60)); let m = a.count, n = s.count
  guard m >= 8 else { return nil }
  var prev = [Double](repeating: 0, count: n + 1), cur = prev
  var bestCol = [Double](repeating: -1e9, count: n + 1)
  for i in 1...m {
    cur[0] = 0
    for j in 1...n {
      let x = Tracker.sim(a[i-1], s[j-1])
      cur[j] = max(0, prev[j-1] + (x > 0 ? x : -0.4), prev[j] - 0.15, cur[j-1] - 0.3)
      let v = cur[j] - 0.15 * Double(m - i)
      if v > bestCol[j] { bestCol[j] = v }
    }
    swap(&prev, &cur)
  }
  var bj = 1; for j in 1...n where bestCol[j] > bestCol[bj] { bj = j }
  return bestCol[bj] >= Double(min(m, 20)) * 0.55 ? (bj, bestCol[bj]) : nil
}
