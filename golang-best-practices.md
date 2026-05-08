# Go Best Practices Guide

Derived from real production code review. Each pattern includes a concrete example and the reasoning behind it.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Naming Conventions](#2-naming-conventions)
3. [Interfaces & Dependency Injection](#3-interfaces--dependency-injection)
4. [Error Handling](#4-error-handling)
5. [Configuration](#5-configuration)
6. [Logging](#6-logging)
7. [HTTP Handlers](#7-http-handlers)
8. [Repository Pattern](#8-repository-pattern)
9. [Service Layer](#9-service-layer)
10. [Caching](#10-caching)
11. [Database & Transactions](#11-database--transactions)
12. [Testing](#12-testing)
13. [Concurrency](#13-concurrency)
14. [Response Envelope](#14-response-envelope)
15. [Anti-Patterns to Avoid](#15-anti-patterns-to-avoid)

---

## 1. Project Structure

Use the standard Go layout for multi-binary services.

```
project-root/
  cmd/
    service-a/main.go     ← one main per binary
    service-b/main.go
  internal/
    config/               ← env → typed Config struct
    meta/                 ← shared constants (permissions, errors)
    data/                 ← DTOs, ORM models
    repository/           ← database access layer
    service/              ← business logic
    app/
      service-a/
        handler/          ← HTTP handlers
        middleware/        ← auth, rate-limit, logging
        route/            ← route wiring
    api-client/           ← outbound HTTP clients
    util/                 ← logger, db, redis, types
  go.mod
  Dockerfile
  .env.example
```

**Rules:**
- `internal/` prevents external packages from importing your code.
- `cmd/` entry points should be thin — only wire dependencies and call `Run()`.
- Use `lowercase` directory names. Avoid hyphens; they force import aliasing.

```go
// Bad — forces callers to alias
import supercache "weather-forecast-api/internal/util/super-cache"

// Good — importable directly
import "weather-forecast-api/internal/util/supercache"
```

---

## 2. Naming Conventions

### Constants — PascalCase, not SCREAMING_SNAKE

```go
// Bad — C-style, not idiomatic Go
const PERMISSION_USER = "user"
const ERROR_NOT_FOUND = "not found"

// Good
const PermissionUser = "user"

// Good for errors — use sentinel errors, not strings
var ErrNotFound = errors.New("not found")
var ErrUnauthorized = errors.New("unauthorized")
```

### Packages — short, lowercase, no underscores

```go
// Bad
package app_weather_api
package user_svc

// Good
package weatherapi
package usersvc   // or just: package service (if single service per dir)
```

### Receiver names — short abbreviation of the type

```go
// Bad
func (this *userService) GetList(...) {}
func (self *userRepo) Insert(...) {}

// Good
func (s *userService) GetList(...) {}
func (r *userRepo) Insert(...) {}
```

### Acronyms — consistent casing

```go
// Bad
type HttpHandler interface{}
type sqsQueue struct{}
type userID int64  // mixed

// Good
type HTTPHandler interface{}
type SQSQueue struct{}
type UserID int64
```

### File names — snake_case, match the primary type

```
user_repo.go         ← UserRepo
user_repo_mock.go    ← UserRepoMock (test helpers)
user_svc.go          ← UserSvc
auth_handler.go      ← authHandler
```

---

## 3. Interfaces & Dependency Injection

### Define interfaces at the consumer, not the producer

```go
// Good — service defines what it needs from the repo
type UserRepo interface {
    GetByID(ctx context.Context, id int64) (*orm.User, error)
    Insert(ctx context.Context, tx TX, req orm.User) (orm.UserInsertRes, error)
}
```

### Use constructor injection, not hidden singletons

```go
// Bad — dependencies are hard-wired inside, untestable
func NewUserSvc() UserSvc {
    return &userSvc{
        userRepo: user_repo.NewUserRepo(),   // singleton, can't be replaced in tests
        pg:       postgresql.NewPostgresqlDb(),
    }
}

// Good — dependencies are explicit, injectable
func NewUserSvc(
    userRepo UserRepo,
    pg       PostgresqlDB,
    cache    CacheDB,
) UserSvc {
    return &userSvc{
        userRepo: userRepo,
        pg:       pg,
        cache:    cache,
    }
}
```

### Wire at the entry point, not deep inside

```go
// cmd/weather-api/main.go
func main() {
    cfg := config.Load()

    pg  := postgresql.New(cfg.DB)
    rdb := redisdb.New(cfg.Redis)

    userRepo := user_repo.New(pg)
    roleRepo := role_repo.New(pg)
    userSvc  := user_svc.New(userRepo, roleRepo, rdb)

    h := handler.NewUserHandler(userSvc)
    // ...
}
```

---

## 4. Error Handling

### Wrap errors with context using `fmt.Errorf("%w")`

```go
// Bad — loses origin
return nil, errors.New("failed")

// Good — preserves the chain
if err := repo.Insert(ctx, user); err != nil {
    return nil, fmt.Errorf("userSvc.Create insert: %w", err)
}
```

### Use sentinel errors for known failure modes

```go
var (
    ErrNotFound     = errors.New("not found")
    ErrUnauthorized = errors.New("unauthorized")
    ErrConflict     = errors.New("conflict")
)

// Caller can inspect
if errors.Is(err, ErrNotFound) {
    return response.Notfound[T](err.Error())
}
```

### Never silently swallow errors

```go
// Bad — caller can never detect failure
func (c cacheDB) Set(key string, value any, ttl time.Duration) error {
    err = codec.Set(...)
    // goto HANDLE_ERR   ← logs and returns nil even on error
    return nil
}

// Good — return the error
func (c cacheDB) Set(ctx context.Context, key string, value any, ttl time.Duration) error {
    if err := codec.Set(&cache.Item{Key: key, Value: value, TTL: ttl}); err != nil {
        return fmt.Errorf("cache.Set %q: %w", key, err)
    }
    return nil
}
```

### Never use `goto` for control flow

```go
// Bad — unexpected jump, confusing flow
key, err := makeKey(req)
if err != nil {
    goto HANDLE_ERR
}
HANDLE_ERR:
logger.Warn(...)
return codec.Get(...)

// Good — plain if/else
key, err := makeKey(req)
if err != nil {
    logger.Warn("makeKey failed", "err", err)
    return zero, fmt.Errorf("makeKey: %w", err)
}
return codec.Get(ctx, key, &result)
```

### Don't ignore errors with `_` on important calls

```go
// Bad
userKey, _ := cachedb.MakeKey(req.ID)

// Good
userKey, err := cachedb.MakeKey(req.ID)
if err != nil {
    return response.InternalServerError[T](err, "make cache key")
}
```

---

## 5. Configuration

### Load once via a typed struct

```go
type Config struct {
    Server   ServerConfig
    DB       DBConfig
    Redis    RedisConfig
    Kafka    KafkaConfig
}

var once sync.Once
var cfg *Config

func Load() *Config {
    once.Do(func() {
        godotenv.Load()
        cfg = &Config{
            Server: ServerConfig{
                Port:    getEnvInt("PORT", 8080),
                Debug:   getEnvBool("DEBUG", false),
            },
            // ...
        }
    })
    return cfg
}
```

### Load `.env` from working directory only

```go
// Bad — searches up 9 directory levels
godotenv.Load("../../../../../../.env")
godotenv.Load("../../../../../../../.env")

// Good — load once from cwd; use absolute path flag for tests
godotenv.Load(".env")   // no-op if not present; real env vars override
```

### Provide `.env.example` with all keys and safe defaults

```
# Server
PORT=8080
DEBUG=false
LOG_LEVEL=info

# Database
POSTGRES_CONNECTION_STRING=postgres://user:pass@localhost:5432/dbname

# Redis
REDIS_HOST=localhost:6379
REDIS_PASSWORD=
```

---

## 6. Logging

### Use `log/slog` with structured key-value pairs

```go
// Bad — positional args, no structure
logger.Error("SQL select failed.", err)

// Good — structured, searchable
slog.Error("sql select failed", "table", "users", "err", err)
slog.Info("user created", "userID", userID, "empID", req.EmpID)
```

### Pass logger via context or constructor, not global

```go
// Acceptable — package-level singleton for simple services
var log *slog.Logger

func Init(cfg Config) {
    log = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
        Level: cfg.LogLevel,
    }))
    slog.SetDefault(log)
}

// Better for testability — inject logger
type userSvc struct {
    log  *slog.Logger
    repo UserRepo
}
```

### Log levels

| Level | Use for |
|-------|---------|
| `Debug` | Dev-only detail: SQL queries, cache hits/misses |
| `Info` | Normal events: service started, request processed |
| `Warn` | Recoverable issues: cache miss, retry attempt |
| `Error` | Failures requiring attention: DB error, external API down |

---

## 7. HTTP Handlers

### Keep handlers thin — parse, delegate, respond

```go
func (h *userHandler) Create(c *fiber.Ctx) error {
    userInfo, _ := c.Locals("userInfo").(data.AuthGetUserInfo)

    var req data.UserCreateReq
    if err := c.BodyParser(&req); err != nil {
        return response.BadRequest[any]().JSON(c)
    }
    req.CreatedBy = userInfo.FullName

    res := h.userSvc.Create(c.Context(), req)
    return res.JSON(c)
}
```

**Rules:**
- No business logic in handlers.
- No direct DB calls from handlers.
- Parse → enrich with auth context → call service → respond.

### Register routes with consistent prefix and slash style

```go
// Bad — inconsistent leading slash
router.Post("/user", h.GetList)
router.Get("user/:id", h.GetInfo)     // missing /

// Good — always use leading slash
router.Post("/user", h.GetList)
router.Get("/user/:id", h.GetInfo)
router.Post("/user/create", h.Create)
router.Delete("/user/:id", h.Delete)
router.Put("/user/:id", h.Update)
```

### Use `web.HTTPHandler` interface for handler grouping

```go
type HTTPHandler interface {
    Init(router fiber.Router)
}

func (h *userHandler) Init(router fiber.Router) {
    router.Get("/user/:id", middleware.Auth(), h.GetInfo)
    router.Post("/user", middleware.Auth(), h.GetList)
}
```

---

## 8. Repository Pattern

### Always accept `context.Context` as the first parameter

```go
// Bad — no way to cancel, trace, or set deadlines
func (r *userRepo) GetByID(id int64) (*orm.User, error)

// Good
func (r *userRepo) GetByID(ctx context.Context, id int64) (*orm.User, error)
```

### Return `nil, nil` for "not found", never `sql.ErrNoRows` to callers

```go
func (r *userRepo) GetByID(ctx context.Context, id int64) (*orm.User, error) {
    var res orm.User
    err := r.pg.GetContext(ctx, &res, query, id)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, nil   // not found is not an error at repo level
        }
        return nil, fmt.Errorf("userRepo.GetByID: %w", err)
    }
    return &res, nil
}
```

### Use parameterized queries — never string-format user input into SQL

```go
// Bad — SQL injection risk
query := fmt.Sprintf("SELECT * FROM users WHERE email = '%s'", email)

// Good — parameterized
query := `SELECT * FROM users WHERE email = $1`
r.pg.GetContext(ctx, &res, query, email)
```

### Split query building from execution for readability

```go
func (r *userRepo) GetList(ctx context.Context, req orm.UserGetListReq) ([]orm.UserGetListRes, error) {
    var args []any

    base := `
        SELECT u.id, u.emp_id, u.full_name, r.name AS role_name
        FROM users u
        LEFT JOIN roles r ON u.role_id = r.id
    `
    where, args := buildWhere(req)
    order := buildOrder(req.Sort)
    limit := buildLimit(req.PerPage, &args)

    query := r.pg.Rebind(base + where + order + limit)
    var res []orm.UserGetListRes
    if err := r.pg.SelectContext(ctx, &res, query, args...); err != nil {
        return nil, fmt.Errorf("userRepo.GetList: %w", err)
    }
    return res, nil
}
```

---

## 9. Service Layer

### Return a typed response, not `(T, error)` for HTTP services

```go
// Pattern — service returns Response[T], handler calls .JSON(c)
type UserSvc interface {
    GetList(ctx context.Context, req data.UserGetListReq) response.Response[[]data.UserGetListRes]
    GetInfo(ctx context.Context, req data.UserGetInfoReq) response.Response[*data.UserGetInfoRes]
    Create(ctx context.Context, req data.UserCreateReq)  response.Response[*data.UserCreateRes]
}

func (s *userSvc) GetInfo(ctx context.Context, req data.UserGetInfoReq) response.Response[*data.UserGetInfoRes] {
    if valMap := s.validate.Check(req); len(valMap) > 0 {
        return response.ValidationFailed[*data.UserGetInfoRes](valMap)
    }

    user, err := s.userRepo.GetByID(ctx, req.ID)
    if err != nil {
        return response.InternalServerError[*data.UserGetInfoRes](err, "get user by id")
    }
    if user == nil {
        return response.Notfound[*data.UserGetInfoRes]("user not found")
    }

    res := toUserGetInfoRes(*user)
    return response.Success(&res)
}
```

### Validate at the service boundary, not in the handler

```go
func (s *userSvc) Create(ctx context.Context, req data.UserCreateReq) response.Response[*data.UserCreateRes] {
    // 1. Sanitize / normalize
    req = normalizeCreateReq(req)

    // 2. Validate
    if valMap := s.validate.Check(req); len(valMap) > 0 {
        return response.ValidationFailed[*data.UserCreateRes](valMap)
    }

    // 3. Business logic
    // ...
}
```

### Keep mapping functions as private package-level helpers

```go
// in user_svc_mapper.go (or bottom of user_svc.go)
func toUserGetInfoRes(u orm.UserGetInfoRes) data.UserGetInfoRes {
    return data.UserGetInfoRes{
        ID:       u.ID,
        EmpID:    u.EmpID,
        FullName: u.FullName.String,
        RoleName: u.RoleName.String,
    }
}
```

---

## 10. Caching

### Always pass `context.Context` to cache operations

```go
// Bad — no context, can't cancel or trace
func (c cacheDB) GetInfo(key string, req any, res any) error

// Good
func (c cacheDB) Get(ctx context.Context, key string, dest any) error
func (c cacheDB) Set(ctx context.Context, key string, value any, ttl time.Duration) error
```

### Use a consistent key naming convention

```go
// Convention: {prefix}:{service}:{operation}:{id}
const CacheKeyPrefix = "weather"

func GenCacheKey(service, fn string) string {
    return fmt.Sprintf("%s:%s:%s", CacheKeyPrefix, service, fn)
}

// Usage
key := meta.GenCacheKey("user", "GetEmpLookup")
fullKey := fmt.Sprintf("%s:%s", key, empID)
```

### Use `GetOrSet` / `GetOrSetPtr` to eliminate cache stampede

```go
// Bad — check-then-set races under load
if err := cache.Get(ctx, key, &res); err != nil {
    res, err = fetchFromDB(ctx, id)
    cache.Set(ctx, key, res, ttl)
}

// Good — atomic singleflight via GetOrSet
res, err := cache.GetOrSet(ctx, key, func() (UserInfo, error) {
    return fetchFromDB(ctx, id)
})
```

### Fix SCAN cursor in Redis iteration

```go
// Bad — cursor is discarded, loop only scans first page
keys, _, err := client.Scan(ctx, cursor, pattern, 1000).Result()

// Good — advance cursor
var cursor uint64
for {
    var keys []string
    var err error
    keys, cursor, err = client.Scan(ctx, cursor, pattern, 1000).Result()
    if err != nil {
        return err
    }
    // process keys...
    if cursor == 0 {
        break
    }
}
```

---

## 11. Database & Transactions

### Wrap mutations in explicit transactions

```go
err := s.pg.ExecTx(ctx, func(tx postgresql.TX) error {
    res, err := s.userRepo.Insert(ctx, tx, toInsertReq(req))
    if err != nil {
        return err  // tx auto-rolled back
    }
    userID = res.ID
    return nil
})
```

### Distinguish "not found" from "error" in repo results

```go
user, err := s.userRepo.GetByID(ctx, req.ID)
if err != nil {
    return response.InternalServerError[T](err, "get user")
}
if user == nil {
    return response.Notfound[T]("user not found")
}
```

### Use `sqlx` named params for complex inserts

```go
query := `
    INSERT INTO users (emp_id, full_name, email, role_id, created_by)
    VALUES (:emp_id, :full_name, :email, :role_id, :created_by)
    RETURNING id
`
var id int64
rows, err := tx.NamedQuery(query, req)
```

---

## 12. Testing

### Use constructor injection so mocks can be passed in tests

```go
func TestUserSvc_GetInfo_NotFound(t *testing.T) {
    repo := &UserRepoMock{}
    repo.On("GetByID", mock.Anything, int64(99)).Return(nil, nil)

    svc := NewUserSvc(repo, nil, nil)
    res := svc.GetInfo(context.Background(), data.UserGetInfoReq{ID: 99})

    assert.False(t, res.Success)
    assert.Equal(t, 404, res.StatusCode)
    repo.AssertExpectations(t)
}
```

### Place mock files next to the interface they mock

```
internal/repository/user/
  user_repo.go         ← interface + implementation
  user_repo_mock.go    ← mock (used in tests only)
```

### Write table-driven tests for multiple cases

```go
func TestUserSvc_Create(t *testing.T) {
    tests := []struct {
        name       string
        req        data.UserCreateReq
        setupMocks func(*UserRepoMock)
        wantCode   int
    }{
        {
            name: "success",
            req:  data.UserCreateReq{EmpID: "12345", RoleID: 1},
            setupMocks: func(m *UserRepoMock) {
                m.On("Insert", mock.Anything, mock.Anything).Return(orm.UserInsertRes{ID: 1}, nil)
            },
            wantCode: 200,
        },
        {
            name:       "missing empID",
            req:        data.UserCreateReq{},
            setupMocks: func(m *UserRepoMock) {},
            wantCode:   400,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            m := &UserRepoMock{}
            tt.setupMocks(m)
            svc := NewUserSvc(m, nil, nil)
            res := svc.Create(context.Background(), tt.req)
            assert.Equal(t, tt.wantCode, res.StatusCode)
        })
    }
}
```

### Don't leave tests commented out — delete them or fix them

```go
// Bad — dead test noise
// func TestCreateUser_Success(t *testing.T) {
//     ...hundreds of lines...
// }

// Good — either un-comment and fix, or delete
```

---

## 13. Concurrency

### Pass `context.Context` to long-running goroutines

```go
func (h *hub) Run(ctx context.Context) {
    for {
        select {
        case <-ctx.Done():
            h.cleanup()
            return
        case msg := <-h.broadcast:
            h.handleMessage(msg)
        }
    }
}
```

### Use `golang.org/x/sync/errgroup` for parallel work with error propagation

```go
g, ctx := errgroup.WithContext(ctx)

g.Go(func() error {
    return s.syncStores(ctx)
})
g.Go(func() error {
    return s.syncProducts(ctx)
})

if err := g.Wait(); err != nil {
    return fmt.Errorf("sync failed: %w", err)
}
```

### Prefer channels over shared memory; use `sync.Mutex` only when necessary

```go
// Prefer
type Hub struct {
    register   chan *Client
    unregister chan *Client
    broadcast  chan []byte
}

// Only if channels don't fit the shape
type SafeMap struct {
    mu sync.RWMutex
    m  map[string]any
}
```

---

## 14. Response Envelope

Use a generic envelope for all API responses.

```go
type Response[T any] struct {
    Success          bool              `json:"success"`
    StatusCode       int               `json:"statusCode"`
    Message          string            `json:"message,omitempty"`
    ValidationErrors map[string]string `json:"validationErrors,omitempty"`
    Data             T                 `json:"data,omitempty"`
    Error            error             `json:"-"`
}

// Constructors for each status
func Success[T any](data T) Response[T]
func BadRequest[T any](msg string) Response[T]
func Notfound[T any](msg string) Response[T]
func ValidationFailed[T any](valMap map[string]string) Response[T]
func InternalServerError[T any](err error, msg string) Response[T]

// Send via Fiber
func (r Response[T]) JSON(c *fiber.Ctx) error {
    return c.Status(r.StatusCode).JSON(r)
}
```

**Handler usage:**
```go
func (h *userHandler) GetInfo(c *fiber.Ctx) error {
    var req data.UserGetInfoReq
    if err := c.ParamsParser(&req); err != nil {
        return response.BadRequest[any]().JSON(c)
    }
    return h.userSvc.GetInfo(c.Context(), req).JSON(c)
}
```

---

## 15. Anti-Patterns to Avoid

| Anti-pattern | Why bad | Fix |
|---|---|---|
| `goto` for control flow | Confusing, hides logic, error-prone | Use `if/return` |
| Silently swallowing errors (return `nil` on error) | Bugs become invisible | Always return or log the error |
| `sync.Once` singletons in constructors | Blocks dependency injection for tests | Use constructor injection |
| `ALL_CAPS_SNAKE_CASE` constants | Not idiomatic Go | Use `PascalCase` / `var Err = errors.New(...)` |
| Hyphen directory names | Forces import aliasing | Use `lowercase` or `lowercase_with_underscore` |
| Missing `context.Context` in repo/service | No cancellation, tracing, deadlines | First param always `ctx context.Context` |
| All tests commented out | No test coverage, dead noise | Fix tests or delete them |
| `.env` path traversal (9 levels up) | Fragile, platform-dependent | Load from cwd only |
| Ignoring error with `_` on important calls | Silent failures | Handle or explicitly log every error |
| Commented-out production code left in codebase | Confuses readers, blocks refactors | Use git history — delete dead code |
| SCAN cursor discarded in Redis iteration | Misses pages, potentially infinite loop | Always capture and advance cursor |
| Typos in public identifiers (`PosgresqlDB`, `DeletePRefix`) | API surface rot | Rename and update callsites |
| Repository methods without `ctx` | Cannot cancel slow queries | Add `ctx context.Context` as first param |

---

## Quick Reference Checklist

Before merging a PR, verify:

- [ ] Package names are `lowercase`, no underscores, no hyphens
- [ ] Exported constants use `PascalCase`; errors use `var Err = errors.New(...)`
- [ ] All functions that do I/O accept `ctx context.Context` as first param
- [ ] No `goto` statements
- [ ] No silently swallowed errors (no `return nil` after an error)
- [ ] No `_` ignoring errors on DB/cache/HTTP calls
- [ ] Mocks are accepted via constructor injection (not `sync.Once` globals)
- [ ] Redis SCAN loops capture and advance the cursor
- [ ] No large blocks of commented-out code
- [ ] Table-driven tests cover happy path and at least two error cases
- [ ] Config loads from cwd only; never traverses parent directories
