# GMP v2 Scaffold Templates

Placeholders: `{{MODULE}}` go module (`dpp`), `{{BIN}}` binary dir (`dpp-api`),
`{{PKG}}` app package (`dppapi`), `{{TITLE}}` API title, `{{UTIL}}` goutil module path.
Copy verbatim; replace placeholders only. Lines marked `// redis` are dropped when Redis is not used.

## cmd/{{BIN}}/main.go

```go
package main

import (
	"os"

	"{{MODULE}}/internal/app/{{PKG}}"
)

// @title {{TITLE}}
// @version 1.0
// @BasePath /api/v1
// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
func main() {
	// Run already logs the cause; only the exit code is decided here.
	if err := {{PKG}}.Run(); err != nil {
		os.Exit(1)
	}
}
```

## internal/app/{{PKG}}/app.go

```go
package {{PKG}}

import (
	"context"
	"fmt"
	"log/slog"
	"os/signal"
	"syscall"
	"time"

	"{{MODULE}}/internal/app/{{PKG}}/middleware"
	"{{MODULE}}/internal/app/{{PKG}}/route"
	"{{MODULE}}/internal/config"

	"{{UTIL}}/logger"
	"{{UTIL}}/redisdb" // redis
	"{{UTIL}}/validation"
)

// shutdownTimeout bounds how long in-flight requests get to finish after SIGINT/SIGTERM.
const shutdownTimeout = 10 * time.Second

// Run returns instead of exiting so deferred cleanups always run; main decides the exit code.
func Run() error {
	cfg, err := config.Load()
	if err != nil {
		slog.Error("invalid config", "error", err)
		return err
	}
	slog.SetDefault(logger.New(logger.Options{Level: cfg.LogLevel, Format: cfg.LogFormat}))

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	// Open each resource and defer its Close right after; defers run after Shutdown, in reverse order.
	cache, err := redisdb.New(ctx, redisdb.Options{ // redis
		Hosts: cfg.Redis.Hosts, Password: cfg.Redis.Password, // redis
		UseCluster: cfg.Redis.UseCluster, UseTLS: cfg.Redis.UseTLS, DB: cfg.Redis.CacheIdx, // redis
	}) // redis
	if err != nil { // redis
		slog.Error("redis connect failed", "error", err) // redis
		return err // redis
	} // redis
	defer cache.Close() // redis

	validate := validation.New()

	// repositories, e.g. ticketRepo := ticketrepo.New(db)
	// services, e.g. ticketSvc := ticketsvc.New(ticketRepo, cache, validate)
	_ = validate

	app := route.New(route.Deps{
		Config:     cfg,
		Middleware: middleware.New(),
		// TicketSvc: ticketSvc,
	})

	errCh := make(chan error, 1)
	go func() {
		slog.Info("start server", "port", cfg.Web.Port)
		errCh <- app.Listen(fmt.Sprintf(":%d", cfg.Web.Port))
	}()

	// Block until a signal arrives or the server fails to start (e.g. port in use).
	select {
	case err := <-errCh:
		slog.Error("server stopped unexpectedly", "error", err)
		return err
	case <-ctx.Done():
		stop() // restore default signal handling: a second Ctrl+C force-kills
		slog.Info("shutdown signal received")
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
	defer cancel()
	if err := app.Shutdown(shutdownCtx); err != nil {
		slog.Error("graceful shutdown failed", "error", err)
		return err
	}
	slog.Info("server stopped")
	return nil
}
```

## internal/app/{{PKG}}/route/route.go

```go
package route

import (
	"context"

	"{{MODULE}}/internal/app/{{PKG}}/handler"
	"{{MODULE}}/internal/app/{{PKG}}/middleware"
	"{{MODULE}}/internal/config"

	"{{UTIL}}/response"
	"{{UTIL}}/web"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/cors"
)

type Route interface {
	Listen(addr string) error
	Shutdown(ctx context.Context) error
}

// Deps is everything the routes need; built once in app.go.
type Deps struct {
	Config     *config.Config
	Middleware middleware.Middleware
	// services go here as resources are added, e.g. TicketSvc ticketsvc.Svc
}

type route struct {
	app  *fiber.App
	deps Deps
}

// New builds the app with all middleware and routes registered; it reads no globals.
func New(deps Deps) Route {
	r := &route{
		// every error, including 404/405 and recovered panics, leaves as the envelope
		app:  fiber.New(fiber.Config{ErrorHandler: response.ErrorHandler}),
		deps: deps,
	}

	mw := deps.Middleware
	// AccessLog wraps Recovery so recovered panics are logged with their 500
	r.app.Use(mw.RequestID, mw.AccessLog, mw.Recovery)
	r.useCORS()

	api := r.app.Group("/api/v1")
	r.registerPublicHandlers(api)

	// private := api.Use(mw.Authorization)
	// r.registerPrivateHandlers(private)
	return r
}

func (r *route) Listen(addr string) error {
	return r.app.Listen(addr)
}

// Shutdown stops accepting new connections and waits for in-flight requests until ctx expires.
func (r *route) Shutdown(ctx context.Context) error {
	return r.app.ShutdownWithContext(ctx)
}

func (r *route) registerPublicHandlers(root fiber.Router) {
	web.Register(root,
		handler.NewHealthHandler(),
		// handler.NewTicketHandler(r.deps.TicketSvc),
	)

	// API docs at /api/v1/docs, not exposed in prod
	if r.deps.Config.ServerMode != "prod" {
		web.Register(root, handler.NewSwaggerHandler())
	}
}

func (r *route) useCORS() {
	r.app.Use(cors.New(cors.Config{
		AllowOrigins: r.deps.Config.Web.CORSAllowOrigin,
		AllowHeaders: []string{"Origin", "Content-Type", "Accept", "Authorization"},
		AllowMethods: []string{"GET", "POST", "HEAD", "PUT", "DELETE", "PATCH", "OPTIONS"},
		// no credentials: clients send a Bearer token, never cookies
	}))
}
```

