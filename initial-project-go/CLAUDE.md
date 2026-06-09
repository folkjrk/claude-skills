# Project — Claude Code Guidelines (Go + Fiber)

## Tech Stack

| Layer | Library |
|---|---|
| Language | Go 1.22+ |
| HTTP Framework | Fiber v2 |
| ORM | GORM v2 |
| Database | PostgreSQL (`gorm.io/driver/postgres`) |
| Cache | Redis (`github.com/redis/go-redis/v9`) |
| Validation | `go-playground/validator/v10` |
| Auth | `golang-jwt/jwt/v5` |
| Config | `joho/godotenv` + env vars |
| Logging | `log/slog` (stdlib) — JSON handler in prod |
| Testing | `testing` + `testify` (assert, mock) |

---

## Project Layout

```
project-root/
├── cmd/                        # Application entry points (one main.go per binary)
│   ├── api/main.go
│   ├── worker/main.go
│   └── job/main.go
├── internal/                   # Private application code
│   ├── app/                    # Per-binary bootstrap + per-app handlers
│   │   ├── api/app.go          # API binary wiring (DI graph, server start)
│   │   └── weather-api/        # Per-app: handler/, service/, middleware/, route/
│   ├── config/                 # Config struct + loader
│   ├── data/                   # Shared data structs
│   │   ├── orm/                # GORM models
│   │   ├── dto/                # External-facing payloads (req/res)
│   │   └── event/              # Message/event payloads
│   ├── domain/                 # Business entities + domain errors
│   ├── repository/             # Data access (interface + impl per aggregate)
│   ├── service/                # Cross-app business logic
│   ├── util/                   # Shared utilities (response, logger, postgresql, redisdb, validation, web)
│   └── meta/                   # Constants, permission keys, cache keys
├── docs/                       # OpenAPI / swagger
├── go.mod / go.sum
├── Makefile
├── Dockerfile
└── .env.example
```

---

## Architecture — Clean Layers

```
Handler (Fiber)  →  Service  →  Repository  →  DB / Redis / External API
```

- **Handler**: parse request, validate DTO, call service, return wrapped response. No business logic.
- **Service**: business logic, orchestration, caching, transaction boundaries.
- **Repository**: data access only — no business rules, no HTTP, no logging side-effects.
- **Dependencies point inward**: handler depends on service *interface*, service depends on repo *interface*. Concrete types only injected at `app.go` bootstrap.

---

## Layer Rules

### `cmd/<binary>/main.go` — Entry point
- Thin file. Only calls `app.Run()`.
- One binary per use case (`api`, `worker`, `job`).

### `internal/app/<binary>/app.go` — Bootstrap
- Build the DI graph: load config → init logger → init DB/Redis → construct repos → construct services → construct handlers → register routes → start server.
- Wire **concrete types** here; everywhere else uses interfaces.
- Handle graceful shutdown (signal trap → server.Shutdown → close DB/Redis).

