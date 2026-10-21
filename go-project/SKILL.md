---
name: go-project
description: Go Modularization Protocol (GMP) — refactor or design Go backend features (Fiber) into clean layers handler → service → repository with strict boundaries, consistent errors, context propagation and testable interfaces. Use when refactoring fat handlers/god services, reviewing Go code against the pattern, adding a new resource, or bootstrapping a Go API project structure.
user-invocable: true
---

# Go Modularization Protocol (GMP) v1

A standardized framework for turning tangled Go backend code (fat handlers, SQL in
handlers, global state, god services) into layered, testable feature modules.

## Core Mandate: Dependencies Point Inward

```text
Handler (Fiber)  →  Service  →  Repository  →  DB / Redis / External API
```

Each layer depends only on the **interface** of the layer below it. Concrete types
are wired in exactly one place: `internal/app/<binary>/app.go`.

## Recommended Structure

```text
cmd/<binary>/main.go                 # 🚪 ENTRY: calls app.Run() only
internal/
├── app/<binary>/
│   ├── app.go                       # 🔌 WIRING: config → infra → repo → svc → route, graceful shutdown
│   ├── route/route.go               # 🗺️ ROUTES: global middleware, public/private groups
│   ├── middleware/                  # 🛡️ AUTH / LOGGING / RBAC for this binary
│   ├── handler/[resource]_handler.go# 🌐 HTTP: parse → call svc → .JSON(c)
│   └── service/[resource]/
│       ├── [resource]_svc.go        # 📜 CONTRACT: interface + Req/Res structs (validate tags)
│       ├── [resource]_svc_impl.go   # 🧠 LOGIC: business rules, cache, tx boundary
│       └── [resource]_svc_test.go   # 🧪 TEST: table-driven, mocked repo
├── repository/[resource]/
│   ├── [resource]_repo.go           # 📜 CONTRACT: interface
│   ├── [resource]_repo_impl.go      # 🗄️ DATA: queries only
│   └── [resource]_repo_mock.go      # 🎭 MOCK: testify/mock
├── data/orm/[resource].go           # 🧱 MODELS: DB structs (never serialized to clients)
├── domain/errors.go                 # ⚠️ SENTINELS: ErrNotFound, ErrAlreadyExists, ...
├── meta/                            # ⚙️ STATIC: cache keys, TTLs, Locals keys, permission keys
├── config/config.go                 # 🔧 CONFIG: typed struct, the only place reading env
└── util/                            # 🧰 SHARED: response, web, validation, logger, postgresql, redisdb, cachedb
```

Service shared by several binaries → `internal/service/[area]/` instead of
`internal/app/<binary>/service/`.

## Layer Guidelines

### 1. Naming & Scaling
- Files `snake_case.go`; packages lowercase single word; service packages end `svc`
  (`usersvc`), repository packages end `repo` (`userrepo`).
- Constructors `New` / `NewXxx`, returning the **interface**: `func New(repo userrepo.UserRepo, ...) UserSvc`.
- Interface + `_impl` split only when it pays off; a resource with ≤ 2 trivial
  methods may keep interface and impl in one file.
- **Rule of Three:** helper used by 3+ resources → `internal/util/`.

### 2. Handler (`handler/`)
- Implements `web.HTTPHandler { Init(router fiber.Router) }` and registers its own routes.
- Only: `ParamsParser` / `QueryParser` / `BodyParser` → `svc.X(c.UserContext(), req)` → `.JSON(c)`.
- Parse failure → `response.BadRequest[any]().JSON(c)`.
- **Forbidden:** business rules, `if` on domain state, DB/Redis/repo access, building error messages.

```go
func (h *userHandler) GetInfo(c *fiber.Ctx) error {
    var req usersvc.GetInfoReq
    if err := c.ParamsParser(&req); err != nil {
        return response.BadRequest[any]().JSON(c)
    }
    return h.svc.GetInfo(c.UserContext(), req).JSON(c)
}
```

### 3. Service (`service/`)
- Validates first: `if m := s.validate.Check(req); len(m) > 0 { return response.ValidationFailed[T](m) }`.
- Returns `response.Response[T]` — the service decides the status code; the handler never does.
- Maps domain errors with `errors.Is` → `NotFound` / `Conflict` / `InternalServerError(err, msg)`.
- Owns transactions (`db.Transaction(...)`) and caching (read-through: cache → repo → set; invalidate on write).
- Maps ORM → `XxxRes` via a private `toXxxRes`. ORM structs never leave as JSON.
- **Forbidden:** `*fiber.Ctx`, `os.Getenv`, constructing its own dependencies, global singletons.

### 4. Repository (`repository/`)
- Every method takes `ctx` first and uses `db.WithContext(ctx)`.
- Translates driver errors: not found → `domain.ErrNotFound`, unique violation → `domain.ErrAlreadyExists`.
  Update/Delete with `RowsAffected == 0` → `domain.ErrNotFound`.
- Wraps everything else: `fmt.Errorf("find user %s: %w", id, err)`.
- **Forbidden:** business rules, logging, calling other repos/services/HTTP, `Raw`/`Exec` with string concatenation.

