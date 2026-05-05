# Claude Code Viewer API Reference

Complete API documentation extracted from the source code at [d-kimuson/claude-code-viewer](https://github.com/d-kimuson/claude-code-viewer).

## Table of Contents

- [Overview](#overview)
- [Starting the Server](#starting-the-server)
- [Frontend URL Format](#frontend-url-format)
- [API Endpoints](#api-endpoints)
  - [Authentication](#authentication)
  - [Configuration](#configuration)
  - [Projects](#projects)
  - [Sessions](#sessions)
  - [Search](#search)
  - [Git Operations](#git-operations)
  - [Claude Code](#claude-code)
  - [Session Processes](#session-processes)
  - [Scheduler](#scheduler)
  - [File System](#file-system)
  - [Tasks](#tasks)
  - [Feature Flags](#feature-flags)
  - [SSE (Server-Sent Events)](#sse-server-sent-events)

---

## Overview

- **Package**: `@kimuson/claude-code-viewer`
- **Source**: https://github.com/d-kimuson/claude-code-viewer
- **Default Port**: 3000 (configurable with `-p`)
- **Data Source**: `~/.claude/projects/`

---

## Starting the Server

```powershell
# Using the local startup script
powershell -File "C:\code\claude\code-viewer\start-claude-viewer.ps1"

# Or directly
C:\Users\IT.XYZ\AppData\Roaming\npm\claude-code-viewer.cmd -p 3400 -h 0.0.0.0

# Hidden window (background)
Start-Process -FilePath 'C:\Users\IT.XYZ\AppData\Roaming\npm\claude-code-viewer.cmd' -ArgumentList '-p 3400 -h 0.0.0.0' -WindowStyle Hidden
```

**CLI Options:**
```
-p, --port <port>              Port to listen on (default: 3000)
-h, --hostname <hostname>      Hostname to listen on (default: localhost)
-P, --password <password>      Password for authentication
-e, --executable <executable>  Path to Claude Code executable
--claude-dir <claude-dir>      Path to Claude directory
```

---

## Frontend URL Format

### Project List
```
http://localhost:3400/
```

### Project View
```
http://localhost:3400/projects/{projectId}
```

### Session View (CORRECT FORMAT)
```
http://localhost:3400/projects/{projectId}/session?tab=sessions&sessionId={sessionId}
```

**Example:**
```
http://localhost:3400/projects/QzpcVXNlcnNcSVQuWFlaXC5jbGF1ZGVccHJvamVjdHNcQy0tY29kZS1XaW5kb3dzLWZyZW5jaA/session?tab=sessions&sessionId=0a07a636-50ac-4502-bbbf-42c1093984a6
```

---

## API Endpoints

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/login` | Login with password |
| POST | `/api/auth/logout` | Logout (clear session) |
| GET | `/api/auth/check` | Check authentication status |

```bash
# Login
curl -X POST http://localhost:3400/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"password": "your-password"}'

# Check auth status
curl http://localhost:3400/api/auth/check
```

---

### Configuration

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/config` | Get current config |
| PUT | `/api/config` | Update config |
| GET | `/api/version` | Get viewer version |

---

### Projects

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/projects` | List all projects |
| GET | `/api/projects/:projectId` | Get project details (with optional cursor) |
| POST | `/api/projects` | Create new project |
| GET | `/api/projects/:projectId/latest-session` | Get latest session for project |

```bash
# List all projects
curl http://localhost:3400/api/projects

# Get project with pagination
curl "http://localhost:3400/api/projects/{projectId}?cursor=xxx"

# Create project
curl -X POST http://localhost:3400/api/projects \
  -H "Content-Type: application/json" \
  -d '{"projectPath": "C:\\code\\my-project"}'
```

---

### Sessions

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/projects/:projectId/sessions/:sessionId` | Get session details |
| GET | `/api/projects/:projectId/sessions/:sessionId/export` | Export session as HTML |
| DELETE | `/api/projects/:projectId/sessions/:sessionId` | Delete session |
| GET | `/api/projects/:projectId/agent-sessions/:agentId` | Get agent session |

```bash
# Get session
curl "http://localhost:3400/api/projects/{projectId}/sessions/{sessionId}"

# Export session
curl "http://localhost:3400/api/projects/{projectId}/sessions/{sessionId}/export"
```

---

### Search

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/search` | Full-text search across conversations |

**Query Parameters:**
- `q` (required): Search query (min 2 chars)
- `limit` (optional): Max results
- `projectId` (optional): Limit to specific project

```bash
# Search all projects
curl "http://localhost:3400/api/search?q=native+installer"

# Search within project
curl "http://localhost:3400/api/search?q=alias&projectId={projectId}&limit=20"
```

**Response:**
```json
{
  "results": [
    {
      "projectId": "...",
      "projectName": "...",
      "sessionId": "...",
      "conversationIndex": 1,
      "type": "user|assistant",
      "snippet": "...matching text...",
      "timestamp": "2026-01-22T14:53:41.149Z",
      "score": 52.44
    }
  ]
}
```

---

### Git Operations

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/projects/:projectId/git/current-revisions` | Get current git revisions |
| POST | `/api/projects/:projectId/git/diff` | Get diff between refs |
| POST | `/api/projects/:projectId/git/commit` | Commit files |
| POST | `/api/projects/:projectId/git/push` | Push commits |
| POST | `/api/projects/:projectId/git/commit-and-push` | Commit and push |

```bash
# Get diff
curl -X POST "http://localhost:3400/api/projects/{projectId}/git/diff" \
  -H "Content-Type: application/json" \
  -d '{"fromRef": "HEAD~1", "toRef": "HEAD"}'
```

---

### Claude Code

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/projects/:projectId/claude-commands` | Get available commands |
| GET | `/api/projects/:projectId/mcp/list` | List MCP servers |
| GET | `/api/cc/meta` | Get Claude Code metadata |
| GET | `/api/cc/features` | Get available features |

---

### Session Processes

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/cc/session-processes` | List running session processes |
| POST | `/api/cc/session-processes` | Create new session (or resume) |
| POST | `/api/cc/session-processes/:id/continue` | Continue existing session |
| POST | `/api/cc/session-processes/:id/abort` | Abort session |
| POST | `/api/cc/permission-response` | Respond to permission request |

---

### Scheduler

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/scheduler/jobs` | List scheduled jobs |
| POST | `/api/scheduler/jobs` | Create scheduled job |
| PATCH | `/api/scheduler/jobs/:id` | Update scheduled job |
| DELETE | `/api/scheduler/jobs/:id` | Delete scheduled job |

---

### File System

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/fs/file-completion` | Get file completions |
| GET | `/api/fs/directory-browser` | Browse directories |

```bash
# File completion
curl "http://localhost:3400/api/fs/file-completion?projectId={projectId}&basePath=/src/"

# Directory browser
curl "http://localhost:3400/api/fs/directory-browser?currentPath=C:/code&showHidden=false"
```

---

### Tasks

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/tasks` | List tasks |
| POST | `/api/tasks` | Create task |
| PATCH | `/api/tasks/:id` | Update task |

```bash
# List tasks
curl "http://localhost:3400/api/tasks?projectId={projectId}&sessionId={sessionId}"
```

---

### Feature Flags

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/flags` | Get feature flags |

---

### SSE (Server-Sent Events)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/sse` | Real-time event stream |

---

## Example Workflow: Find a Conversation

```bash
# 1. Search for keywords
curl -s "http://localhost:3400/api/search?q=native+installer" | jq '.results[0]'

# 2. Extract projectId and sessionId from results
# 3. Build the frontend URL:
#    http://localhost:3400/projects/{projectId}/session?tab=sessions&sessionId={sessionId}

# 4. Open in browser
start "http://localhost:3400/projects/{projectId}/session?tab=sessions&sessionId={sessionId}"
```

---

## Related Files

| File | Purpose |
|------|---------|
| `C:\code\claude\code-viewer\start-claude-viewer.ps1` | Startup script |
| `C:\Users\IT.XYZ\AppData\Roaming\npm\node_modules\@kimuson\claude-code-viewer` | Installed package |
| `C:\Users\IT.XYZ\.claude\projects\` | Conversation data |
| `C:\Users\IT.XYZ\.claude\viewer-service.log` | Service log |

---

## Source Code

- **Repository**: https://github.com/d-kimuson/claude-code-viewer
- **Routes**: `src/server/hono/route.ts`
- **Version**: 0.5.4 (as of this documentation)
