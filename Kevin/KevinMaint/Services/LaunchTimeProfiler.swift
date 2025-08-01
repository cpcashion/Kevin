import Foundation

final class LaunchTimeProfiler {
    static let shared = LaunchTimeProfiler()
    
    private var startTime: Date?
    private var checkpoints: [(String, TimeInterval)] = []
    
    private init() {}
    
    func startProfiling() {
        startTime = Date()
        checkpoints.removeAll()
        print("🚀 [LAUNCH PROFILER] App launch started at \(Date())")
    }
    
    func checkpoint(_ name: String) {
        guard let startTime = startTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        checkpoints.append((name, elapsed))
        print("⏱️ [LAUNCH PROFILER] \(name): \(String(format: "%.3f", elapsed))s (total: \(String(format: "%.3f", elapsed))s)")
    }
    
    func finishProfiling() {
        guard let startTime = startTime else { return }
        let totalTime = Date().timeIntervalSince(startTime)
        
        print("🏁 [LAUNCH PROFILER] ===== LAUNCH COMPLETE =====")
        print("🏁 [LAUNCH PROFILER] Total launch time: \(String(format: "%.3f", totalTime))s")
        print("🏁 [LAUNCH PROFILER] Breakdown:")
        
        var previousTime: TimeInterval = 0
        for (name, time) in checkpoints {
            let stepTime = time - previousTime
            print("🏁 [LAUNCH PROFILER]   \(name): \(String(format: "%.3f", stepTime))s (cumulative: \(String(format: "%.3f", time))s)")
            previousTime = time
        }
        
        // Identify bottlenecks
        let slowSteps = checkpoints.enumerated().compactMap { index, checkpoint in
            let stepTime = index == 0 ? checkpoint.1 : checkpoint.1 - checkpoints[index - 1].1
            return stepTime > 1.0 ? (checkpoint.0, stepTime) : nil
        }
        
        if !slowSteps.isEmpty {
            print("🐌 [LAUNCH PROFILER] SLOW STEPS (>1s):")
            for (name, time) in slowSteps {
                print("🐌 [LAUNCH PROFILER]   \(name): \(String(format: "%.3f", time))s")
            }
        }
        
        print("🏁 [LAUNCH PROFILER] ========================")
    }
}