### `internal/repository/<aggregate>/` — Data access
- Two files: `<name>_repo.go` (interface) + `<name>_repo_impl.go` (GORM/Redis implementation).
- Every method takes `ctx context.Context` as the first arg.
- Return `*Domain` types or `[]*Domain`, not GORM models. Map ORM → domain inside the impl.
- Never call other repos, services, or HTTP from here.
- Return `domain.ErrNotFound` for missing rows (don't leak `gorm.ErrRecordNotFound`).

```go
type UserRepo interface {
    FindByID(ctx context.Context, id string) (*domain.User, error)
    Create(ctx context.Context, u *domain.User) error
}
```

### `internal/service/<area>/` or `internal/app/<binary>/service/` — Business logic
- Accept repo interfaces via constructor (`NewUserSvc(repo UserRepo, cache CacheClient) *UserSvc`).
- Wrap errors with context: `fmt.Errorf("get user %s: %w", id, err)`.
- Orchestrate multiple repos, manage transactions via a unit-of-work or `db.Transaction(...)`.
- No Fiber types here — must be reusable from `cmd/worker`.

### `internal/app/<binary>/handler/` — Fiber handlers
- One handler struct per resource: `UserHandler` with methods `GetByID`, `Create`, etc.
- Parse + validate DTO from request → call service → write response via `util/response`.
- **Never** call repos or DB directly.
- Use `c.UserContext()` (or `c.Context()`) — propagate to service.

```go
func (h *UserHandler) GetByID(c *fiber.Ctx) error {
    id := c.Params("id")
    user, err := h.svc.GetUser(c.UserContext(), id)
    if err != nil { return err } // central error handler maps to status
    return response.OK(c, user)
}
```

### `internal/app/<binary>/route/` — Route registration
- Group routes per resource. Apply middleware at the group level.
- Routes file knows about handlers + middleware only — no service references.

### `internal/app/<binary>/middleware/` — Per-binary middleware
- Reusable middleware (auth, RBAC, request-id, recover) lives in `internal/util/web/` if shared across binaries; binary-specific ones stay here.

### `internal/domain/` — Entities + errors
- Pure structs and domain errors (`ErrNotFound`, `ErrInvalidInput`).
- No `gorm` tags, no `json` tags (those belong in `data/orm` and `data/dto`).

### `internal/data/dto/` — Request/Response DTOs
- One file per resource. Use `validate:"..."` tags.
- Map DTO → domain explicitly in handler or a `Map*` helper — never pass DTOs into services.

### `internal/data/orm/` — GORM models
- `gorm:"..."` and `json:"-"` tags. Never expose ORM types past the repository boundary.

### `internal/util/response/` — Response wrapper
- Single response shape:
  ```json
  { "success": true, "data": ..., "message": "...", "pagination": { ... } }
  ```
- Helpers: `OK(c, data)`, `Created(c, data)`, `Paginated(c, data, page)`, `Error(c, err)`.

---

## Cross-Cutting Rules

### Imports & Packages
- Module path: `<org>/<project>` (e.g. `mycompany/weather-api`).
- Internal-only code under `internal/` — Go enforces visibility.
- Package names: short, lowercase, no underscores. Service packages end `svc`, repo packages end `repo` (`usersvc`, `userrepo`).
- Never `import _ "side-effect"` outside `cmd/` or `app/<binary>/app.go`.

### Context
- **Every** function that does I/O takes `ctx context.Context` as the first parameter.
- Pass `c.UserContext()` from Fiber handlers into services.
- Use `ctx, cancel := context.WithTimeout(ctx, 5*time.Second)` for external calls; always `defer cancel()`.

### Errors
- Return errors — don't panic (except truly unrecoverable bootstrap failures).
- Wrap with `fmt.Errorf("operation: %w", err)` to preserve the chain.
- Compare with `errors.Is` / `errors.As`.
- Define domain sentinels in `internal/domain/errors.go`.
- Central Fiber error handler maps `domain.ErrNotFound` → 404, `domain.ErrInvalidInput` → 400, validator errors → 422, default → 500.

### Validation
- Use `validator/v10` on DTOs in handler. Fail fast before calling service.
- Service layer assumes validated input but still guards critical invariants.

### Configuration
- `internal/config/config.go` defines a typed `Config` struct loaded from env vars (with `.env` fallback in dev).
- Never read `os.Getenv` outside `config/`. Pass `*Config` (or sub-sections) via constructor.

### Logging
- `log/slog` with JSON handler in production, text in dev.
- Inject a `*slog.Logger` via DI — don't use the global default.
- Log at the boundary: handler logs request errors, service logs business events, repo stays silent (let callers decide).
- Never log secrets, tokens, PII.

### Database
- GORM session created in `app.go`. Pass `*gorm.DB` only into repo constructors.
- Transactions: `db.Transaction(func(tx *gorm.DB) error { ... })` — service owns the boundary, repos accept `*gorm.DB` if they need to participate.
- Connection pool: `db.SetMaxOpenConns(25)`, `SetMaxIdleConns(5)`, `SetConnMaxLifetime(5*time.Minute)`.

### Cache (Redis)
- Wrap in `internal/util/redisdb/` + `internal/util/cachedb/` (typed get/set with TTL).
- Cache keys defined as constants in `internal/meta/cache_keys.go` (`CacheKeyUser = "user:%s"`).
- Read-through pattern in service: check cache → fallback to repo → write cache.

### Security
- Passwords: `bcrypt`. JWT: HS256 with secret from config (or RS256 with key files).
- All write endpoints behind auth middleware. RBAC enforced server-side — never trust frontend gating.
- Validate every input. Use parameterised queries (GORM does this by default — never `Raw` with string concat).
- CORS configured explicitly in `app.go`, not wildcard in prod.

### Concurrency
- Don't spawn goroutines without a way to cancel them — pass `ctx` and respect `<-ctx.Done()`.
- Use `errgroup.Group` for fan-out with error propagation.
- Protect shared state with `sync.Mutex` / `sync.RWMutex`; prefer channels for ownership transfer.

---

## Naming Conventions

| Item | Convention | Example |
|---|---|---|
| Packages | lowercase, single word | `usersvc`, `userrepo`, `middleware` |
| Files | `snake_case.go` | `user_svc.go`, `user_repo_impl.go` |
| Exported types | `PascalCase` | `UserService`, `GetUserResponse` |
| Unexported | `camelCase` | `userSvc`, `mapToDomain` |
| Interfaces | no `-er` suffix when name is clear | `UserSvc`, `UserRepo` |
| Constructors | `New<Type>` | `NewUserSvc`, `NewUserRepo` |
| Constants / cache keys | `PascalCase` or `ALL_CAPS` | `CacheTTLLong`, `PERM_USER_READ` |
| Service package | suffix `svc` | `package usersvc` |
| Repository package | suffix `repo` | `package userrepo` |
| Test files | `_test.go` next to source | `user_svc_test.go` |

---

## Testing

- **Unit tests** target service and util layers — mock the repo interface (use `testify/mock` or hand-rolled fakes).
- **Repository tests** run against a real Postgres in a Docker container (or `testcontainers-go`).
- **Handler tests** use `app.Test(req)` from Fiber to exercise the full HTTP stack with mocked services.
- Table-driven tests are the default style:
  ```go
  tests := []struct{ name string; in X; want Y; wantErr error }{...}
  for _, tt := range tests { t.Run(tt.name, func(t *testing.T) { ... }) }
  ```
- Coverage target: ≥ 80% on service + util; repo and handler tested by integration tests.
- `go test ./... -race` must pass in CI.

---

## Adding a New Feature — Checklist

1. Define the entity in `internal/domain/<name>.go` (+ any new domain errors in `errors.go`).
2. Add GORM model in `internal/data/orm/<name>.go` and run/auto-migrate.
3. Add DTOs (request + response) in `internal/data/dto/<name>.go` with `validate` tags.
4. Add repo interface `internal/repository/<name>/<name>_repo.go` + impl `<name>_repo_impl.go`.
5. Add service in `internal/service/<area>/` (or `internal/app/<binary>/service/`) wiring the repo interface.
6. Add handler in `internal/app/<binary>/handler/<name>_handler.go`.
7. Register routes in `internal/app/<binary>/route/<name>_routes.go`.
8. Wire constructors in `internal/app/<binary>/app.go` (repo → service → handler → route).
9. Add cache keys / permission keys to `internal/meta/` if needed.
10. Tests: unit for service, integration for repo, HTTP test for handler. Run `go test ./... -race`.
