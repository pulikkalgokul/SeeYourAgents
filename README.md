# SeeAgents

SeeAgents is a macOS app that detects your running [Claude Code](https://claude.ai/code) sessions and visualizes them as live, animated agents working in a virtual office.

## Demo

<!-- Add screen recording here -->
https://github.com/user-attachments/assets/YOUR-SCREEN-RECORDING-ID

> *Replace the placeholder above with your screen recording once uploaded to GitHub.*

## What It Does

SeeAgents monitors Claude Code processes in real time and reflects their activity as characters in a pixel-art office scene. Each agent is shown typing at a desk when working, idle when waiting, and highlighted when it needs your attention.

- **Auto-detects** Claude Code sessions by scanning running processes
- **Tails transcript files** live using OS-level kqueue notifications
- **Parses agent activity** from JSONL transcript records
- **Renders a live office** where each agent is a character at a desk
- **Tracks tool activity** including sub-agents spawned via the Task tool

## Status Indicators

| Status | Color | Meaning |
|--------|-------|---------|
| Active | Green | Executing tools |
| Thinking | Purple | Generating a response |
| Waiting | Blue | Idle after responding |
| Permission | Orange | Waiting on your input |

## Views

**Office View** — A SpriteKit-powered pixel-art office. Each Claude Code session appears as a character at a desk, animated based on current activity. Pan and zoom to explore.

**Debug View** — A list-based SwiftUI view showing raw agent state: session ID, active tools, sub-agent tool hierarchy, and status.

## How It Works

```
claude process → JSONL transcript file → kqueue notification
  → parse JSON → update agent state → animate character in office
```

1. Every 2 seconds, SeeAgents scans for `claude` processes using `ps`
2. It resolves each process's working directory via `lsof`
3. It maps the directory to a hashed path under `~/.claude/projects/`
4. It watches the most recent JSONL transcript file for each session
5. New lines are parsed and agent state is updated in real time

## Requirements

- macOS 13+
- [Claude Code](https://claude.ai/code) installed and running sessions

## Building

1. Clone the repo
2. Open `SeeAgents.xcodeproj` in Xcode
3. Build and run (no external dependencies)

All dependencies are native Apple frameworks — SwiftUI, SpriteKit, AppKit, and Foundation. No package manager required.

## Architecture

```
AgentDetection/
  AgentManager.swift       — Orchestrates scanning and file watching
  ProjectScanner.swift     — Finds claude processes and maps to transcript files
  AgentWatcher.swift       — Tails JSONL files via kqueue
  TranscriptParser.swift   — Decodes JSONL and updates agent state
  TimerManager.swift       — Manages idle and permission timers

Office/
  OfficeScene.swift        — SpriteKit scene, camera, pan/zoom
  OfficeState.swift        — Game state and character positions
  CharacterFSM.swift       — Character animation state machine
  AgentBridge.swift        — Syncs agent state to office characters

Rendering/
  CharacterSpriteLoader.swift
  FloorRenderer.swift
  WallRenderer.swift
  FurnitureRenderer.swift
  TextureCache.swift

Layout/
  OfficeLayout.swift       — Decodes office floor plan from JSON
  Pathfinding.swift        — A* pathfinding for character movement
  SeatGenerator.swift      — Assigns desk positions to agents
```