## internal/app/{{PKG}}/route/route_test.go

```go
package route

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"{{MODULE}}/internal/app/{{PKG}}/middleware"
	"{{MODULE}}/internal/config"
	"{{MODULE}}/internal/meta"

	"github.com/gofiber/fiber/v3"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// testDeps returns Deps with an explicit config, so no .env is read.
func testDeps() Deps {
	return Deps{
		Config: &config.Config{
			ServerMode: "local",
			Web:        config.WebConfig{CORSAllowOrigin: []string{"http://example.com"}},
		},
		Middleware: middleware.New(),
	}
}

func newTestApp(t *testing.T, deps Deps) *fiber.App {
	t.Helper()
	r := New(deps).(*route)
	r.app.Get("/api/v1/boom", func(c fiber.Ctx) error { panic("boom") })
	return r.app
}

func errorCode(t *testing.T, resp *http.Response) string {
	t.Helper()
	var body struct {
		Success bool `json:"success"`
		Error   struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	require.NoError(t, json.NewDecoder(resp.Body).Decode(&body))
	assert.False(t, body.Success)
	return body.Error.Code
}

func TestRoute_Health(t *testing.T) {
	resp, err := newTestApp(t, testDeps()).Test(httptest.NewRequest(http.MethodGet, "/api/v1/health", nil))
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)
	assert.NotEmpty(t, resp.Header.Get("X-Request-Id"))
}

func TestRoute_UnknownRoute_ReturnsEnvelope(t *testing.T) {
	resp, err := newTestApp(t, testDeps()).Test(httptest.NewRequest(http.MethodGet, "/api/v1/nope", nil))
	require.NoError(t, err)
	assert.Equal(t, http.StatusNotFound, resp.StatusCode)
	assert.Equal(t, meta.ErrCodeNotFound, errorCode(t, resp))
}

func TestRoute_Panic_ReturnsInternal(t *testing.T) {
	resp, err := newTestApp(t, testDeps()).Test(httptest.NewRequest(http.MethodGet, "/api/v1/boom", nil))
	require.NoError(t, err)
	assert.Equal(t, http.StatusInternalServerError, resp.StatusCode)
	assert.Equal(t, meta.ErrCodeInternal, errorCode(t, resp))
}

func TestRoute_DocsHiddenInProd(t *testing.T) {
	deps := testDeps()
	deps.Config.ServerMode = "prod"
	resp, err := newTestApp(t, deps).Test(httptest.NewRequest(http.MethodGet, "/api/v1/docs", nil))
	require.NoError(t, err)
	assert.Equal(t, http.StatusNotFound, resp.StatusCode)
}

func TestRoute_CORS_NoCredentials(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/v1/health", nil)
	req.Header.Set("Origin", "http://example.com")
	resp, err := newTestApp(t, testDeps()).Test(req)
	require.NoError(t, err)
	assert.Equal(t, "http://example.com", resp.Header.Get("Access-Control-Allow-Origin"))
	assert.Empty(t, resp.Header.Get("Access-Control-Allow-Credentials"))
}
```

## internal/app/{{PKG}}/middleware/middleware.go

