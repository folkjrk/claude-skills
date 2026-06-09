---
type: meta
status: active
created: 2026-04-19
updated: 2026-05-21
tags: [go, fiber, backend, reference]
---
# Backend Development Reference Guide (Go + Fiber)

**Version:** 3.0
**Last Updated:** May 2026
**Audience:** Full-stack developers building scalable Go backend services with Fiber

This guide covers **Go backend engineering best practices** using **Fiber v2** as the HTTP framework, focusing on dependency injection, interface-based design, testability, and production-ready patterns.

---

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [Core Go Principles](#2-core-go-principles)
3. [Project Structure & Architecture](#3-project-structure--architecture)
4. [Dependency Injection & Interfaces](#4-dependency-injection--interfaces)
5. [Repository Pattern](#5-repository-pattern)
6. [Service Layer Pattern](#6-service-layer-pattern)
7. [Handler Pattern (Fiber)](#7-handler-pattern-fiber)
8. [Response Wrapper Pattern](#8-response-wrapper-pattern)
9. [Middleware Patterns (Fiber)](#9-middleware-patterns-fiber)
10. [Routing Pattern](#10-routing-pattern)
11. [Error Handling](#11-error-handling)
12. [Configuration Management](#12-configuration-management)
13. [Testing Strategy](#13-testing-strategy)
14. [Database Patterns](#14-database-patterns)
15. [Logging & Observability](#15-logging--observability)
16. [Security Best Practices](#16-security-best-practices)
17. [Concurrency Patterns](#17-concurrency-patterns)
18. [Naming Conventions](#18-naming-conventions)
19. [Production Readiness](#19-production-readiness)

---

## 1. Getting Started

### 1.1 Initialize a New Project

```bash
# สร้าง project
mkdir my-api && cd my-api
go mod init my-api

# ติดตั้ง Fiber และ dependencies หลัก
go get github.com/gofiber/fiber/v2
go get github.com/joho/godotenv
go get github.com/go-playground/validator/v10
go get gorm.io/gorm
go get gorm.io/driver/postgres
go get github.com/redis/go-redis/v9
go get github.com/golang-jwt/jwt/v5
go get log/slog  # built-in Go 1.21+
```

### 1.2 Entry Point Bootstrap Pattern

```go
// cmd/api/main.go
package main

import (
    "my-api/internal/app"
)

func main() {
    app.Run()
}
```

```go
// internal/app/app.go
package app

import (
    "context"
    "os/signal"
    "syscall"

    "my-api/internal/config"
    "my-api/internal/route"
    "my-api/internal/util/logger"
    "my-api/internal/util/postgresql"
    "my-api/internal/util/redisdb"
)

func Run() {
    ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
    defer func() {
        stop()
        postgresql.Close()
        redisdb.Close()
    }()

    Init(ctx)

    r := route.New()
    r.Init()

    logger.Info("server starting on :8080")
    go r.Listen(":8080")

    <-ctx.Done()
    logger.Info("shutting down...")
}

func Init(ctx context.Context) {
    cfg := config.Get()
    logger.Init(cfg.Log)
    postgresql.Init(cfg.Database.URL)
    redisdb.Init(cfg.Redis.Hosts)
}
```

### 1.3 Makefile

```makefile
.PHONY: run build test lint

run:
	go run cmd/api/main.go

build:
	go build -o bin/api cmd/api/main.go

test:
	go test -v -race -count=1 ./...

test-integration:
	go test -v -tags=integration ./...

lint:
	golangci-lint run

tidy:
	go mod tidy

generate:
	go generate ./...
```

---

## 2. Core Go Principles

### 2.1 Idiomatic Go

```go
// ✅ Good
func (s *UserService) GetUser(ctx context.Context, id string) (*User, error) {
    if id == "" {
        return nil, ErrInvalidUserID
    }
    user, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("get user: %w", err)
    }
    return user, nil
}

// ❌ Bad
func (s *UserService) get_user(Id string) *User {
    return s.repo.FindByID(Id) // no context, no error
}
```

### 2.2 Go Proverbs

| Proverb | Meaning |
|---------|---------|
| **"Clear is better than clever"** | ความชัดเจนสำคัญกว่าความฉลาด |
| **"Accept interfaces, return concrete types"** | Functions รับ interface, return struct |
| **"The bigger the interface, the weaker the abstraction"** | Interface เล็กๆ ดีกว่า |
| **"Don't panic"** | ใช้ errors ไม่ใช่ panic (ยกเว้น unrecoverable) |
| **"Errors are values"** | handle errors explicitly |

---

## 3. Project Structure & Architecture

### 3.1 Recommended Folder Structure

```
project-root/
├── cmd/                        # Application entry points
│   ├── api/
│   │   └── main.go
│   ├── worker/
│   │   └── main.go
│   └── job/
│       └── main.go
│
├── internal/                   # Private application code
│   ├── app/                    # App bootstrap per binary
│   │   ├── api/
│   │   │   └── app.go
│   │   └── worker/
│   │       └── app.go
│   │
│   ├── config/                 # Configuration
│   │   └── config.go
│   │
│   ├── data/                   # Shared data structs
│   │   ├── orm/                # DB models (GORM structs)
│   │   ├── dto/                # External data transfer
│   │   └── event/              # Event/message payloads
│   │
│   ├── domain/                 # Business entities & errors
│   │   ├── user.go
│   │   └── errors.go
│   │
│   ├── repository/             # Data access layer (interfaces + impl)
│   │   ├── user/
│   │   │   ├── user_repo.go        # interface
│   │   │   ├── user_repo_impl.go   # implementation
│   │   │   └── user_repo_test.go
│   │   └── product/
│   │
│   ├── service/                # Business logic (app-shared)
│   │   └── forecast/
│   │
│   ├── app/                    # Per-app handlers & services
│   │   └── weather-api/
│   │       ├── handler/
│   │       ├── service/
│   │       ├── middleware/
│   │       └── route/
│   │
│   ├── util/                   # Shared utilities
│   │   ├── response/           # HTTP response wrapper
│   │   ├── logger/
│   │   ├── postgresql/
│   │   ├── redisdb/
│   │   ├── cachedb/
│   │   ├── validation/
│   │   └── web/                # HTTPHandler interface
│   │
│   └── meta/                   # Constants, permission keys, cache keys
│
├── docs/                       # OpenAPI / swagger docs
├── go.mod
├── go.sum
├── Makefile
├── Dockerfile
└── .env.example
```

### 3.2 Clean Architecture Layers

```
Handler (Fiber)  →  Service  →  Repository  →  DB/Redis/External API
```

- **Handler**: รับ request, parse, เรียก service, return response
- **Service**: business logic, orchestration, caching
- **Repository**: data access, query DB, no business logic
- **Dependencies ชี้เข้าใน** — handler รู้จัก service interface, service รู้จัก repo interface

---

## 4. Dependency Injection & Interfaces

### 4.1 Constructor Injection (สำคัญมาก)

**Inject dependencies ผ่าน constructor เสมอ — ห้าม `New...()` ข้างใน**

```go
// ✅ Good — inject ผ่าน constructor
type UserService struct {
    repo   UserRepository
    cache  CacheDB
    logger Logger
}

func NewUserService(repo UserRepository, cache CacheDB, logger Logger) *UserService {
    return &UserService{repo: repo, cache: cache, logger: logger}
}

// ❌ Bad — hard-coded dependency (test ยาก, swap ไม่ได้)
func NewUserService() *UserService {
    return &UserService{
        repo:  postgres.NewUserRepo(),   // ❌ สร้างเอง
        cache: redis.NewCache(),         // ❌ สร้างเอง
    }
}
```

### 4.2 Small, Focused Interfaces

```go
// ✅ Good: แต่ละ interface ทำหน้าที่เดียว
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, user *User) error
    Update(ctx context.Context, user *User) error
    Delete(ctx context.Context, id string) error
    List(ctx context.Context, filter UserFilter) ([]*User, error)
}

type CacheDB interface {
    GetInfo(key string, subKey string, dest any) error
    Set(key string, subKey string, value any, ttl time.Duration)
    Delete(key string, subKey string)
}

// ❌ Bad: God interface
type UserManager interface {
    FindByID(ctx context.Context, id string) (*User, error)
    SendEmail(to, subject, body string) error
    ClearCache(key string)
    CalculateMetrics() Stats
}
```

### 4.3 Manual Wiring ใน app.go

```go
// internal/app/api/app.go
func Init(ctx context.Context) {
    cfg := config.Get()

    // infrastructure
    db := postgresql.Get()
    cache := cachedb.New()
    logger := logger.Get()

    // repositories
    userRepo := userrepo.New(db)
    productRepo := productrepo.New(db)

    // services
    userSvc := usersvc.New(userRepo, cache, logger)
    productSvc := productsvc.New(productRepo, cache, logger)

    // handlers (wire ใน route)
    route.Init(userSvc, productSvc)
}
```

---

## 5. Repository Pattern

### 5.1 Repository Interface

```go
// internal/repository/user/user_repo.go
package userrepo

import (
    "context"
    "my-api/internal/data/orm"
)

type UserRepo interface {
    GetInfo(req orm.UserGetInfoReq) (*orm.User, error)
    GetList(req orm.UserGetListReq) ([]orm.User, error)
    Create(req orm.UserCreateReq) error
    Update(tx TX, req orm.UserUpdateReq) (int64, error)
    Delete(ctx context.Context, id string) error
}
```

### 5.2 Repository Implementation

```go
// internal/repository/user/user_repo_impl.go
package userrepo

import (
    "database/sql"
    "fmt"
    "my-api/internal/data/orm"
    "my-api/internal/util/postgresql"
)

type userRepo struct {
    db postgresql.DB
}

func New(db postgresql.DB) UserRepo {
    return &userRepo{db: db}
}

func (r *userRepo) GetInfo(req orm.UserGetInfoReq) (*orm.User, error) {
    var user orm.User
    result := r.db.Where("id = ? AND deleted_at IS NULL", req.ID).First(&user)
    if result.Error == sql.ErrNoRows {
        return nil, nil
    }
    if result.Error != nil {
        return nil, fmt.Errorf("get user: %w", result.Error)
    }
    return &user, nil
}

func (r *userRepo) Create(req orm.UserCreateReq) error {
    user := orm.User{
        ID:    req.ID,
        Email: req.Email,
        Name:  req.Name,
    }
    if err := r.db.Create(&user).Error; err != nil {
        return fmt.Errorf("create user: %w", err)
    }
    return nil
}

func (r *userRepo) Update(tx TX, req orm.UserUpdateReq) (int64, error) {
    result := tx.Model(&orm.User{}).
        Where("id = ? AND deleted_at IS NULL", req.ID).
        Updates(map[string]any{
            "name":       req.Name,
            "updated_at": req.UpdatedAt,
        })
    if result.Error != nil {
        return 0, fmt.Errorf("update user: %w", result.Error)
    }
    return result.RowsAffected, nil
}

func (r *userRepo) Delete(ctx context.Context, id string) error {
    result := r.db.WithContext(ctx).
        Model(&orm.User{}).
        Where("id = ?", id).
        Update("deleted_at", time.Now())
    if result.Error != nil {
        return fmt.Errorf("delete user: %w", result.Error)
    }
    return nil
}
```

### 5.3 ORM Model (data/orm)

```go
// internal/data/orm/user.go
package orm

import "time"

type User struct {
    ID        string     `gorm:"column:id;primaryKey"`
    Email     string     `gorm:"column:email;uniqueIndex"`
    Name      string     `gorm:"column:name"`
    Status    string     `gorm:"column:status"`
    CreatedAt time.Time  `gorm:"column:created_at;autoCreateTime"`
    UpdatedAt time.Time  `gorm:"column:updated_at;autoUpdateTime"`
    DeletedAt *time.Time `gorm:"column:deleted_at"`
}

func (User) TableName() string { return "users" }

type UserGetInfoReq struct {
    ID string
}

type UserGetListReq struct {
    Status string
    Limit  int
    Offset int
}

type UserCreateReq struct {
    ID    string
    Email string
    Name  string
}

type UserUpdateReq struct {
    ID        string
    Name      string
    UpdatedAt time.Time
}
```

---

## 6. Service Layer Pattern

### 6.1 Service Interface

```go
// internal/app/weather-api/service/user/user_svc.go
package usersvc

import (
    "context"
    "my-api/internal/util/response"
)

type UserSvc interface {
    GetInfo(ctx context.Context, req UserGetInfoReq) response.Response[*UserGetInfoRes]
    GetList(ctx context.Context, req UserGetListReq) response.Response[[]UserGetListRes]
    Create(ctx context.Context, req UserCreateReq) response.Response[*UserCreateRes]
    Update(ctx context.Context, req UserUpdateReq) response.Response[*UserUpdateRes]
    Delete(ctx context.Context, req UserDeleteReq) response.Response[any]
}

// Request/Response structs อยู่ใน service package
type UserGetInfoReq struct {
    ID string `params:"id" validate:"required"`
}

type UserGetInfoRes struct {
    ID    string `json:"id"`
    Email string `json:"email"`
    Name  string `json:"name"`
}
```

### 6.2 Service Implementation

```go
// internal/app/weather-api/service/user/user_svc_impl.go
package usersvc

import (
    "context"
    "fmt"
    "time"

    "my-api/internal/data/orm"
    "my-api/internal/meta"
    userrepo "my-api/internal/repository/user"
    "my-api/internal/util/cachedb"
    "my-api/internal/util/response"
    "my-api/internal/util/validation"
)

type userSvc struct {
    validate validation.Validate
    userRepo userrepo.UserRepo
    cache    cachedb.CacheDB
}

func New(repo userrepo.UserRepo, cache cachedb.CacheDB) UserSvc {
    return &userSvc{
        validate: validation.New(),
        userRepo: repo,
        cache:    cache,
    }
}

func (svc *userSvc) GetInfo(ctx context.Context, req UserGetInfoReq) response.Response[*UserGetInfoRes] {
    if valMap := svc.validate.Check(req); len(valMap) > 0 {
        return response.ValidationFailed[*UserGetInfoRes](valMap)
    }

    cacheKey := meta.GenCacheKey("user", "GetInfo")
    var res UserGetInfoRes
    if svc.cache.GetInfo(cacheKey, req.ID, &res) != nil {
        userDB, err := svc.userRepo.GetInfo(orm.UserGetInfoReq{ID: req.ID})
        if err != nil {
            return response.InternalServerError[*UserGetInfoRes](err, "error user repo get info")
        }
        if userDB == nil {
            return response.Notfound[*UserGetInfoRes]("user not found")
        }
        res = toUserGetInfoRes(*userDB)
        svc.cache.Set(cacheKey, req.ID, res, 10*time.Minute)
    }

    return response.Success(&res)
}

func (svc *userSvc) Update(ctx context.Context, req UserUpdateReq) response.Response[*UserUpdateRes] {
    if valMap := svc.validate.Check(req); len(valMap) > 0 {
        return response.ValidationFailed[*UserUpdateRes](valMap)
    }

    count, err := svc.userRepo.Update(nil, orm.UserUpdateReq{
        ID:        req.ID,
        Name:      req.Name,
        UpdatedAt: time.Now().UTC(),
    })
    if err != nil {
        return response.InternalServerError[*UserUpdateRes](err, "error user repo update")
    }
    if count == 0 {
        return response.Notfound[*UserUpdateRes]("user not found")
    }

    // clear cache
    svc.cache.Delete(meta.GenCacheKey("user", "GetInfo"), req.ID)

    return response.Success(&UserUpdateRes{ModifiedID: req.ID})
}
```

---

## 7. Handler Pattern (Fiber)

### 7.1 HTTPHandler Interface

```go
// internal/util/web/web.go
package web

import "github.com/gofiber/fiber/v2"

// HTTPHandler — ทุก handler ต้อง implement interface นี้
type HTTPHandler interface {
    Init(router fiber.Router)
}

type HandlerRegistrator struct {
    Handlers []HTTPHandler
}

func (m *HandlerRegistrator) Register(h ...HTTPHandler) {
    m.Handlers = append(m.Handlers, h...)
}

func (m *HandlerRegistrator) Init(root fiber.Router) {
    for _, h := range m.Handlers {
        h.Init(root)
    }
}
```

### 7.2 Handler Implementation

```go
// internal/app/weather-api/handler/user_handler.go
package handler

import (
    usersvc "my-api/internal/app/weather-api/service/user"
    "my-api/internal/app/weather-api/middleware"
    "my-api/internal/data"
    "my-api/internal/meta"
    "my-api/internal/util/response"
    "my-api/internal/util/web"

    "github.com/gofiber/fiber/v2"
)

type userHandler struct {
    userSvc usersvc.UserSvc
}

// ✅ รับ dependency ผ่าน constructor
func NewUserHandler(userSvc usersvc.UserSvc) web.HTTPHandler {
    return &userHandler{userSvc: userSvc}
}

func (h *userHandler) Init(router fiber.Router) {
    router.Get("/users/:id", middleware.Permission(meta.PERM_USER_READ), h.GetInfo)
    router.Put("/users/:id", middleware.Permission(meta.PERM_USER_WRITE), h.Update)
    router.Post("/users", middleware.Permission(meta.PERM_USER_WRITE), h.Create)
    router.Delete("/users/:id", middleware.Permission(meta.PERM_USER_WRITE), h.Delete)
}

// GetUserInfo godoc
// @summary get user info
// @tags users
// @security ApiKeyAuth
// @id GetUserInfo
// @param id path string true "user ID"
// @success 200 {object} usersvc.UserGetInfoRes
// @Router /api/users/{id} [get]
func (h *userHandler) GetInfo(c *fiber.Ctx) error {
    var req usersvc.UserGetInfoReq
    if err := c.ParamsParser(&req); err != nil {
        return response.BadRequest[any]().JSON(c)
    }
    res := h.userSvc.GetInfo(c.Context(), req)
    return res.JSON(c)
}

func (h *userHandler) Update(c *fiber.Ctx) error {
    // get user from session (set by Authorization middleware)
    userInfo, _ := c.Locals("userInfo").(data.AuthUserInfo)

    var req usersvc.UserUpdateReq
    if err := c.BodyParser(&req); err != nil {
        return response.BadRequest[any]().JSON(c)
    }
    if err := c.ParamsParser(&req); err != nil {
        return response.BadRequest[any]().JSON(c)
    }
    req.ModifiedByID = userInfo.ID

    res := h.userSvc.Update(c.Context(), req)
    return res.JSON(c)
}

func (h *userHandler) Create(c *fiber.Ctx) error {
    var req usersvc.UserCreateReq
    if err := c.BodyParser(&req); err != nil {
        return response.BadRequest[any]().JSON(c)
    }
    res := h.userSvc.Create(c.Context(), req)
    return res.JSON(c)
}

func (h *userHandler) Delete(c *fiber.Ctx) error {
    var req usersvc.UserDeleteReq
    if err := c.ParamsParser(&req); err != nil {
        return response.BadRequest[any]().JSON(c)
    }
    res := h.userSvc.Delete(c.Context(), req)
    return res.JSON(c)
}
```

### 7.3 Fiber Request Parsing

```go
// Path params: /users/:id
c.ParamsParser(&req)   // map path params → struct fields

// Body (JSON)
c.BodyParser(&req)     // parse JSON body → struct

// Query string: /users?status=active&limit=20
c.QueryParser(&req)    // map query params → struct

// ใช้ทั้ง body + path ในคำสั่งเดียว
c.BodyParser(&req)
c.ParamsParser(&req)   // override ด้วย path params

// Get locals (set by middleware)
userInfo, _ := c.Locals("userInfo").(data.AuthUserInfo)
```

---

## 8. Response Wrapper Pattern

ใช้ generic `Response[T]` เพื่อให้ทุก response มี format เดียวกัน

### 8.1 Response Struct

```go
// internal/util/response/response.go
package response

import (
    "net/http"
    "github.com/gofiber/fiber/v2"
)

type Response[T any] struct {
    Success          bool              `json:"success"`
    StatusCode       int               `json:"statusCode"`
    Message          string            `json:"message,omitempty"`
    ValidationErrors map[string]string `json:"validationErrors,omitempty"`
    Data             T                 `json:"data,omitempty"`
    Error            error             `json:"-"`
}

// JSON — ส่ง response กลับ Fiber
func (r Response[T]) JSON(c *fiber.Ctx) error {
    c.Locals("err", r.Error)
    c.Locals("message", r.Message)
    return c.Status(r.StatusCode).JSON(r)
}

func Success[T any](data T) Response[T] {
    return Response[T]{Success: true, StatusCode: 200, Data: data}
}

func BadRequest[T any](msgs ...string) Response[T] {
    msg := http.StatusText(http.StatusBadRequest)
    if len(msgs) > 0 {
        msg = msgs[0]
    }
    return Response[T]{Success: false, StatusCode: 400, Message: msg}
}

func ValidationFailed[T any](valMap map[string]string) Response[T] {
    return Response[T]{
        Success:          false,
        StatusCode:       400,
        Message:          "Validate Bad Request",
        ValidationErrors: valMap,
    }
}

func Unauthorized[T any](msgs ...string) Response[T] {
    msg := http.StatusText(http.StatusUnauthorized)
    if len(msgs) > 0 {
        msg = msgs[0]
    }
    return Response[T]{Success: false, StatusCode: 401, Message: msg}
}

func Notfound[T any](message string) Response[T] {
    return Response[T]{Success: false, StatusCode: 404, Message: message}
}

func InternalServerError[T any](err error, message string) Response[T] {
    return Response[T]{
        Success:    false,
        StatusCode: 500,
        Message:    message,
        Error:      err,
    }
}
```

### 8.2 Usage Pattern

```go
// ใน service — return Response[T] ทุกที่
func (svc *userSvc) GetInfo(ctx context.Context, req UserGetInfoReq) response.Response[*UserGetInfoRes] {
    if valMap := svc.validate.Check(req); len(valMap) > 0 {
        return response.ValidationFailed[*UserGetInfoRes](valMap)
    }
    user, err := svc.repo.GetInfo(orm.UserGetInfoReq{ID: req.ID})
    if err != nil {
        return response.InternalServerError[*UserGetInfoRes](err, "repo error")
    }
    if user == nil {
        return response.Notfound[*UserGetInfoRes]("user not found")
    }
    return response.Success(&UserGetInfoRes{ID: user.ID, Name: user.Name})
}

// ใน handler — เรียก .JSON(c) เพื่อส่ง response
func (h *userHandler) GetInfo(c *fiber.Ctx) error {
    var req usersvc.UserGetInfoReq
    if err := c.ParamsParser(&req); err != nil {
        return response.BadRequest[any]().JSON(c)
    }
    return h.userSvc.GetInfo(c.Context(), req).JSON(c)
}
```

### 8.3 JSON Response Format

```json
// Success
{ "success": true, "statusCode": 200, "data": { ... } }

// Validation Error
{ "success": false, "statusCode": 400, "message": "Validate Bad Request",
  "validationErrors": { "email": "required", "name": "min=2" } }

// Not Found
{ "success": false, "statusCode": 404, "message": "user not found" }

// Internal Error
{ "success": false, "statusCode": 500, "message": "repo error" }
```

---

## 9. Middleware Patterns (Fiber)

### 9.1 Authorization Middleware

```go
// internal/app/weather-api/middleware/middleware.go
package middleware

import (
    "my-api/internal/data"
    "my-api/internal/util/response"
    "my-api/internal/util/session"

    "github.com/gofiber/fiber/v2"
)

type Middleware interface {
    Authorization(c *fiber.Ctx) error
}

type mw struct {
    session session.SessionStorage
}

func New() Middleware {
    return &mw{session: session.New()}
}

func (m *mw) Authorization(c *fiber.Ctx) error {
    var userInfo data.AuthUserInfo
    if err := m.session.Get(c, &userInfo); err != nil {
        return response.Unauthorized[any]().JSON(c)
    }
    c.Locals("userInfo", userInfo)
    return c.Next()
}
```

### 9.2 Permission Middleware

```go
// internal/app/weather-api/middleware/permission.go
func Permission(permissions ...string) fiber.Handler {
    return func(c *fiber.Ctx) error {
        userInfo, ok := c.Locals("userInfo").(data.AuthUserInfo)
        if !ok {
            return response.Unauthorized[any]().JSON(c)
        }
        for _, p := range permissions {
            if perm, ok := userInfo.Permissions[p]; !ok || !perm.Status {
                return response.Unauthorized[any]().JSON(c)
            }
        }
        return c.Next()
    }
}
```

### 9.3 Logging Middleware

```go
// internal/app/weather-api/middleware/log.go
func Logger() fiber.Handler {
    return func(c *fiber.Ctx) error {
        if c.Path() == "/health" {
            return c.Next()
        }
        start := time.Now().UTC()
        next := c.Next()
        latency := time.Since(start)

        userInfo, _ := c.Locals("userInfo").(data.AuthUserInfo)
        errVal, _ := c.Locals("err").(error)

        log := map[string]any{
            "time":    start.Format(time.RFC3339),
            "method":  c.Method(),
            "path":    c.Path(),
            "status":  c.Response().StatusCode(),
            "latency": latency.Milliseconds(),
            "userID":  userInfo.ID,
        }
        if errVal != nil {
            log["error"] = errVal.Error()
        }
        jsonStr, _ := json.Marshal(log)
        fmt.Println(string(jsonStr))
        return next
    }
}
```

### 9.4 Recovery Middleware

```go
func Recovery() fiber.Handler {
    return func(c *fiber.Ctx) error {
        defer func() {
            if r := recover(); r != nil {
                slog.Error("panic recovered", "error", r, "stack", string(debug.Stack()))
                _ = response.InternalServerError[any](fmt.Errorf("%v", r), "internal server error").JSON(c)
            }
        }()
        return c.Next()
    }
}
```

---

## 10. Routing Pattern

```go
// internal/app/weather-api/route/route.go
package route

import (
    "my-api/internal/app/weather-api/handler"
    "my-api/internal/app/weather-api/middleware"
    "my-api/internal/config"
    "my-api/internal/util/web"

    "github.com/gofiber/fiber/v2"
    "github.com/gofiber/fiber/v2/middleware/cors"
)

type Route interface {
    Init() *fiber.App
    Listen(addr string) error
}

type route struct {
    app     *fiber.App
    mw      middleware.Middleware
    userSvc usersvc.UserSvc   // inject services
}

func New(userSvc usersvc.UserSvc) Route {
    return &route{
        app: fiber.New(fiber.Config{
            BodyLimit:                10 * 1024 * 1024,
            EnableSplittingOnParsers: true,
        }),
        mw:      middleware.New(),
        userSvc: userSvc,
    }
}

func (r *route) Init() *fiber.App {
    cfg := config.Get()

    r.app.Use(cors.New(cors.Config{
        AllowOrigins:     strings.Join(cfg.Web.CORSAllowOrigin, ","),
        AllowCredentials: true,
        AllowMethods:     "GET,POST,PUT,DELETE,PATCH,OPTIONS",
    }))

    if cfg.IsDebug {
        r.app.Use(middleware.Logger())
    }

    r.app.Use(middleware.Recovery())

    api := r.app.Group("/api")

    // public routes
    public := web.HandlerRegistrator{}
    public.Register(handler.NewAuthHandler(...))
    public.Init(api)

    // private routes (require Authorization)
    private := api.Use(r.mw.Authorization)
    privateHandlers := web.HandlerRegistrator{}
    privateHandlers.Register(
        handler.NewUserHandler(r.userSvc),
        handler.NewProductHandler(...),
    )
    privateHandlers.Init(private)

    return r.app
}

func (r *route) Listen(addr string) error {
    return r.app.Listen(addr)
}
```

---

## 11. Error Handling

### 11.1 Sentinel Errors

```go
// internal/domain/errors.go
package domain

import "errors"

var (
    ErrNotFound      = errors.New("not found")
    ErrAlreadyExists = errors.New("already exists")
    ErrUnauthorized  = errors.New("unauthorized")
    ErrInvalidInput  = errors.New("invalid input")
)
```

### 11.2 Error Wrapping

```go
// ✅ ใส่ context ให้ error เสมอ
if err != nil {
    return fmt.Errorf("get user %s: %w", id, err)
}

// ✅ ตรวจ error ด้วย errors.Is
if errors.Is(err, domain.ErrNotFound) {
    return response.Notfound[*UserRes]("user not found")
}

// ❌ อย่า lose context
return nil, errors.New("failed") // ไม่รู้ว่า fail ที่ไหน
```

### 11.3 Transaction Error Handling Pattern

```go
// ใช้ flag แยกประเภท error ใน transaction
var (
    isNotFound bool
    valMap     map[string]string
)

err := pg.ExecTx(ctx, func(tx TX) error {
    count, err := repo.Update(tx, req)
    if err != nil {
        return err
    }
    if count == 0 {
        isNotFound = true
        return errors.New("not found")
    }
    return nil
})

if err != nil {
    if isNotFound {
        return response.Notfound[*Res]("record not found")
    }
    if len(valMap) > 0 {
        return response.ValidationFailed[*Res](valMap)
    }
    return response.InternalServerError[*Res](err, "transaction failed")
}
```

---

## 12. Configuration Management

### 12.1 Config Struct

```go
// internal/config/config.go
package config

import (
    "log/slog"
    "os"
    "time"

    "github.com/joho/godotenv"
)

var cfg *Config

type Config struct {
    IsDebug  bool
    Log      LogConfig
    Web      WebConfig
    Database DatabaseConfig
    Redis    RedisConfig
    JWT      JWTConfig
    Cache    CacheConfig
}

type DatabaseConfig struct {
    URL             string
    MaxOpenConn     int
    MaxIdleConn     int
    ConnMaxLifetime time.Duration
}

type RedisConfig struct {
    Hosts    []string
    Password string
    UseCluster bool
}

type JWTConfig struct {
    Secret     string
    Expiration time.Duration
}

type CacheConfig struct {
    TTLShort  time.Duration
    TTLMedium time.Duration
    TTLLong   time.Duration
}

type LogConfig struct {
    Level  slog.Level
    Format string
}

type WebConfig struct {
    Port            string
    CORSAllowOrigin []string
    BasePath        string
}

func Get() *Config {
    if cfg != nil {
        return cfg
    }
    godotenv.Load()
    cfg = &Config{
        IsDebug: getEnvBool("DEBUG", false),
        Log: LogConfig{
            Level:  getEnvLogLevel("LOG_LEVEL", slog.LevelInfo),
            Format: getEnvString("LOG_FORMAT", "json"),
        },
        Web: WebConfig{
            Port:            getEnvString("PORT", "8080"),
            CORSAllowOrigin: getEnvStringSlice("CORS_ORIGINS", []string{"*"}),
        },
        Database: DatabaseConfig{
            URL:             getEnvString("DATABASE_URL", ""),
            MaxOpenConn:     getEnvInt("DB_MAX_OPEN_CONN", 25),
            MaxIdleConn:     getEnvInt("DB_MAX_IDLE_CONN", 5),
            ConnMaxLifetime: getEnvDuration("DB_CONN_MAX_LIFETIME", 5*time.Minute),
        },
        Redis: RedisConfig{
            Hosts:      getEnvStringSlice("REDIS_HOSTS", []string{}),
            Password:   getEnvString("REDIS_PASSWORD", ""),
            UseCluster: getEnvBool("REDIS_USE_CLUSTER", false),
        },
        JWT: JWTConfig{
            Secret:     getEnvString("JWT_SECRET", ""),
            Expiration: getEnvDuration("JWT_EXPIRATION", 24*time.Hour),
        },
        Cache: CacheConfig{
            TTLShort:  getEnvDuration("CACHE_TTL_SHORT", 5*time.Minute),
            TTLMedium: getEnvDuration("CACHE_TTL_MEDIUM", 1*time.Hour),
            TTLLong:   getEnvDuration("CACHE_TTL_LONG", 24*time.Hour),
        },
    }
    return cfg
}
```

### 12.2 .env.example

```bash
DEBUG=false
PORT=8080
LOG_LEVEL=info
LOG_FORMAT=json

DATABASE_URL=postgres://user:password@localhost:5432/mydb?sslmode=disable
DB_MAX_OPEN_CONN=25
DB_MAX_IDLE_CONN=5

REDIS_HOSTS=localhost:6379
REDIS_PASSWORD=
REDIS_USE_CLUSTER=false

JWT_SECRET=your-secret-here
JWT_EXPIRATION=86400

CACHE_TTL_SHORT=300
CACHE_TTL_MEDIUM=3600
CACHE_TTL_LONG=86400

CORS_ORIGINS=http://localhost:3000
```

---

## 13. Testing Strategy

### 13.1 Testing Pyramid

| Test Type | Coverage | Focus |
|-----------|----------|-------|
| **Unit** | 70% | Service logic ด้วย mock repo |
| **Integration** | 20% | Repo + DB จริง |
| **E2E / Handler** | 10% | HTTP round-trip |

### 13.2 Unit Test — Service Layer

```go
// internal/app/weather-api/service/user/user_svc_test.go
package usersvc_test

import (
    "context"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"

    "my-api/internal/data/orm"
    usersvc "my-api/internal/app/weather-api/service/user"
)

// --- mock repo ---
type mockUserRepo struct {
    getInfoFn func(req orm.UserGetInfoReq) (*orm.User, error)
}

func (m *mockUserRepo) GetInfo(req orm.UserGetInfoReq) (*orm.User, error) {
    return m.getInfoFn(req)
}
func (m *mockUserRepo) GetList(req orm.UserGetListReq) ([]orm.User, error) { return nil, nil }
func (m *mockUserRepo) Create(req orm.UserCreateReq) error                 { return nil }
func (m *mockUserRepo) Update(tx any, req orm.UserUpdateReq) (int64, error) { return 0, nil }
func (m *mockUserRepo) Delete(ctx context.Context, id string) error        { return nil }

// --- mock cache ---
type mockCache struct{}
func (m *mockCache) GetInfo(key, sub string, dest any) error      { return fmt.Errorf("miss") }
func (m *mockCache) Set(key, sub string, val any, ttl time.Duration) {}
func (m *mockCache) Delete(key, sub string)                        {}

func TestUserSvc_GetInfo(t *testing.T) {
    tests := []struct {
        name    string
        req     usersvc.UserGetInfoReq
        repoFn  func(orm.UserGetInfoReq) (*orm.User, error)
        wantOK  bool
        wantCode int
    }{
        {
            name: "success",
            req:  usersvc.UserGetInfoReq{ID: "user-1"},
            repoFn: func(r orm.UserGetInfoReq) (*orm.User, error) {
                return &orm.User{ID: "user-1", Name: "Test"}, nil
            },
            wantOK: true, wantCode: 200,
        },
        {
            name: "not found",
            req:  usersvc.UserGetInfoReq{ID: "x"},
            repoFn: func(r orm.UserGetInfoReq) (*orm.User, error) {
                return nil, nil
            },
            wantOK: false, wantCode: 404,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            svc := usersvc.New(
                &mockUserRepo{getInfoFn: tt.repoFn},
                &mockCache{},
            )
            res := svc.GetInfo(context.Background(), tt.req)
            assert.Equal(t, tt.wantOK, res.Success)
            assert.Equal(t, tt.wantCode, res.StatusCode)
        })
    }
}
```

### 13.3 Integration Test — Repository

```go
// internal/repository/user/user_repo_integration_test.go
//go:build integration

package userrepo_test

import (
    "context"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"

    "my-api/internal/data/orm"
    userrepo "my-api/internal/repository/user"
    "my-api/internal/util/postgresql"
)

func TestUserRepo_Integration(t *testing.T) {
    postgresql.Init(os.Getenv("TEST_DATABASE_URL"))
    db := postgresql.Get()
    repo := userrepo.New(db)
    ctx := context.Background()

    t.Run("create and find", func(t *testing.T) {
        err := repo.Create(orm.UserCreateReq{
            ID: "test-1", Email: "test@example.com", Name: "Test",
        })
        require.NoError(t, err)

        user, err := repo.GetInfo(orm.UserGetInfoReq{ID: "test-1"})
        require.NoError(t, err)
        assert.Equal(t, "test@example.com", user.Email)
    })
}
```

### 13.4 Handler Test (Fiber)

```go
// internal/app/weather-api/handler/user_handler_test.go
package handler_test

import (
    "encoding/json"
    "io"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/gofiber/fiber/v2"
    "github.com/stretchr/testify/assert"
)

type mockUserSvc struct{}

func (m *mockUserSvc) GetInfo(ctx context.Context, req usersvc.UserGetInfoReq) response.Response[*usersvc.UserGetInfoRes] {
    return response.Success(&usersvc.UserGetInfoRes{ID: req.ID, Name: "Test"})
}

func TestUserHandler_GetInfo(t *testing.T) {
    app := fiber.New()
    h := handler.NewUserHandler(&mockUserSvc{})
    h.Init(app.Group("/api"))

    req := httptest.NewRequest(http.MethodGet, "/api/users/user-1", nil)
    resp, err := app.Test(req)
    assert.NoError(t, err)
    assert.Equal(t, 200, resp.StatusCode)

    body, _ := io.ReadAll(resp.Body)
    var result map[string]any
    json.Unmarshal(body, &result)
    assert.True(t, result["success"].(bool))
}
```

---

## 14. Database Patterns

### 14.1 PostgreSQL Init

```go
// internal/util/postgresql/postgresql.go
package postgresql

import (
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
    "gorm.io/gorm/logger"
)

var db *gorm.DB

func Init(dsn string) {
    var err error
    db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
        Logger: logger.Default.LogMode(logger.Silent),
    })
    if err != nil {
        panic("failed to connect database: " + err.Error())
    }

    sqlDB, _ := db.DB()
    sqlDB.SetMaxOpenConns(25)
    sqlDB.SetMaxIdleConns(5)
    sqlDB.SetConnMaxLifetime(5 * time.Minute)
}

func Get() *gorm.DB { return db }
func Close() {
    if sqlDB, err := db.DB(); err == nil {
        sqlDB.Close()
    }
}
```

### 14.2 Transaction Pattern

```go
type TX = *gorm.DB

func ExecTx(ctx context.Context, fn func(tx TX) error) error {
    return db.WithContext(ctx).Transaction(fn)
}

// Usage ใน service
err := postgresql.ExecTx(ctx, func(tx postgresql.TX) error {
    if _, err := repo.Update(tx, updateReq); err != nil {
        return err
    }
    if err := logRepo.Create(tx, logReq); err != nil {
        return err
    }
    return nil
})
```

### 14.3 Cursor-based Pagination

```go
type Cursor struct {
    TableAlias string
    OrderBy    string
    Limit      int
}

func (c Cursor) ToDefault(alias string) Cursor {
    return Cursor{
        TableAlias: alias,
        OrderBy:    alias + ".created_at DESC",
        Limit:      100,
    }
}

// ใน repo
func (r *userRepo) GetList(req orm.UserGetListReq) ([]orm.User, error) {
    var users []orm.User
    q := r.db.Model(&orm.User{}).Where("deleted_at IS NULL")
    if req.Status != "" {
        q = q.Where("status = ?", req.Status)
    }
    q = q.Order("created_at DESC").Limit(req.Limit).Offset(req.Offset)
    return users, q.Find(&users).Error
}
```

---

## 15. Logging & Observability

### 15.1 Structured Logger (slog)

```go
// internal/util/logger/logger.go
package logger

import (
    "log/slog"
    "os"
)

var log *slog.Logger

func Init(cfg config.LogConfig) {
    opts := &slog.HandlerOptions{Level: cfg.Level}
    var handler slog.Handler
    if cfg.Format == "json" {
        handler = slog.NewJSONHandler(os.Stdout, opts)
    } else {
        handler = slog.NewTextHandler(os.Stdout, opts)
    }
    log = slog.New(handler)
    slog.SetDefault(log)
}

func Info(msg string, args ...any)  { log.Info(msg, args...) }
func Error(msg string, err error, args ...any) {
    log.Error(msg, append([]any{"error", err}, args...)...)
}
func Warn(msg string, args ...any)  { log.Warn(msg, args...) }
func Debug(msg string, args ...any) { log.Debug(msg, args...) }
```

### 15.2 Health Check Endpoint

```go
// ใน route
app.Get("/health", func(c *fiber.Ctx) error {
    return c.JSON(fiber.Map{"status": "ok"})
})

// Readiness check
app.Get("/ready", func(c *fiber.Ctx) error {
    sqlDB, _ := postgresql.Get().DB()
    if err := sqlDB.Ping(); err != nil {
        return c.Status(503).JSON(fiber.Map{"status": "unhealthy", "db": err.Error()})
    }
    return c.JSON(fiber.Map{"status": "healthy"})
})
```

---

## 16. Security Best Practices

### 16.1 JWT

```go
import "github.com/golang-jwt/jwt/v5"

type Claims struct {
    UserID string `json:"userId"`
    jwt.RegisteredClaims
}

func GenerateToken(userID, secret string, exp time.Duration) (string, error) {
    claims := Claims{
        UserID: userID,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(exp)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
        },
    }
    return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
}

func VerifyToken(tokenStr, secret string) (*Claims, error) {
    token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (any, error) {
        if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, fmt.Errorf("unexpected signing method")
        }
        return []byte(secret), nil
    })
    if err != nil || !token.Valid {
        return nil, errors.New("invalid token")
    }
    return token.Claims.(*Claims), nil
}
```

### 16.2 Input Validation

```go
// internal/util/validation/validation.go
package validation

import "github.com/go-playground/validator/v10"

type Validate interface {
    Check(s any) map[string]string
}

type validate struct {
    v *validator.Validate
}

func New() Validate {
    return &validate{v: validator.New()}
}

func (vl *validate) Check(s any) map[string]string {
    err := vl.v.Struct(s)
    if err == nil {
        return nil
    }
    errors := make(map[string]string)
    for _, e := range err.(validator.ValidationErrors) {
        errors[e.Field()] = e.Tag()
    }
    return errors
}

// Usage ใน service
type UserCreateReq struct {
    Email string `json:"email" validate:"required,email"`
    Name  string `json:"name"  validate:"required,min=2,max=100"`
}

if valMap := svc.validate.Check(req); len(valMap) > 0 {
    return response.ValidationFailed[*Res](valMap)
}
```

### 16.3 SQL Injection Prevention

```go
// ✅ Parameterized query เสมอ (GORM จัดการให้อัตโนมัติ)
db.Where("email = ? AND status = ?", email, status).Find(&users)

// ❌ อย่าต่อ string
db.Where(fmt.Sprintf("email = '%s'", email)) // SQL injection!
```

---

## 17. Concurrency Patterns

### 17.1 Graceful Shutdown

```go
func Run() {
    ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
    defer func() {
        stop()
        cleanup() // close DB, Redis, etc.
    }()

    go server.Listen(":8080")
    <-ctx.Done()
    slog.Info("shutting down")
}
```

### 17.2 Worker / Job Pattern

```go
type Job struct {
    worker  int
    ticker  time.Duration
    fn      func(ctx context.Context) error
}

func StartJob(ctx context.Context, cfg JobConfig, fn func(ctx context.Context) error) {
    ticker := time.NewTicker(cfg.Interval)
    defer ticker.Stop()
    for {
        select {
        case <-ticker.C:
            if err := fn(ctx); err != nil {
                slog.Error("job failed", "error", err)
            }
        case <-ctx.Done():
            return
        }
    }
}
```

### 17.3 Context Timeout

```go
// ตั้ง timeout ให้ operation ที่ใช้เวลา
ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
defer cancel()

result, err := repo.GetList(ctx, req)
```

---

## 18. Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| **Packages** | lowercase, single word | `usersvc`, `userrepo`, `middleware` |
| **Files** | snake_case | `user_svc.go`, `user_repo_impl.go` |
| **Exported types** | PascalCase | `UserService`, `GetInfo` |
| **Unexported** | camelCase | `userSvc`, `getInfo` |
| **Interfaces** | ไม่ต้อง `-er` suffix ถ้าชื่อมันชัดอยู่แล้ว | `UserSvc`, `UserRepo` |
| **Constructors** | `New` prefix | `NewUserSvc`, `NewUserRepo` |
| **Constants / keys** | ALL_CAPS หรือ PascalCase | `PERM_USER_READ`, `CacheTTLLong` |
| **Service package name** | ลงท้าย `svc` | `package usersvc` |
| **Repository package name** | ลงท้าย `repo` | `package userrepo` |

---

## 19. Production Readiness

### 19.1 Dockerfile (Multi-stage)

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main cmd/api/main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
```

### 19.2 Checklist ก่อน Deploy

- [ ] Health endpoint `/health` และ `/ready`
- [ ] Graceful shutdown (signal handling)
- [ ] Structured logging (JSON format)
- [ ] Environment config ผ่าน `.env` / secrets manager
- [ ] Database connection pool configured
- [ ] Recovery middleware ครอบ panics
- [ ] CORS configured ถูกต้อง
- [ ] Rate limiter (ถ้าต้องการ)
- [ ] Unit tests pass
- [ ] Integration tests pass

---

## Summary

| Layer | ไฟล์ | หน้าที่ |
|-------|------|---------|
| **Entry** | `cmd/api/main.go` | เรียก `app.Run()` |
| **Bootstrap** | `internal/app/api/app.go` | init infra + wire dependencies |
| **Route** | `internal/app/api/route/route.go` | register middleware + handlers |
| **Handler** | `internal/app/api/handler/*.go` | parse request, เรียก service, return response |
| **Service** | `internal/app/api/service/*/` | business logic, validation, cache |
| **Repository** | `internal/repository/*/` | DB queries เท่านั้น |
| **Data/ORM** | `internal/data/orm/` | DB model structs |
| **Response** | `internal/util/response/` | `Response[T]` wrapper |
| **Web** | `internal/util/web/` | `HTTPHandler` interface + registrator |
| **Config** | `internal/config/` | env vars → struct |

**Key rules:**
1. **DI ผ่าน constructor เสมอ** — ห้าม `New...()` ใน implementation
2. **Service return `Response[T]`** — handler แค่เรียก `.JSON(c)`
3. **Repo รับ context** — เพื่อ cancel/timeout ได้
4. **Interface เล็ก** — แต่ละ interface ทำหน้าที่เดียว
5. **Test service ด้วย mock repo** — ไม่ต้องการ DB จริง

---

*Updated: May 2026 — Based on actual project patterns (cop-adp-wfcap-api)*
