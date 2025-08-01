import SwiftUI

public struct TypingPause: Equatable {
    public let match: String
    public let delayMS: Int
    
    public init(_ match: String, _ delayMS: Int) {
        self.match = match
        self.delayMS = delayMS
    }
}

public struct TypingText: View {
    let text: String
    let speed: Double
    let cursor: String
    let pauses: [TypingPause]
    var onComplete: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: String = ""
    @State private var done = false
    @State private var showCursor = true
    @State private var currentIndex = 0
    @State private var typingTask: Task<Void, Never>?
    @State private var cursorTask: Task<Void, Never>?

    public init(
        text: String,
        speed: Double = 40,
        cursor: String = "▍",
        pauses: [TypingPause] = [],
        onComplete: (() -> Void)? = nil
    ) {
        self.text = text
        self.speed = speed
        self.cursor = cursor
        self.pauses = pauses
        self.onComplete = onComplete
    }

    public var body: some View {
        Text(buildAttributedText())
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .animation(.none, value: shown)
            .accessibilityLabel(Text(text))
            .onAppear { start() }
            .onDisappear { cancel() }
            .onChange(of: reduceMotion) { _ in restartIfNeeded() }
            .onReceive(NotificationCenter.default.publisher(for: .init("TypingTextSkip"))) { _ in
                skip()
            }
    }
    
    private func buildAttributedText() -> AttributedString {
        var attributedString = AttributedString(shown)
        attributedString.foregroundColor = Color(KMTheme.primaryText)
        
        if !done && showCursor {
            var cursorString = AttributedString(cursor)
            cursorString.foregroundColor = Color(KMTheme.primaryText)
            cursorString.font = .system(size: 28, weight: .bold, design: .rounded)
            attributedString.append(cursorString)
        }
        
        return attributedString
    }

    private func start() {
        if UIAccessibility.isVoiceOverRunning || reduceMotion {
            shown = text
            done = true
            onComplete?()
            return
        }
        
        shown = ""
        currentIndex = 0
        done = false
        showCursor = true

        // Start smooth character-by-character typing
        startTyping()
        
        // Start cursor blinking
        startCursorBlink()
    }
    
    private func startTyping() {
        typingTask = Task {
            let speedMs = UInt64(1000 / max(speed, 1)) * 1_000_000 // Convert to nanoseconds
            
            while currentIndex < text.count && !Task.isCancelled {
                let nextIndex = text.index(text.startIndex, offsetBy: currentIndex + 1)
                let newShown = String(text[text.startIndex..<nextIndex])
                
                await MainActor.run {
                    shown = newShown
                    currentIndex += 1
                }
                
                // Check for custom pauses
                var delay = speedMs
                let currentChar = String(text[text.index(text.startIndex, offsetBy: currentIndex - 1)])
                
                // Apply custom pauses
                for pause in pauses {
                    if shown.hasSuffix(pause.match) {
                        delay = UInt64(pause.delayMS) * 1_000_000
                        break
                    }
                }
                
                // Apply base punctuation pauses
                switch currentChar {
                case ".": delay = 300 * 1_000_000
                case ",": delay = 150 * 1_000_000
                case "!", "?": delay = 400 * 1_000_000
                case "—": delay = 200 * 1_000_000
                default: break
                }
                
                try? await Task.sleep(nanoseconds: delay)
            }
            
            if !Task.isCancelled {
                await MainActor.run {
                    done = true
                    onComplete?()
                }
            }
        }
    }
    
    private func startCursorBlink() {
        cursorTask = Task {
            while !done && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await MainActor.run {
                    if !done {
                        showCursor.toggle()
                    }
                }
            }
        }
    }

    private func cancel() {
        typingTask?.cancel()
        cursorTask?.cancel()
    }

    public func skip() {
        cancel()
        shown = text
        done = true
        showCursor = false
        onComplete?()
    }

    private func restartIfNeeded() {
        cancel()
        start()
    }
}