```go
package middleware

import (
	"fmt"
	"log/slog"
	"runtime/debug"
	"strings"
	"time"

	"{{MODULE}}/internal/meta"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"
)

type Middleware interface {
	RequestID(c fiber.Ctx) error
	AccessLog(c fiber.Ctx) error
	Recovery(c fiber.Ctx) error
}

type middleware struct{}

func New() Middleware {
	return &middleware{}
}

func (m *middleware) RequestID(c fiber.Ctx) error {
	id := uuid.NewString()
	c.Locals(meta.LocalRequestID, id)
	c.Set("X-Request-Id", id)
	return c.Next()
}

// Recovery turns a panic into an error so the ErrorHandler answers with a 500 envelope.
func (m *middleware) Recovery(c fiber.Ctx) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("panic: %v", r)
			slog.ErrorContext(c.Context(), "panic recovered",
				"error", err, "stack", string(debug.Stack()), "requestId", c.Locals(meta.LocalRequestID))
		}
	}()
	return c.Next()
}

// AccessLog runs the ErrorHandler itself so the logged status is the one the client gets.
func (m *middleware) AccessLog(c fiber.Ctx) error {
	if strings.HasSuffix(c.Path(), "/health") {
		return c.Next()
	}
	start := time.Now()
	if err := c.Next(); err != nil {
		c.Locals(meta.LocalErr, err)
		if hErr := c.App().ErrorHandler(c, err); hErr != nil {
			_ = c.SendStatus(fiber.StatusInternalServerError)
		}
	}
	attrs := []any{
		"method", c.Method(),
		"path", c.Path(),
		"status", c.Response().StatusCode(),
		"latencyMs", time.Since(start).Milliseconds(),
		"requestId", c.Locals(meta.LocalRequestID),
	}
	if e, ok := c.Locals(meta.LocalErr).(error); ok && e != nil {
		attrs = append(attrs, "error", e.Error())
	}
	slog.InfoContext(c.Context(), "http", attrs...)
	return nil
}
```

## internal/app/{{PKG}}/handler/health_handler.go

```go
package handler

import (
	"{{UTIL}}/response"
	"{{UTIL}}/web"

	"github.com/gofiber/fiber/v3"
)

type healthHandler struct{}

func NewHealthHandler() web.HTTPHandler {
	return &healthHandler{}
}

func (h *healthHandler) Init(router fiber.Router) {
	router.Get("/health", h.Health)
}

// Health is a liveness probe: it never touches the DB.
//
// @summary health check
// @tags health
// @id Health
// @produce json
// @success 200 {object} map[string]any "OK"
// @Router /health [get]
func (h *healthHandler) Health(c fiber.Ctx) error {
	return response.OK(fiber.Map{"status": "ok"}).JSON(c)
}
```

## internal/app/{{PKG}}/handler/swagger_handler.go

```go
package handler

import (
	"{{MODULE}}/internal/app/{{PKG}}/docs"

	"{{UTIL}}/web"

	scalar "github.com/MarceloPetrucio/go-scalar-api-reference"
	"github.com/gofiber/contrib/v3/swaggo"
	"github.com/gofiber/fiber/v3"
)

type swaggerHandler struct{}

func NewSwaggerHandler() web.HTTPHandler {
	return &swaggerHandler{}
}

func (h *swaggerHandler) Init(router fiber.Router) {
	router.Get("/docs", h.Document)
	router.Get("/docs/*", swaggo.HandlerDefault)
}

func (h *swaggerHandler) Document(c fiber.Ctx) error {
	html, err := scalar.ApiReferenceHTML(&scalar.Options{
		// embedded spec from `make swag`; the image ships no spec file to read from disk
		SpecContent:   docs.SwaggerInfo.ReadDoc(),
		CustomOptions: scalar.CustomOptions{PageTitle: "{{TITLE}}"},
		DarkMode:      true,
	})
	if err != nil {
		return err
	}
	c.Type("html")
	return c.SendString(html)
}
```

## internal/config/config.go

Only fields the product uses. Add a block when its integration lands.

```go
package config

import (
	"errors"
	"log/slog"

	"{{UTIL}}/envx"

	"github.com/joho/godotenv"
)

type Config struct {
	ServerMode string // local, dev, staging, prod
	LogLevel   slog.Level
	LogFormat  string // JSON, TEXT
	Web        WebConfig
	Redis      RedisConfig // redis
}

type WebConfig struct {
	Port            int
	CORSAllowOrigin []string
}

type RedisConfig struct { // redis
	Hosts      []string
	Password   string
	UseCluster bool
	UseTLS     bool
	CacheIdx   int
}

// defaultLocalOrigin is the frontend dev server, used when ACCESS_ORIGIN is unset in local mode.
const defaultLocalOrigin = "http://localhost:3000"

// Load reads .env if present (real env vars win) and returns a validated Config.
func Load() (*Config, error) {
	_ = godotenv.Load()

	mode := envx.String("SERVER_MODE", "local")
	corsDefault := []string{}
	if mode == "local" {
		corsDefault = []string{defaultLocalOrigin}
	}

	cfg := &Config{
		ServerMode: mode,
		LogLevel:   envx.LogLevel("LOG_LEVEL", slog.LevelInfo),
		LogFormat:  envx.String("LOG_FORMAT", "JSON"),
		Web: WebConfig{
			Port:            envx.Int("PORT", 8080),
			CORSAllowOrigin: envx.StringSlice("ACCESS_ORIGIN", corsDefault),
		},
		Redis: RedisConfig{ // redis
			Hosts:      envx.StringSlice("REDIS_HOST", nil),
			Password:   envx.String("REDIS_PASSWORD", ""),
			UseCluster: envx.Bool("REDIS_USE_CLUSTER", false),
			UseTLS:     envx.Bool("REDIS_USE_TLS", false),
			CacheIdx:   envx.Int("REDIS_CACHE_INDEX", 0),
		},
	}
	return cfg, cfg.Validate()
}

// Validate reports settings the server cannot start without.
func (c *Config) Validate() error {
	var errs []error
	if len(c.Web.CORSAllowOrigin) == 0 {
		errs = append(errs, errors.New("ACCESS_ORIGIN is required: comma-separated list of allowed origins"))
	}
	if len(c.Redis.Hosts) == 0 { // redis
		errs = append(errs, errors.New("REDIS_HOST is required")) // redis
	} // redis
	return errors.Join(errs...)
}
```

