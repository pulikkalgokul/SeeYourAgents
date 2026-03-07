# SeeAgents

A macOS app that detects running Claude Code sessions and displays them as live, status-tracked agents. It finds `claude` processes, maps them to JSONL transcript files, tails those files in real-time, and parses each line to show what the agent is doing.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                       SeeAgentsApp                           │
│                     (@main entry point)                      │
│                            │                                 │
│                   creates & owns                             │
│                            ▼                                 │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │                    AgentManager                          │ │
│ │              (orchestrator / brain)                       │ │
│ │                                                          │ │
│ │  agents: [Int: AgentActivity]   <-- UI reads this        │ │
│ │  watchers: [Int: AgentWatcher]                           │ │
│ │  timerManager: TimerManager                              │ │
│ │  scanner: ProjectScanner                                 │ │
│ └──────┬──────────────┬──────────────┬─────────────────────┘ │
│        │              │              │                        │
│        ▼              ▼              ▼                        │
│  ProjectScanner  AgentWatcher   TimerManager                 │
│  (find sessions) (tail files)  (idle/permission)             │
│                       │                                      │
│                       ▼                                      │
│                TranscriptParser                               │
│                (decode JSONL lines)                           │
│                                                              │
│ ───────────────── UI Layer ─────────────────                 │
│                                                              │
│ ContentView -- AgentRow -- StatusIndicator                   │
│            └-- AgentDetailView                               │
└──────────────────────────────────────────────────────────────┘
```

---

## How It Works

### 1. Process Discovery (`ProjectScanner`)

Runs every 2 seconds on a background queue. Finds active Claude Code sessions by bridging from OS processes to JSONL transcript files.

```
Run `ps -eo pid,comm`
  Filter for comm == "claude"
       │
       ▼
For each PID, run `lsof -a -p <PID> -d cwd -Fn`
  Extract the working directory (cwd)
  e.g. /Users/you/Desktop/MyProject
       │
       ▼
Convert cwd to Claude's project hash format
  /Users/you/Desktop/MyProject
  → -Users-you-Desktop-MyProject
       │
       ▼
Look in ~/.claude/projects/<hash>/
  List JSONL files, sort by modification date
  Take top N files (N = number of claude processes in that dir)
       │
       ▼
Report new sessions → onSessionFound
Report dead sessions → onSessionLost
```

**Key insight:** Claude Code stores conversation transcripts at `~/.claude/projects/<hashed-cwd>/<session-id>.jsonl`. The scanner bridges from running OS processes to those files.

### 2. File Watching (`AgentWatcher`)

When `AgentManager` receives `onSessionFound`, it creates an `AgentActivity` model and an `AgentWatcher` to tail the JSONL file.

The watcher uses **kqueue** (`DispatchSource`) to get OS-level notifications when the file is written to:

```
DispatchSource (kqueue)
  OS kernel notifies on .write / .extend
       │
       ▼
  readNewLines()
       │
       ▼
  Is file size > our saved offset?
    No  → return (nothing new)
    Yes → Seek to offset, read new bytes
       │
       ▼
  Prepend leftover lineBuffer from last read
  Split by "\n"
       │
       ├── Complete lines (all but last) → send to callback
       └── Last fragment → save as lineBuffer (might be incomplete)
       │
       ▼
  Dispatch FileReadResult to main queue
       │
       ▼
  AgentManager's onNewLines callback fires
```

### 3. JSONL Parsing (`TranscriptParser`)

Each complete JSONL line is a JSON object with a `type` field. The parser decodes it and updates the agent's state.

**Record types:**

| Type | Meaning |
|------|---------|
| `"assistant"` | Claude's response (may contain `tool_use` blocks) |
| `"user"` | User input or `tool_result` returning from a tool |
| `"system"` | System events (`turn_duration` = turn ended) |
| `"progress"` | Live progress (bash output, sub-agent activity) |

**What each handler does:**

- **`assistant`** — If it contains `tool_use` blocks: track each tool (id, name, human-readable status), set status to active, start 7s permission timer. If text-only: start 5s idle timer.
- **`user`** — If it contains `tool_result` blocks: remove completed tools from tracking. If plain text (new prompt): reset everything to active.
- **`system`** (subtype `turn_duration`) — Turn is definitively over. Clear all tool state, set status to waiting.
- **`progress`** — `bash_progress`/`mcp_progress` restart the permission timer (tool is alive). `agent_progress` tracks sub-agent tools within a Task tool.

### 4. Status State Machine

```
                   ┌─────────┐
       ┌──────────>│  ACTIVE  │<────────────────────┐
       │           │ (green)  │                      │
       │           └────┬─────┘                      │
       │                │                            │
       │   text-only    │   tool_use detected        │
       │   response     │                            │
       │                ▼                            │
       │   ┌─── 5s idle timer ───┐                   │
       │   │                     │                   │
       │   ▼                     │ (cancelled if     │
  ┌─────────────┐            tools start)            │
  │   WAITING   │                                    │
  │   (blue)    │                                    │
  └─────────────┘                                    │
       ▲                                             │
       │                          7s permission      │
  system/turn_duration            timer fires        │
  (turn ended)                        │              │
                                      ▼              │
                              ┌──────────────┐       │
                              │  PERMISSION  │───────┘
                              │  (orange)    │
                              └──────────────┘
                                new data arrives
                                → clears permission
