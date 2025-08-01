import Foundation

actor TypewriterEngine {
    struct Config {
        let speed: Double         // chars per second
        let pauses: [TypingPause] // custom pauses
        let basePauses: [TypingPause] // punctuation pauses
    }

    private var isCancelled = false

    func cancel() { isCancelled = true }

    func type(text: String, config: Config, onUpdate: @Sendable (Substring) -> Void) async {
        isCancelled = false
        let cleanText = stripPauseTags(text)
        var i = cleanText.startIndex

        while i < cleanText.endIndex && !isCancelled {
            let next = cleanText.index(after: i)
            let chunk = cleanText[cleanText.startIndex...i]
            await MainActor.run { onUpdate(chunk) }

            let char = cleanText[i]
            var delay: UInt64 = UInt64(1_000_000_000 / max(config.speed, 1)) // ns per char

            // Check for custom pauses based on what's been shown so far
            let shown = String(chunk)
            
            // Custom match-based pauses (after the char is shown)
            for p in config.pauses {
                if shown.hasSuffix(p.match) {
                    delay = UInt64(p.delayMS) * 1_000_000
                    break
                }
            }
            
            // Base punctuation pauses
            for p in config.basePauses {
                if String(char) == p.match {
                    delay = UInt64(p.delayMS) * 1_000_000
                    break
                }
            }

            // Check for {pause:NNN} tags in original text
            if let pauseDelay = getPauseDelay(at: i, in: text, cleanText: cleanText) {
                delay = UInt64(pauseDelay) * 1_000_000
            }

            try? await Task.sleep(nanoseconds: delay)
            i = next
        }

        if !isCancelled {
            await MainActor.run { onUpdate(cleanText[...]) }
        }
    }
    
    private func stripPauseTags(_ text: String) -> String {
        return text.replacingOccurrences(
            of: #"\{pause:\d+\}"#,
            with: "",
            options: .regularExpression
        )
    }
    
    private func getPauseDelay(at index: String.Index, in originalText: String, cleanText: String) -> Int? {
        // Find corresponding position in original text and check for pause tags
        let pattern = #"\{pause:(\d+)\}"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = originalText as NSString
        let matches = regex?.matches(in: originalText, range: NSRange(location: 0, length: nsString.length))
        
        // This is a simplified implementation - in practice you'd need to map positions
        // between original and clean text more precisely
        return nil
    }
}