## internal/domain/errors.go

```go
package domain

import "errors"

// Sentinels returned by repositories; services map them with errors.Is.
var (
	ErrNotFound      = errors.New("not found")
	ErrAlreadyExists = errors.New("already exists")
)
```

## internal/meta/error_codes.go

```go
package meta

// Machine-readable error.code values (API spec in docs/).
const (
	ErrCodeBadRequest      = "BAD_REQUEST"
	ErrCodeValidation      = "VALIDATION_ERROR"
	ErrCodeUnauthorized    = "UNAUTHORIZED"
	ErrCodeForbidden       = "FORBIDDEN"
	ErrCodeNotFound        = "NOT_FOUND"
	ErrCodeConflict        = "CONFLICT"
	ErrCodePayloadTooLarge = "PAYLOAD_TOO_LARGE"
	ErrCodeInternal        = "INTERNAL_ERROR"
)
```

These must equal the codes goutil `response.ErrorHandler` emits for the matching statuses.

## internal/meta/locals.go

```go
package meta

// Keys for fiber.Ctx Locals.
const (
	LocalRequestID = "requestId"
	// LocalErr holds the internal error behind a response, for the access log only.
	LocalErr = "err"
)
```

## internal/data/orm/doc.go

```go
// Package orm holds DB models, one file per resource (e.g. ticket.go).
// Models never leave the service layer as JSON; services map them to XxxRes.
package orm
```

## Makefile

```makefile
.PHONY: db-up db-down run build test vet fmt lint tidy swag

db-up:
	docker compose up -d --wait

db-down:
	docker compose down

run:
	go run ./cmd/{{BIN}}

build:
	go build -o bin/{{BIN}} ./cmd/{{BIN}}

test:
	go test -race -count=1 ./...

vet:
	go vet ./...

fmt:
	gofmt -l -w .

lint:
	golangci-lint run

tidy:
	go mod tidy

swag:
	swag init -g cmd/{{BIN}}/main.go -d ./ -o internal/app/{{PKG}}/docs --parseInternal --parseDependency
```

## Dockerfile

```dockerfile
FROM golang:1.26-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY cmd ./cmd
COPY internal ./internal
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/{{BIN}} ./cmd/{{BIN}}

FROM alpine:3.22
RUN apk --no-cache add ca-certificates tzdata && adduser -D -u 10001 app
USER app
WORKDIR /home/app
COPY --from=builder /out/{{BIN}} ./
EXPOSE 8080
CMD ["./{{BIN}}"]
```

If goutil is a private repo, add `ARG GOPRIVATE` and a build secret for git credentials before `go mod download`.

## docker-compose.yml (only the services the project uses)

```yaml
services:
  postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app
      POSTGRES_DB: app
    ports: ["5432:5432"]
    volumes: [pgdata:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d app"]
      interval: 2s
      timeout: 3s
      retries: 20
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 2s
      timeout: 3s
      retries: 20

volumes:
  pgdata:
```

## .env.example

```dotenv
SERVER_MODE=local
LOG_LEVEL=info
LOG_FORMAT=TEXT
PORT=8080
ACCESS_ORIGIN=http://localhost:3000
REDIS_HOST=localhost:6379
REDIS_PASSWORD=
REDIS_USE_CLUSTER=false
REDIS_USE_TLS=false
REDIS_CACHE_INDEX=0
```

## .gitignore

```gitignore
bin/
storage/
.env
*.pem
.DS_Store
coverage.out
```

## .golangci.yml

```yaml
version: "2"
linters:
  enable:
    - errcheck
    - govet
    - staticcheck
    - unused
    - ineffassign
    - bodyclose
    - contextcheck
    - errorlint
    - gosec
```
