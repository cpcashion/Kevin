# Threaded Replies Implementation

## Overview
Implemented threaded conversation support using a clean, iOS-native sheet design. Users tap a "Reply" button to open a dedicated thread view where they can see the parent message, all replies, and add their own reply.

## Design Philosophy
- **Sheet-based UI**: Native iOS feel with modal sheets (like iMessage threads)
- **Clean timeline**: No inline reply UI cluttering the main timeline
- **Focused conversation**: Thread sheet shows only relevant messages
- **Simple interaction**: Tap "Reply" → See thread → Type reply → Done

## Features Implemented

### 1. **Data Model Updates**
- **ThreadMessage model** (`ThreadModels.swift`):
  - Added `parentMessageId: String?` - Links replies to parent messages
  - Added `replyCount: Int?` - Tracks number of direct replies
  - Added helper properties: `isReply` and `hasReplies`

### 2. **Backend Support**
- **ThreadService** (`ThreadService.swift`):
  - Updated `sendMessage()` to accept `parentMessageId` parameter
  - Added `incrementReplyCount()` method using Firestore atomic increment
  - Updated `parseMessage()` to read threading fields from Firestore
  - Automatic reply count updates when replies are sent

### 3. **UI Components**

#### TimelineCard Enhancements
- **Reply button**: Tap to start replying to a message
- **Reply count badge**: Shows number of replies (e.g., "2 replies")
- **Visual distinction**: Reply cards have different styling (lighter background, accent border)
- **No long-press required**: Simple tap on "Reply" button

#### Threaded Display
- **Parent messages**: Show with reply count and reply button
- **Indented replies**: Visually nested under parent with connecting line
- **Expand/collapse**: Tap parent message to toggle thread visibility
- **Auto-expand**: Threads automatically expand when you send a reply

### 4. **Chat Composer**
- **Reply indicator**: Shows who you're replying to with message preview
- **Cancel reply**: Tap X to cancel and return to normal message mode
- **Visual feedback**: Blue accent bar and preview of parent message

## User Flow

### Replying to a Message
1. User sees a message in the timeline
2. Tap the message card
3. **Sheet opens** showing:
   - Parent message at top (full context)
   - All existing replies below
   - Reply input field at bottom
4. Type reply and tap send
5. Reply is added to the thread
6. Sheet auto-dismisses after sending
7. Timeline updates to show reply count

### Viewing Threads
1. Messages with replies show a reply count badge (e.g., "2 💬")
2. Tap any message card → Opens thread sheet
3. Thread sheet shows:
   - Parent message
   - All replies (if any)
   - Reply input field
4. No inline expansion - keeps timeline clean

### Thread Sheet Features
- **Parent message**: Full message text with author and timestamp
- **Reply list**: All replies in chronological order
- **Reply input**: Clean text field with send button
- **Done button**: Close sheet and return to timeline
- **Auto-dismiss**: Sheet closes automatically after sending reply

## Technical Details

### Thread Organization
- **Top-level messages**: `parentMessageId == nil`
- **Replies**: `parentMessageId != nil`
- Timeline only shows top-level messages initially
- Replies are fetched and rendered when thread is expanded

### State Management
- `selectedThreadMessage: ThreadMessage?` - Tracks which thread to show in sheet
- `showingThreadSheet: Bool` - Controls sheet presentation
- No inline expansion state needed - everything happens in the sheet

### Visual Design

**Timeline:**
- **Message cards**: Tappable cards with reply count badge (if replies exist)
- **Clean layout**: No buttons, no inline threads, no indentation
- **Reply count badge**: Small blue badge showing number of replies

**Thread Sheet (Native Messaging Style):**
- **Chat bubbles**: Messages displayed as rounded bubbles
- **Current user**: Blue bubbles aligned to the right
- **Other users**: Gray bubbles aligned to the left with author name
- **Timestamps**: Small timestamp below each bubble
- **Conversation flow**: Natural back-and-forth like iMessage/Slack
- **Input field**: Fixed at bottom with send button

## Data Structure

### Firestore Schema
```
maintenance_requests/{requestId}/thread_messages/{messageId}
{
  id: string
  requestId: string
  authorId: string
  message: string
  type: string
  parentMessageId?: string  // NEW: Links to parent
  replyCount?: number       // NEW: Count of replies
  createdAt: timestamp
}
```

### Atomic Updates
- Reply count uses Firestore `FieldValue.increment(1)`
- Ensures accurate counts even with concurrent replies
- No race conditions or count drift

## Benefits

1. **Clean Timeline**: No inline reply UI cluttering the main view
2. **Native Messaging UX**: Chat bubbles like iMessage/Slack - instantly familiar
3. **Visual Clarity**: Current user (blue, right) vs others (gray, left)
4. **Focused Conversation**: Thread sheet shows only relevant messages
5. **Natural Flow**: Back-and-forth conversation is easy to follow
6. **Simple Interaction**: Single tap to reply, no complex gestures
7. **Organized Threads**: Multiple discussions stay separate
8. **Real-time Updates**: Firestore listener updates counts automatically
9. **Better Mobile UX**: Dedicated screen space for replying

## Files Modified

1. **Models/ThreadModels.swift**
   - Added threading fields to ThreadMessage

2. **Services/ThreadService.swift**
   - Added reply support to sendMessage
   - Added incrementReplyCount method
   - Updated parseMessage for threading

3. **Features/IssueDetail/IssueDetailView.swift**
   - Added thread sheet state variables
   - Updated TimelineCard with reply button
   - Added sheet presentation for threads
   - Implemented thread rendering with indentation
   - Added expand/collapse functionality

4. **Features/IssueDetail/ThreadSheetView.swift** (NEW)
   - Dedicated sheet view for thread conversations
   - Shows parent message + all replies
   - Clean reply input at bottom
   - Auto-dismiss after sending

## Future Enhancements

- Jump to parent message from reply
- Quote parent message text in reply
- Notification when someone replies to your message
- Thread-level muting/following
- Reply depth limits (prevent deeply nested threads)