```

### 5. Timer System (`TimerManager`)

Two kinds of timers infer status when there's no explicit signal:

| Timer | Starts When | Delay | Effect |
|-------|-------------|-------|--------|
| **Waiting** | Assistant sends text-only response | 5s | `status = .waiting` |
| **Permission** | A non-exempt tool begins | 7s | `status = .permission` |

Both are cancelled when new data arrives from the file watcher.

**Why 7 seconds for permission?** If Claude invoked a tool (like `Edit`) and 7 seconds pass with no progress or result, it likely means the tool is waiting for user permission in the terminal.

**Exempt tools** (don't trigger permission timer): `Task`, `AskUserQuestion`

---

## Data Model

### `AgentActivity` (`@Observable`)

| Property | Type | Purpose |
|----------|------|---------|
| `id` | `Int` | Unique agent number |
| `projectDir` | `String` | `~/.claude/projects/<hash>` |
| `jsonlFile` | `String` | Full path to `.jsonl` file |
| `fileOffset` | `UInt64` | How far we've read into the file |
| `lineBuffer` | `String` | Incomplete last line from previous read |
| `activeToolIds` | `Set<String>` | Currently running tool IDs |
| `activeToolStatuses` | `[String: String]` | toolId → "Reading main.swift" |
| `activeToolNames` | `[String: String]` | toolId → "Read" |
| `activeSubagentToolIds` | `[String: Set<String>]` | parentId → sub-tool IDs |
| `activeSubagentToolNames` | `[String: [String: String]]` | parentId → (subId → name) |
| `isWaiting` | `Bool` | Idle / awaiting next prompt |
| `permissionSent` | `Bool` | Tool stuck on permission |
| `hadToolsInTurn` | `Bool` | Did this turn use tools? |
| `status` | `AgentStatus` | `.active` / `.waiting` / `.permission` |

### `TranscriptRecord` (Decodable)

```
TranscriptRecord
├── type: String              ("assistant", "user", "system", "progress")
├── subtype: String?          ("turn_duration" for system)
├── parentToolUseId: String?  (which tool a progress event belongs to)
├── message: TranscriptMessage?
│   ├── role: String?
│   └── content: MessageContent?
│       ├── .string(String)           plain text
│       └── .blocks([ContentBlock])   structured content
│           ├── type: "tool_use"      Claude calling a tool
│           │   ├── id, name, input
│           ├── type: "tool_result"   Result coming back
│           │   └── toolUseId
│           └── type: "text"          Plain text block
└── data: ProgressData?
    ├── type: String?         ("bash_progress", "agent_progress", ...)
    └── message: TranscriptMessage?   (nested for sub-agents)
```

---

## End-to-End Data Flow

```
Claude Code runs in terminal
     │
     │ writes JSONL lines to
     ▼
~/.claude/projects/<hash>/<session>.jsonl
     │
     │ discovered by
     ▼
ProjectScanner (ps → lsof → find JSONL)
     │
     │ onSessionFound
     ▼
AgentManager.addAgent()
     │
     ├── creates AgentActivity (model)
     └── creates AgentWatcher (file tailer)
            │
            │ kqueue detects new bytes
            ▼
       readNewLines() → splits into complete JSONL lines
            │
            │ dispatches to main queue
            ▼
       AgentManager.onNewLines callback
            │
            ├── cancels timers, clears permission if needed
            └── for each line:
                   │
                   ▼
            TranscriptParser.processLine()
                   │
                   ├── tracks tool_use / tool_result
                   ├── manages waiting/permission timers
                   └── updates AgentActivity properties
                          │
                          │ @Observable triggers SwiftUI
                          ▼
                   ContentView re-renders
```

---

## Threading Model

```
┌──────────────────────┐     ┌─────────────────────────────┐
│     Main Queue       │     │   Background (utility QoS)  │
│     (MainActor)      │     │                             │
│                      │     │  ProjectScanner.scan()      │
│  AgentManager        │<────│    ps, lsof, file listing   │
│  AgentActivity       │     │                             │
│  TimerManager        │     │  AgentWatcher               │
│  TranscriptParser    │     │    readNewLines()           │
│  SwiftUI views       │     │    kqueue events            │
│                      │     │                             │
└──────────────────────┘     └─────────────────────────────┘
         ▲                              │
         │    DispatchQueue.main.async  │
         └──────────────────────────────┘
```

All state mutations happen on the main queue. Background queues only do I/O (reading files, running `ps`/`lsof`) and dispatch results back to main.

---

## Project Structure

```
SeeAgents/SeeAgents/
├── SeeAgentsApp.swift                 @main entry point
├── ContentView.swift                  NavigationSplitView UI
├── Constants/
│   └── GameConstants.swift            Timing, paths, exempt tools
├── Models/
│   ├── AgentActivity.swift            Per-agent observable state
│   └── TranscriptRecord.swift         Codable JSONL record types
└── AgentDetection/
    ├── ProjectScanner.swift           Scans for claude processes + JSONL files
    ├── AgentWatcher.swift             Tails a single JSONL file (kqueue)
    ├── AgentManager.swift             Orchestrates scanner + watchers
    ├── TranscriptParser.swift         Parses JSONL lines → state updates
    └── TimerManager.swift             Waiting + permission timers
```
