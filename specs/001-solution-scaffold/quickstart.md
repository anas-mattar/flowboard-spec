# Quickstart — 001 Solution Scaffold

How to run and verify this feature locally once implemented.

## Prerequisites

- .NET SDK 10.0.2xx (pinned by `flowboard-api/global.json`)
- Node 22 + npm

## 1. Start the backend

```powershell
cd D:\solutions\flowboard\flowboard-api
dotnet run --project src/Flowboard.Api
```

Serves on `http://localhost:5111` (launchSettings, HTTP profile). Verify directly:

```powershell
curl http://localhost:5111/v1/health
# → {"status":"ok","service":"flowboard-api","version":"...","timestampUtc":"..."}
```

## 2. Start the frontend

```powershell
cd D:\solutions\flowboard\flowboard-web
Copy-Item .env.example .env.local   # first time only; sets FLOWBOARD_API_URL
npm run dev
```

Open `http://localhost:3000`.

## 3. Verify the user stories

| Story | Check |
|---|---|
| US1 — alive end-to-end | Page shows **FlowBoard** and backend status **ok** within 5 s |
| US2 — theme | Toggle theme → whole page switches instantly; reload → same theme, no flash |
| US3 — backend down | Stop the backend (Ctrl+C), reload → shell still renders; status shows the explicit error state (✕ message — distinct from the "…" loading state) |
| Edge — first visit | Clear site data → theme follows OS preference |

## 4. Gates (run by the feature owner; agent runs are feedback only)

```powershell
cd D:\solutions\flowboard\flowboard-api ; dotnet build --warnaserror && dotnet test
"EXIT: $LASTEXITCODE"
```

```powershell
cd D:\solutions\flowboard\flowboard-web ; npm run lint && npm run build
"EXIT: $LASTEXITCODE"
```

Both must print `EXIT: 0`. Phase A is certified by the first, Phase B by the second.