### 5. Request / Response Contracts (`*_svc.go`)
- `XxxReq` carries Fiber tags (`params` / `query` / `json`) **and** `validate` tags; path IDs use `json:"-"`.
- `XxxRes` has explicit `json` tags in camelCase; only fields the client needs (least privilege).

### 6. Response Wrapper (`util/response`)
Single shape for every endpoint, including Fiber's central `ErrorHandler`:
```json
{ "success": false, "statusCode": 400, "message": "validation failed", "validationErrors": { "email": "email" }, "data": null }
```
`Error` is `json:"-"` — kept for the request logger, never returned to clients. 5xx messages are generic.

### 7. Wiring (`app.go`)
- Order: `config.Load()` → logger → DB/Redis (ping, `defer Close`) → repos → services → `route.New(Deps{...})`.
- `signal.NotifyContext` + `app.ShutdownWithContext` with a timeout; `Listen` error ends the process.
- `main.go` contains nothing but `app.Run()`.

## Cross-Cutting Rules

| Concern | Rule |
|---|---|
| Context | First param of every I/O func; handlers pass `c.UserContext()`; external calls use `context.WithTimeout` + `defer cancel()` |
| Errors | Return, don't panic (bootstrap excepted); wrap with `%w`; compare with `errors.Is/As`; sentinels in `domain/` |
| Config | `os.Getenv` only in `config/`; inject `*Config` or a sub-struct; fail fast on missing required values |
| Logging | Inject `*slog.Logger`; JSON in production; log at handler/middleware boundary and for business events in service; repos stay silent; never log secrets/PII |
| Concurrency | Every goroutine has a cancel path via `ctx`; `errgroup` for fan-out; no fire-and-forget |
| Globals | No package-level mutable state (DB, clients, caches) — pass via constructors |
| Constants | Cache keys, TTLs, Locals keys, permission keys live in `meta/` |

## Testing Strategy
- **Service:** table-driven unit tests with `[resource]_repo_mock.go` and a fake cache;
  assert `res.StatusCode` per case and `repo.AssertExpectations(t)`.
- **Repository:** integration tests against real Postgres (docker / testcontainers), build tag `integration`.
- **Handler:** `app.Test(httptest.NewRequest(...))` with a mocked service.
- `go vet ./...` and `go test ./... -race` must pass; target ≥ 80% coverage on service + util.

## Security Checklist
1. No hardcoded secrets — everything from `config/`; `.env` gitignored.
2. Validate every request in the service before touching the repo.
3. Parameterised queries only.
4. Write endpoints behind auth middleware; RBAC enforced server-side.
5. 5xx responses never expose internal error text.
6. CORS origins explicit — no `*` with credentials.

## Smell → Fix

| Smell | Fix |
|---|---|
| SQL / `db.` call in a handler | Move to repo method; handler calls service |
| Handler returns different JSON shapes | Service returns `response.Response[T]`; handler `.JSON(c)` |
| `if err == gorm.ErrRecordNotFound` in service | Repo returns `domain.ErrNotFound`; service uses `errors.Is` |
| `NewXxx()` builds its own DB/client | Inject via constructor; wire in `app.go` |
| Global `var DB *gorm.DB` | Pass `*gorm.DB` to repo constructors |
| `os.Getenv` scattered | Add field to `Config` |
| Service takes `*fiber.Ctx` | Take `ctx` + `XxxReq` |
| ORM struct returned as JSON | Add `XxxRes` + `toXxxRes` mapper |
| Untestable service (concrete deps) | Depend on repo interface; add `_mock.go` |
| `go func()` without ctx | Pass ctx, select on `ctx.Done()`, or use `errgroup` |

## Refactoring Workflow

1. **Survey:** read the target code and list smells using the table above. If the
   project already has a consistent convention that differs (e.g. sqlx instead of GORM,
   different folder names), keep the project's convention and apply the *rules*, not the names.
2. **Sentinels & Constants:** add `domain/errors.go` entries and `meta/` keys.
3. **Repository:** extract data access into interface + impl + mock; translate errors.
4. **Contracts:** define `XxxReq` / `XxxRes` with tags in `[resource]_svc.go`.
5. **Service:** move business logic in; validate → repo → map → `response.Response[T]`.
6. **Handler:** shrink to parse → service → `.JSON(c)`; register via `Init(router)`.
7. **Wire:** construct repo → service → handler in `app.go` / `route.go`; delete globals.
8. **Test:** table-driven service tests with the repo mock.
9. **Verify:** `gofmt -l .`, `go vet ./...`, `go build ./...`, `go test ./... -race` — all clean before reporting done.
   Report which smells were fixed and any left with the reason.

For a **new resource**, run steps 2–9 directly. For a **new project**, create the
Recommended Structure first (`go mod init`, config, util/response, util/web,
util/validation, logger, postgresql, app.go, route.go, `/health`, Makefile,
Dockerfile, `.env.example`), then add the first resource with steps 2–9.
