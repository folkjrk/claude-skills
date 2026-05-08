# Project Framework Manual

A reference guide for replicating the architecture and structure of this project.

---

## Table of Contents

1. [Tech Stack](#1-tech-stack)
2. [Project Structure](#2-project-structure)
3. [Setup & Environment](#3-setup--environment)
4. [Babel Configuration](#4-babel-configuration)
5. [Docker](#5-docker)
6. [Routing](#6-routing)
7. [State Management (Redux)](#7-state-management-redux)
8. [API Layer](#8-api-layer)
9. [Internationalization (i18n)](#9-internationalization-i18n)
10. [Form Handling](#10-form-handling)
11. [Authentication & Authorization](#11-authentication--authorization)
12. [Styling](#12-styling)
13. [Custom Hooks](#13-custom-hooks)
14. [Component Patterns](#14-component-patterns)
15. [Real-time (SSE)](#15-real-time-sse)
16. [Testing](#16-testing)
17. [Key Conventions](#17-key-conventions)

---

## 1. Tech Stack

| Category          | Library                                            | Version           |
| ----------------- | -------------------------------------------------- | ----------------- |
| Framework         | react-router                                       | ^7.13.1           |
| Router (dev)      | @react-router/dev                                  | ^7.13.1           |
| Router (routes)   | @react-router/fs-routes                            | ^7.13.1           |
| Router (node)     | @react-router/node                                 | ^7.13.1           |
| Router (serve)    | @react-router/serve                                | ^7.13.1           |
| UI                | react + react-dom                                  | ^19.1.0           |
| Language          | typescript                                         | ^5.8.3            |
| Build             | vite                                               | ^6.3.3            |
| State             | @reduxjs/toolkit + react-redux                     | ^2.8.2 / ^9.2.0   |
| Forms             | react-hook-form                                    | ^7.62.0           |
| Form Resolvers    | @hookform/resolvers                                | ^5.2.1            |
| Validation        | zod                                                | ^4.1.3            |
| Styling           | tailwindcss                                        | ^4.1.4            |
| i18n              | i18next + react-i18next                            | ^25.4.0 / ^15.7.0 |
| Language Detector | i18next-browser-languagedetector                   | ^8.2.0            |
| UI Primitives     | @headlessui/react                                  | ^2.2.7            |
| Icons             | @heroicons/react                                   | ^2.2.0            |
| Animation         | framer-motion                                      | ^12.23.12         |
| Date              | dayjs (+ timezone, UTC, buddhistEra plugins)       | ^1.11.13          |
| PDF               | jspdf + jspdf-autotable                            | ^4.2.0 / ^5.0.7   |
| Class names       | clsx                                               | ^2.1.1            |
| SVG as component  | vite-plugin-svgr                                   | ^4.3.0            |
| Bot detection     | isbot                                              | ^5               |
| Testing           | jest + ts-jest                                     | ^29.7.0 / ^29.1.2 |
| Testing DOM       | @testing-library/react + @testing-library/jest-dom | ^16.1.0 / ^6.4.2  |
| Test env          | jest-environment-jsdom                             | ^29.7.0           |

---

## 2. Project Structure

```
/
├── app/                         # All source code lives here
│   ├── routes/                  # File-based route pages
│   ├── components/              # Reusable UI and feature components
│   │   ├── [feature]/           # Domain-specific components (e.g., payment/)
│   │   ├── __tests__/           # Component unit tests
│   │   └── button.tsx, input.tsx, dialog.tsx, ...   # UI primitives
│   ├── hooks/                   # Custom React hooks
│   ├── stores/                  # Redux store (index.ts + slices)
│   ├── api/                     # API call functions (grouped by domain)
│   ├── i18n/
│   │   ├── index.ts             # i18n initialization
│   │   ├── types.ts             # Translation key types
│   │   └── locales/
│   │       ├── en.json
│   │       └── th.json
│   ├── utils/                   # Utility/helper functions
│   ├── config/                  # Static config (e.g., navigation menus)
│   ├── provider/                # React context providers
│   ├── data/                    # Static data files
│   ├── assets/                  # SVGs and images
│   ├── root.tsx                 # Root layout: providers, navbar, sidebar
│   ├── app.css                  # Global CSS
│   ├── types.ts                 # Global TypeScript types
│   ├── constants.tsx            # App-wide constants (columns, statuses, etc.)
│   ├── config.ts                # Reads env variables, exposes via hook
│   └── field-lengths.ts         # Max character length constants per field
├── public/                      # Static public files
├── types/                       # Ambient/global type declarations
├── __mocks__/                   # Jest module mocks
├── vite.config.ts
├── vite-env.d.ts           # Vite client types + SVG?react module declaration
├── react-router.config.ts
├── tailwind.config.ts
├── tsconfig.json
├── babel.config.cjs
├── jest.config.mjs
├── jest.setup.js
└── .env
```

---

## 3. Setup & Environment

### Create a new React Router project

Bootstrap the project using the React Router CLI:

```bash
npm create-react-router@latest my-app
cd my-app
```

> This scaffolds the project with React Router v7, Vite, and TypeScript pre-configured.

### Install dependencies

```bash
npm install
```

> **Note:** `@react-router/serve` must be included in `dependencies` (not just `devDependencies`) to enable `npm start` in production. The binary `react-router-serve` is provided by this package.
>
> ```bash
> npm install @react-router/serve
> ```

### Environment variables (`.env`)

```env
VITE_API_URL=http://localhost:8080/api
VITE_COGNITO_ENDPOINT=https://<your-cognito-domain>.amazoncognito.com
VITE_COGNITO_AUTH_CLIENT_ID=<client-id>
VITE_COGNITO_AUTH_REDIRECT_URL=http://localhost:8080/api/auth/cb
VITE_COGNITO_LOGOUT_URL=https://<your-cognito-domain>.amazoncognito.com/logout
VITE_IS_DEBUG=true
```

All env vars are read in `app/config.ts` and exposed via a default-export function (used as `useConfig()`) so components never read `import.meta.env` directly.

### `app/config.ts`

```ts
import isClient from "@/hooks/isClient";

// Works in both Vite (import.meta.env) and Jest (globalThis.import.meta.env)
const getEnv = () => {
  try {
    const importMeta = (0, eval)("import.meta");
    if (importMeta?.env) return importMeta.env;
  } catch {
    // fall through
  }
  return (globalThis as any).import?.meta?.env || {};
};

const env = getEnv();

const DefaultConfig = {
  Debug: env.VITE_IS_DEBUG,
  ApiUrl: env.VITE_API_URL,
  CognitoAuthClientId: env.VITE_COGNITO_AUTH_CLIENT_ID,
  CognitoAuthRedirectUrl: env.VITE_COGNITO_AUTH_REDIRECT_URL,
  CognitoEndpoint: env.VITE_COGNITO_ENDPOINT,
  AppVersion: env.VITE_APP_VERSION,
  DispensingUrl: env.VITE_DISPENSING_URL,
  LogoutUrl: env.VITE_COGNITO_LOGOUT_URL,
};

export default () => {
  let config = { ...DefaultConfig } as any;

  // On the client, prefer window.ENV (injected by SSR loader) over build-time values
  if (isClient() && (window as any).ENV) {
    const w = (window as any).ENV;
    config = { ...config, ...w };
  }

  config.getCognitoLoginUrl = (state?: string) => {
    let url = `${config.CognitoEndpoint}/login?client_id=${config.CognitoAuthClientId}&response_type=code&scope=openid&redirect_uri=${encodeURIComponent(config.CognitoAuthRedirectUrl)}`;
    if (state) url += `&state=${encodeURIComponent(state)}`;
    return url;
  };

  config.getCognitoLogoutUrl = () =>
    `${config.CognitoEndpoint}/logout?client_id=${config.CognitoAuthClientId}&logout_uri=${encodeURIComponent(config.LogoutUrl)}`;

  return config;
};
```

> The `window.ENV` fallback is populated by the root loader in `root.tsx` which passes server-side env to the client — this is the standard SSR pattern for runtime config.

### Scripts

```bash
npm run dev        # Dev server (port 3000)
npm run build      # Production build (SSR)
npm run start      # Serve production build (requires @react-router/serve)
npm run typecheck  # TypeScript check
npm run test       # Jest tests
npm run test:watch # Jest watch mode
npm run storybook  # Storybook dev (port 6006)
```

> `npm start` uses `react-router-serve` from `@react-router/serve`. Always run `npm run build` before `npm start`.

### `vite.config.ts`

```ts
import { reactRouter } from "@react-router/dev/vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";
import tsconfigPaths from "vite-tsconfig-paths";
import svgr from "vite-plugin-svgr";

export default defineConfig({
  plugins: [tailwindcss(), reactRouter(), tsconfigPaths(), svgr()],
  server: {
    port: 3000,
  },

  build: {
    sourcemap: true,
  },
});
```

> Note: `reactRouter()` from `@react-router/dev/vite` already includes React support. Do **not** add `@vitejs/plugin-react` separately.

### `react-router.config.ts`

```ts
import type { Config } from "@react-router/dev/config";

export default {
  ssr: true, // set to false for SPA mode
} satisfies Config;
```

### `postcss.config.js`

Required for TailwindCSS v4:

```js
export default {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};
```

### TypeScript config (`tsconfig.json`)

```json
{
  "include": [
    "**/*",
    "**/.server/**/*",
    "**/.client/**/*",
    ".react-router/types/**/*",
    "types/**/*"
  ],
  "compilerOptions": {
    "lib": ["DOM", "DOM.Iterable", "ES2022"],
    "types": ["node", "vite/client", "jest"],
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "rootDirs": [".", "./.react-router/types"],
    "baseUrl": ".",
    "paths": {
      "@/*": ["./app/*"]
    },
    "esModuleInterop": true,
    "verbatimModuleSyntax": false,
    "noEmit": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "strict": false
  }
}
```

Key notes:
- `include` covers `.server`/`.client` directories and `.react-router/types` (auto-generated route types)
- `"types": ["node", "vite/client", "jest"]` — explicit type roots so `import.meta`, Node globals, and Jest globals are all available
- `rootDirs` includes `.react-router/types` so generated route types resolve without explicit imports
- `strict: false` — intentionally disabled; add per-file `// @ts-strict` if needed
- `verbatimModuleSyntax: false` — allows mixed `import`/`import type` without enforcement

### Vite environment types (`vite-env.d.ts`)

This file lives at the project root and serves two purposes:

```ts
/// <reference types="vite/client" />

declare module "*.svg?react" {
  const ReactComponent: React.FunctionComponent<React.SVGProps<SVGSVGElement>>;
  export default ReactComponent;
}
```

- **`/// <reference types="vite/client" />`** — pulls in Vite's `ImportMeta` interface so `import.meta.env` and `import.meta.hot` are typed everywhere (works alongside `"vite/client"` in `tsconfig.json` `types`)
- **`*.svg?react` module declaration** — required when using `vite-plugin-svgr` so TypeScript accepts `import Logo from "@/assets/logo.svg?react"` as a React component

---

## 4. Babel Configuration

Babel is used **only for Jest** (not for the Vite dev/build pipeline, which uses `@vitejs/plugin-react`).

### `babel.config.cjs`

```js
module.exports = function (api) {
  api.cache(true);

  const importMetaPlugin = require("./babel-plugin-import-meta-transform.cjs");

  return {
    presets: [
      ["@babel/preset-env", { targets: { node: "current" } }],
      "@babel/preset-typescript",
      ["@babel/preset-react", { runtime: "automatic" }],
    ],
    plugins: [
      importMetaPlugin, // transforms import.meta.env for Jest compatibility
    ],
  };
};
```

### Required dev dependencies

```json
"@babel/preset-env": "^7.28.3",
"@babel/preset-react": "^7.27.1",
"@babel/preset-typescript": "^7.27.1",
"babel-jest": "^29.7.0"
```

### Custom plugin: `babel-plugin-import-meta-transform.cjs`

Vite uses `import.meta.env` for environment variables, but Jest runs in Node.js where `import.meta` is not available. This custom Babel plugin rewrites `import.meta.env.*` → `global.import.meta.env.*` at test time.

```js
// babel-plugin-import-meta-transform.cjs
module.exports = function (babel) {
  const { types: t } = babel;
  return {
    name: "import-meta-transform",
    visitor: {
      MemberExpression(path) {
        if (
          path.node.object?.type === "MetaProperty" &&
          path.node.object.meta?.name === "import" &&
          path.node.object.property?.name === "meta"
        ) {
          path.replaceWith(
            t.memberExpression(
              t.memberExpression(
                t.identifier("global"),
                t.identifier("import"),
              ),
              t.identifier("meta"),
            ),
          );
        }
      },
    },
  };
};
```

Then in `jest.setup.js`, set up mock values:

```js
global.import = {
  meta: {
    env: {
      VITE_API_URL: "http://localhost:8080/api",
      VITE_IS_DEBUG: "false",
      // ...other vars
    },
  },
};
```

---

## 5. Docker

The project uses a **multi-stage Docker build** to keep the final image small and secure.

### `Dockerfile`

```dockerfile
FROM node:25.5.0-alpine AS base

# Stage 1: Install all dependencies (including dev)
FROM base AS deps
ENV NODE_ENV=production
WORKDIR /app
ADD package.json /app
RUN npm install --include=dev

# Stage 2: Prune to production-only dependencies
FROM base AS production-deps
WORKDIR /app
COPY --from=deps /app/node_modules /app/node_modules
ADD package.json ./
RUN npm prune --omit=dev

# Stage 3: Build the app
FROM base AS builder
LABEL stage=builder
WORKDIR /app
COPY --from=deps /app/node_modules /app/node_modules
ADD . .
RUN npm run build

# Stage 4: Final runtime image
FROM base

ARG USER=default
ENV HOME /home/$USER

# Create non-root user
RUN apk add --update sudo
RUN adduser -D $USER \
    && echo "$USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER \
    && chmod 0440 /etc/sudoers.d/$USER

ENV NODE_ENV=production
ARG APP_VERSION
ENV VITE_APP_VERSION=${APP_VERSION}

# Copy only what is needed to run
COPY --from=production-deps /app/node_modules /node_modules
COPY --from=deps /app/package.json /package.json
COPY --from=builder /app/build /build
COPY --from=builder /app/app-start.sh /app-start.sh

RUN chmod +x /app-start.sh \
    && chown $USER:$USER /app-start.sh \
    && npm uninstall -g npm

USER $USER

EXPOSE 3000
```

### Stage breakdown

| Stage             | Purpose                                                                      |
| ----------------- | ---------------------------------------------------------------------------- |
| `deps`            | Install all dependencies including devDependencies needed for build          |
| `production-deps` | Strip devDependencies for a lean runtime layer                               |
| `builder`         | Run `npm run build` to produce the SSR bundle in `/build`                    |
| final             | Minimal runtime image — only production deps, build output, and start script |

### `app-start.sh`

The entrypoint script that starts the server:

```sh
#!/bin/sh -ex
/node_modules/.bin/react-router-serve ./build/server/index.js
```

### Build and run

```bash
# Build image (pass version as build arg)
docker build --build-arg APP_VERSION=1.0.0 -t my-app .

# Run container
docker run -p 3000:3000 \
  -e VITE_API_URL=https://api.example.com \
  my-app /app-start.sh
```

### Notes

- Base image: `node:25.5.0-alpine` — lightweight Alpine Linux
- App runs as a **non-root user** (`default`) for security
- `npm` is uninstalled from the final image to reduce attack surface
- Pass runtime env vars via `docker run -e` or a `.env` file — they must be baked in at build time if accessed via `import.meta.env`

---

## 6. Routing

Routing uses **React Router v7 file-based routing** (`@react-router/fs-routes`).

### Naming convention

| Pattern                          | Result                          |
| -------------------------------- | ------------------------------- |
| `routes/login.tsx`               | `/login`                        |
| `routes/payment._index.tsx`      | `/payment` (index of payment)   |
| `routes/payment.detail.tsx`      | `/payment/detail`               |
| `routes/customer.$id.tsx`        | `/customer/:id` (dynamic param) |
| `routes/setting.user._index.tsx` | `/setting/user`                 |

### Root layout (`app/root.tsx`)

- Exports `links` — preloads Google Fonts
- Exports `loader` — passes server-side ENV to the client via `window.ENV` (injected in `<head>`)
- Exports `Layout` — wraps **all** routes with providers (including `/login` and `/error`)
- Exports `App` — routing logic only; renders `<ClientOnly>` for protected routes, `<Outlet />` for public routes
- Exports `ErrorBoundary` — handles unhandled errors

**Critical pattern**: All providers must live in `Layout`, not inside the inner app component. `Layout` is called for every route in React Router v7, so any provider placed there is available to `/login`, `/error`, and all other routes. If providers are placed inside the inner app component (e.g. `PharmacyApp`), the login page will crash because it renders via `<Outlet />` outside that component tree.

```tsx
// Layout — wraps every route
export function Layout({ children }) {
  const config = useLoaderData<typeof loader>();
  return (
    <html>
      <head>
        {/* Inject server-side env so client config picks it up at runtime */}
        <script dangerouslySetInnerHTML={{ __html: `window.ENV = ${JSON.stringify(config?.ENV)}` }} />
      </head>
      <body suppressHydrationWarning>
        <ReduxProvider store={store}>
          <AlertProvider>
            <ToastProvider>
              <I18nextProvider i18n={i18n}>
                <SSEProvider>
                  <Auth>{children}</Auth>
                </SSEProvider>
              </I18nextProvider>
            </ToastProvider>
          </AlertProvider>
        </ReduxProvider>
      </body>
    </html>
  );
}

// App — routing logic only
export default function App() {
  const location = useLocation();
  const isPublic = location.pathname === "/login" || location.pathname === "/error";
  if (isPublic) return <Outlet />;
  return (
    <ClientOnly fallback={<div className="min-h-svh" />}>
      <Outlet />
    </ClientOnly>
  );
}
```

The inner app component (e.g. `PharmacyApp`) only holds UI structure (Sidebar, Navbar) — no providers.

### Built-in routes

| File                      | Path        | Purpose                                                    |
| ------------------------- | ----------- | ---------------------------------------------------------- |
| `routes/_index.tsx`       | `/`         | Home/index page                                            |
| `routes/login.tsx`        | `/login`    | Login page — redirects to Cognito OAuth, handles logout dispatch |
| `routes/error.tsx`        | `/error`    | Error display page — reads `message`, `details`, `stack` from query params |
| `routes/$.tsx`            | `/*`        | Catch-all — redirects unmatched paths to `/error` with 401/404 message |

#### `routes/login.tsx`

Rendered outside `ClientOnly` (public route). Reads `state.isLogout` from router state to dispatch Redux `logout()` on redirect-back from Cognito logout. Uses `useDispatch` — requires `ReduxProvider` to be in `Layout`.

```tsx
export default function Login() {
  const dispatch = useDispatch();
  const config   = useConfig();
  const { state } = useLocation();

  useEffect(() => {
    if (state?.isLogout) dispatch(logout());
  }, [state?.isLogout]);

  return (
    <Button onClick={() => { window.location.href = config.getCognitoLoginUrl(); }}>
      เข้าสู่ระบบ
    </Button>
  );
}
```

#### `routes/$.tsx`

Catch-all route for unmatched paths. Uses `useEffect` + `navigate` to redirect to `/error` — **never** access `window` directly during render (SSR unsafe).

```tsx
export default function CatchAll() {
  const location = useLocation();
  const navigate = useNavigate();

  useEffect(() => {
    if (location.pathname === "/401") {
      navigate('/error?message=401&details=Unauthorized', { replace: true });
    } else {
      navigate('/error?message=404&details=Page not found', { replace: true });
    }
  }, [location.pathname, navigate]);

  return null;
}
```

#### `routes/error.tsx`

Error display page at `/error`. Reads `message`, `details`, and `stack` from query params (written by `ErrorBoundary` or `$.tsx`). Must be a **route file** — if placed in `components/` there is no route registered for `/error` and `$.tsx` will redirect to itself in an infinite loop.

```tsx
export default function ErrorPage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const config   = useConfig();

  const message = searchParams.get('message');
  const details = searchParams.get('details');
  const stack   = searchParams.get('stack');

  return (
    <div>
      <p>{message}</p>
      <p>{details}</p>
      {stack && <pre>{stack}</pre>}
      <button onClick={() => navigate('/')}>Home</button>
      <p>{config.AppVersion}</p>
    </div>
  );
}
```

### Route loader pattern

```tsx
// routes/payment._index.tsx
export async function loader({ request }: Route.LoaderArgs) {
  // Server-side data fetching
  return { initialData };
}

export default function PaymentPage({ loaderData }: Route.ComponentProps) {
  // Client-side component
}
```

---

## 7. State Management (Redux)

### Store setup (`app/stores/index.ts`)

```ts
import { configureStore } from "@reduxjs/toolkit";
import authReducer from "./auth";

// Custom middleware: persists state to localStorage on every action
const localStorageMiddleware = (store) => (next) => (action) => {
  const result = next(action);
  const state = store.getState();
  localStorage.setItem(
    "app-state",
    JSON.stringify({
      ...state,
      auth: { ...state.auth, isAuthenticated: undefined }, // exclude sensitive flags
    }),
  );
  return result;
};

// Rehydrate from localStorage on init
const preloadedState = JSON.parse(localStorage.getItem("app-state") ?? "{}");

export const store = configureStore({
  reducer: { 
    //@ts-ignore
    auth: authReducer },
  preloadedState,
  //@ts-ignore 
  middleware: (getDefault) => getDefault().concat(localStorageMiddleware),
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
```

### Auth slice (`app/stores/auth.ts`)

```ts
import { createSlice, PayloadAction } from "@reduxjs/toolkit";
import { UserData } from "@/types";

const authSlice = createSlice({
  name: "auth",
  initialState: { user: null as UserData | null },
  reducers: {
    setUserInfo: (state, action: PayloadAction<UserData>) => {
      state.user = action.payload;
    },
    logout: (state) => {
      state.user = null;
    },
  },
});

export const { setUserInfo, logout } = authSlice.actions;
export default authSlice.reducer;
```

### Usage hook (`app/hooks/useAuthStore.ts`)

```ts
import { useSelector, useDispatch } from "react-redux";
import { RootState } from "@/stores";

export function useAuthStore() {
  const dispatch = useDispatch();
  const user = useSelector((state: RootState) => state.auth.user);
  return { user, dispatch };
}
```

---

## 8. API Layer

### Custom fetch hook (`app/hooks/useNativeFetch.ts`)

All API calls go through this hook. It handles:

- **Timeout** — default 15 seconds
- **Retry** — on network error or 5xx/429 status
- **AbortSignal** — request cancellation
- **Response parsing** — auto-detects JSON, Blob, or text
- **Error typing** — custom `ApiError` class

```ts
const fetch = useNativeFetch();

// GET
const res = await fetch.get<ResponseType>("/endpoint");

// POST
const res = await fetch.post<ResponseType>("/endpoint", bodyPayload);

// PUT
const res = await fetch.put<ResponseType>("/endpoint", bodyPayload);

// DELETE
const res = await fetch.del<ResponseType>("/endpoint");

// Cancellable
const { promise, cancel } = fetch.cancellable<ResponseType>("/endpoint");
// call cancel() to abort
```

**Response type:**

```ts
type ApiResponse<T> = {
  success: boolean;
  data: T;
  message?: string;
  pagination?: { page: number; perPage: number; total: number };
};
```

### API modules (`app/api/`)

Group API calls by domain in separate files:

```ts
// app/api/payment.ts
import { useNativeFetch } from "@/hooks/useNativeFetch";
import { PaymentSearchPayloadType } from "@/types";

export function usePaymentApi() {
  const fetch = useNativeFetch();

  return {
    fetchPayments: (payload: PaymentSearchPayloadType) =>
      fetch.post<PaymentListResponse>("/payment/search", payload),

    fetchPaymentById: (id: string) =>
      fetch.get<PaymentDetail>(`/payment/${id}`),
  };
}
```

### Standard payload shape

```ts
type SearchPayloadType = {
  page: number;
  perPage: number;
  sortBy: string;
  sortOrder: "asc" | "desc";
  searchText?: string;
  // ...domain-specific filters
};
```

---

## 9. Internationalization (i18n)

### Setup (`app/i18n/index.ts`)

```ts
import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import LanguageDetector from "i18next-browser-languagedetector";
import en from "./locales/en.json";
import th from "./locales/th.json";

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources: { en: { translation: en }, th: { translation: th } },
    fallbackLng: "th",
    detection: { order: ["localStorage"], lookupLocalStorage: "i18nextLng" },
    react: { useSuspense: false },
  });
```

### Translation files (`app/i18n/locales/`)

Organize keys by feature namespace:

```json
{
  "common": {
    "save": "Save",
    "cancel": "Cancel",
    "error": { "required": "This field is required" }
  },
  "payment": {
    "title": "Payment",
    "column": { "code": "Code", "status": "Status" }
  }
}
```

### Custom hook (`app/hooks/useI18n.ts`)

```ts
const {
  t,
  changeLanguage,
  formatDate,
  formatCurrency,
  formatNumber,
  isLanguage,
} = useI18n();

t("payment.title"); // → "Payment"
formatDate(new Date(), "DD/MM/YYYY"); // locale-aware
formatCurrency(1000); // → "1,000.00"
changeLanguage("en"); // switch language
isLanguage("th"); // → true/false
```

---

## 10. Form Handling

### Pattern: React Hook Form + Zod

```tsx
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";

// 1. Define schema
const schema = z.object({
  name: z.string().min(1, "Required"),
  amount: z.number().min(0),
});
type FormType = z.infer<typeof schema>;

// 2. Setup form
const { control, handleSubmit, watch, setValue, setError, formState: { errors } } =
  useForm<FormType>({
    resolver: zodResolver(schema),
    defaultValues: { name: "", amount: 0 },
    mode: "onSubmit",
  });

// 3. Controlled input
<Controller
  name="name"
  control={control}
  render={({ field: { value, onChange }, fieldState: { error } }) => (
    <Input value={value} onChange={onChange} error={error?.message} />
  )}
/>

// 4. Submit
<form onSubmit={handleSubmit(async (data) => {
  const res = await api.save(data);
  if (!res.success) setError("name", { message: res.message });
})}>
```

---

## 11. Authentication & Authorization

### Authentication flow

1. User visits any route → `Auth` component checks session
2. If no session → redirect to `/login`
3. Login page → redirect to AWS Cognito OAuth page
4. Cognito → redirects to backend callback `/api/auth/cb`
5. Backend sets HTTP-only cookie with access token
6. Backend redirects to app with user data
7. App stores user in Redux → persisted to localStorage

### Permission hook (`app/hooks/usePermission.ts`)

```ts
const { read, create, update, delete: del } = usePermission("payment");

if (!read) return <Navigate to="/unauthorized" />;
```

Permissions are role-based: `admin`, `pharmacist`, `RAPD`. Each role has a set of resource permissions stored on the user object.

### Navigation menus (`app/config/navigationMenus.ts`)

```ts
export function getMenuByRole(
  role: string,
  t: TFunction,
  pharmacistId?: string,
) {
  // Returns filtered menu items based on role
}
```

---

## 12. Styling

### TailwindCSS v4 with custom theme (`tailwind.config.ts`)

```ts
import type { Config } from "tailwindcss";

export default {
  content: ["./app/**/*.{js,ts,jsx,tsx}", "./index.html"],
  theme: {
    extend: {
      colors: {
        primary: {
          50: "#F2FBF9",
          100: "#D2F5F0",
          200: "#A5EAE1",
          300: "#70D8CD",
          400: "#47C0B7",
          500: "#29A39B",
          600: "#1E837F",
          700: "#1C6967",
          800: "#1B5453",
          900: "#1B4645",
          950: "#0A2729",
        },
        secondary: {
          50: "#FDF2F8",
          100: "#FCE7F3",
          200: "#FBCFE9",
          300: "#F9A8D6",
          400: "#F472B9",
          500: "#EA3291",
          600: "#EB2992",
          700: "#BE1861",
          800: "#9D1750",
          900: "#831845",
          950: "#500726",
        },
        gray: {
          50: "#F7F8F7",
          100: "#EEF0F0",
          200: "#D9DEDD",
          300: "#B3BDBB",
          400: "#919F9C",
          500: "#738480",
          600: "#5D6C69",
          700: "#4C5856",
          800: "#414B4A",
          900: "#394140",
          950: "#262B2A",
        },
        info: {
          50: "#FDF2F8",
          100: "#EFF8FF",
          200: "#DEF1FF",
          300: "#00AAFF",
          400: "#0085D4",
        },
        warning: {
          50: "#FEFEEA",
          100: "#FFFDC2",
          200: "#FEC203",
          300: "#CE8D00",
        },
        success: {
          50: "#EEF8F4",
          100: "#D0FBE3",
          200: "#009460",
          300: "#00BC54",
        },
        error: {
          50: "#FEF2F2",
          100: "#FEE2E2",
          200: "#DF2526",
          300: "#BC191C",
        },
        background: {
          50: "#F6F6F6", // BG1 — light gray page background
          100: "#FFFFFF", // BG2 — white card/panel background
        },
      },
      fontFamily: {
        sarabun: ["Sarabun", "sans-serif"],
        kanit: ["Kanit", "sans-serif"],
      },
      spacing: {
        "18": "4.5rem", // 72px — used for collapsed sidebar width
      },
    },
  },
} satisfies Config;
```

### Patterns

- Use `clsx` for conditional class names: `clsx("base-class", condition && "extra-class")`
- Use Headless UI for accessible primitives (Dialog, Menu, Listbox, etc.)
- Use Heroicons for icons: `import { XMarkIcon } from "@heroicons/react/24/solid"`
- Use custom SVGs via SVGR: `import Logo from "@/assets/logo.svg?react"`

### Button variants example

```tsx
<Button variant="solid" color="primary">Save</Button>
<Button variant="outline" color="secondary">Cancel</Button>
<Button variant="plain" color="error">Delete</Button>
```

---

## 13. Custom Hooks

| Hook                      | Purpose                                                 |
| ------------------------- | ------------------------------------------------------- |
| `useNativeFetch()`        | API fetch wrapper with timeout, retry, abort            |
| `useI18n()`               | Translation + locale-aware formatting                   |
| `useAuthStore()`          | Access Redux auth state and dispatch                    |
| `useConfig()`             | Read environment variables                              |
| `useLookups()`            | Fetch paginated dropdown options with debounced search  |
| `usePermission(resource)` | Returns `{ read, create, update, delete }` for resource |
| `useTableSort()`          | Manages `{ sortBy, sortOrder }` state for tables        |
| `useNavigation()`         | Navigate with query param helpers                       |
| `useQueryParams()`        | Parse URL query params to typed object                  |
| `useDateTime()`           | Live clock display (updates every second)               |
| `useMaskedInput()`        | Format input as phone, number, etc. while typing        |

---

## 14. Component Patterns

### UI Primitive (e.g., `app/components/input.tsx`)

```tsx
import { forwardRef } from "react";
import clsx from "clsx";

type InputProps = React.InputHTMLAttributes<HTMLInputElement> & {
  error?: string;
  label?: string;
};

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ error, label, className, ...props }, ref) => (
    <div>
      {label && <label>{label}</label>}
      <input
        ref={ref}
        className={clsx(
          "base-input-classes",
          error && "error-classes",
          className,
        )}
        {...props}
      />
      {error && <p className="text-error-500 text-sm">{error}</p>}
    </div>
  ),
);
```

### Feature Component (page-level)

```tsx
// routes/example._index.tsx
export default function ExamplePage() {
  const { t } = useI18n();
  const api = useExampleApi();
  const { read, create } = usePermission("example");

  const [data, setData] = useState<ExampleType[]>([]);
  const { sortBy, sortOrder, handleSort } = useTableSort();

  useEffect(() => {
    api.fetchAll({ page: 1, perPage: 20, sortBy, sortOrder }).then((res) => {
      if (res.success) setData(res.data);
    });
  }, [sortBy, sortOrder]);

  if (!read) return <Navigate to="/" replace />;

  return (
    <div>
      <h1>{t("example.title")}</h1>
      <Table data={data} onSort={handleSort} />
    </div>
  );
}
```

### Alert / Toast pattern

```tsx
import { useAlert } from "@/provider/alert";
import { useToast } from "@/provider/toast";

const { confirm, alert } = useAlert();
const { showToast } = useToast();

// Confirm dialog before destructive action
const confirmed = await confirm({ title: t("common.confirm"), message: "..." });
if (!confirmed) return;

// Toast notification
showToast({ type: "success", message: t("common.saved") });
```

---

## 15. Real-time (SSE)

Server-Sent Events are used for real-time status updates.

### Provider (`app/provider/sse.tsx`)

```tsx
// Wraps the app, connects to /api/events
// On event → dispatches to Redux or shows toast
<SSEProvider>{children}</SSEProvider>
```

### Usage

Components that need real-time updates just need to be inside `SSEProvider` (which is in root). They can read the updated Redux state normally. The SSE provider handles the connection, reconnection, and toast notifications automatically.

---

## 16. Testing

### Setup

- **Jest** with `ts-jest` preset
- **jsdom** environment
- Setup file: `jest.setup.js` (imports `@testing-library/jest-dom`)
- Mocks in `__mocks__/` (e.g., mock for SVG imports)

### `jest.config.mjs`

```js
export default {
  testEnvironment: "jsdom",
  setupFilesAfterEnv: ["<rootDir>/jest.setup.js"],
  coverageProvider: "v8",
  moduleNameMapper: {
    // SVG ?react imports — must come before the general @/ rule
    "^@/(.*)\\.svg\\?react$": "<rootDir>/__mocks__/fileMock.js",
    // Path alias
    "^@/(.*)$": "<rootDir>/app/$1",
    // CSS modules
    "\\.(css|less|scss|sass)$": "identity-obj-proxy",
    // Static assets
    "\\.(jpg|jpeg|png|gif|svg|ttf|woff|woff2|mp4|webm|wav|mp3)$":
      "<rootDir>/__mocks__/fileMock.js",
  },
  transform: {
    "^.+\\.(ts|tsx|js|jsx)$": "babel-jest",
  },
  testMatch: [
    "<rootDir>/app/**/__tests__/**/*.(ts|tsx|js)",
    "<rootDir>/app/**/*.(test|spec).(ts|tsx|js)",
  ],
  collectCoverageFrom: [
    "app/**/*.{ts,tsx}",
    "!app/**/*.d.ts",
    "!app/**/*.index.ts",
    "!app/**/*.config.{ts,tsx}",
  ],
  coverageDirectory: "coverage",
  coverageReporters: ["text", "lcov", "html"],
  testPathIgnorePatterns: ["/node_modules/", "/dist/"],
  moduleFileExtensions: ["ts", "tsx", "js", "jsx", "json"],
  extensionsToTreatAsEsm: [".ts", ".tsx"],
};
```

### `jest.setup.js`

```js
require("@testing-library/jest-dom");
const { TextEncoder, TextDecoder } = require("util");

// Polyfill TextEncoder/TextDecoder
global.TextEncoder = TextEncoder;
global.TextDecoder = TextDecoder;

// Mock import.meta.env (transformed by babel-plugin-import-meta-transform)
global.import = global.import || {};
global.import.meta = global.import.meta || {};
global.import.meta.env = {
  VITE_IS_DEBUG: "true",
  VITE_API_URL: "https://api.example.com",
  VITE_COGNITO_AUTH_CLIENT_ID: "test-client-id",
  VITE_COGNITO_AUTH_REDIRECT_URL: "https://example.com/callback",
  VITE_COGNITO_ENDPOINT: "https://cognito.example.com",
  VITE_COGNITO_LOGOUT_URL: "https://example.com/logout",
  VITE_APP_VERSION: "v0.0.0-test",
  DEV: true,
};

// Mock browser APIs not available in jsdom
global.ResizeObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}));

global.IntersectionObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}));

Object.defineProperty(window, "matchMedia", {
  writable: true,
  value: jest.fn().mockImplementation((query) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: jest.fn(),
    removeListener: jest.fn(),
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
    dispatchEvent: jest.fn(),
  })),
});

window.scrollTo = jest.fn();

// Suppress known noisy warnings during tests
const originalError = console.error;
const originalWarn = console.warn;
beforeAll(() => {
  console.error = (...args) => {
    if (
      typeof args[0] === "string" &&
      (args[0].includes("Warning: ReactDOM.render is deprecated") ||
        args[0].includes("not wrapped in act") ||
        args[0].includes("hydration error"))
    )
      return;
    originalError.call(console, ...args);
  };
  console.warn = (...args) => {
    if (
      typeof args[0] === "string" &&
      (args[0].includes("Warning:") || args[0].includes("useLayoutEffect"))
    )
      return;
    originalWarn.call(console, ...args);
  };
});
afterAll(() => {
  console.error = originalError;
  console.warn = originalWarn;
});
```

### `__mocks__/fileMock.js`

Stub for all static assets (SVG, images, fonts) imported in components:

```js
module.exports = "test-file-stub";
```

### Writing tests

```tsx
// app/components/__tests__/button.test.tsx
import { render, screen } from "@testing-library/react";
import { Button } from "@/components/button";

test("renders button with label", () => {
  render(<Button>Click me</Button>);
  expect(screen.getByText("Click me")).toBeInTheDocument();
});
```

---

## 17. Key Conventions

### File naming

- React components: `PascalCase.tsx`
- Hooks: `camelCase.ts` with `use` prefix
- Utilities: `camelCase.ts`
- API modules: `kebab-case.ts`
- Route files: `routename._index.tsx` or `routename.subpage.tsx`

### Type conventions (`app/types.ts`)

```ts
// API response wrapper
type ApiResponse<T> = {
  success: boolean;
  data: T;
  message?: string;
  pagination?: PaginationType;
};

// User data from auth
type UserData = {
  id: string;
  email: string;
  fullName: string;
  role: "admin" | "pharmacist" | "RAPD";
  permissions: Record<
    string,
    { read: boolean; create: boolean; update: boolean; delete: boolean }
  >;
};
```

### Constants (`app/constants.tsx`)

- Table column widths as named constants (`COL_WIDTH_SM`, `COL_WIDTH_MD`, etc.)
- Status enums and their display labels
- Per-page options for pagination (`PER_PAGE_OPTIONS`)
- Status badge color mapping

### Bilingual display pattern

For fields that have both Thai and English values (e.g., names):

```ts
// utils/common.ts
export function getDisplayValue(
  item: { nameTh?: string; nameEn?: string },
  lang: string,
) {
  return lang === "th" ? item.nameTh : item.nameEn;
}

// Usage
const { i18n } = useI18n();
getDisplayValue(item, i18n.language);
```

### Debug logging

```ts
import { logger } from "@/utils/common";

logger("PaymentPage", "Fetching data", payload); // only logs when VITE_IS_DEBUG=true
```

### Date formatting

```ts
import { formatDate, formatDateTime } from "@/utils/date";

formatDate(date); // "DD/MM/YYYY" (Thai year +543 if locale is th)
formatDateTime(date); // "DD/MM/YYYY HH:mm:ss"
```

---

## Quick Start Checklist for a New Project

### Config files to copy / create

- [ ] `package.json` — copy dependencies and devDependencies, update name
- [ ] `vite.config.ts` — plugins: `tailwindcss`, `reactRouter`, `tsconfigPaths`, `svgr`; port 3000
- [ ] `react-router.config.ts` — set `ssr: true`
- [ ] `tailwind.config.ts` — content glob, custom colors, fonts, spacing
- [ ] `postcss.config.js` — `@tailwindcss/postcss` plugin
- [ ] `tsconfig.json` — target ES2022, `module: ES2022`, `moduleResolution: bundler`, `paths` alias `@/*`, `noEmit: true`, `strict: false`, `types: [node, vite/client, jest]`, `rootDirs` includes `.react-router/types`
- [ ] `vite-env.d.ts` — `/// <reference types="vite/client" />` + `*.svg?react` module declaration
- [ ] `babel.config.cjs` — presets: env, typescript, react (Jest only)
- [ ] `babel-plugin-import-meta-transform.cjs` — `import.meta` → `global.import.meta` for Jest
- [ ] `jest.config.mjs` — jsdom env, `setupFilesAfterEnv`, moduleNameMapper, transform, testMatch
- [ ] `jest.setup.js` — jest-dom, polyfills, browser API mocks, console suppression
- [ ] `__mocks__/fileMock.js` — `module.exports = "test-file-stub"`
- [ ] `.env` — all `VITE_*` variables

### Source files to create

- [ ] `app/routes.ts` — file-based route config using `flatRoutes()` from `@react-router/fs-routes`
- [ ] `app/routes/_index.tsx` — root index route (`/`)
- [ ] `app/routes/login.tsx` — login page: redirects to Cognito OAuth, dispatches `logout()` on return from Cognito logout
- [ ] `app/routes/error.tsx` — error display page at `/error`: reads `message`, `details`, `stack` from query params; **must be a route** (not a component) or `$.tsx` creates an infinite redirect loop
- [ ] `app/routes/$.tsx` — catch-all: redirects 401/404 to `/error` via `useEffect`+`navigate` (never `window.location` during render — SSR unsafe)
- [ ] `app/config.ts` — reads env vars, builds Cognito URLs, handles `window.ENV` for SSR
- [ ] `app/types.ts` — `ApiResponse<T>`, `UserData`, `PaginationType`
- [ ] `app/constants.tsx` — column widths, status enums, per-page options
- [ ] `app/field-lengths.ts` — max char lengths per field
- [ ] `app/app.css` — global CSS (Tailwind `@import`)
- [ ] `app/root.tsx` — `Layout` holds all providers (Redux → Alert → Toast → I18n → SSE → Auth wrapping `{children}`); `App` is routing logic only; `window.ENV` injected in `<head>` via `useLoaderData`
- [ ] `app/stores/index.ts` — Redux store with SSR-safe localStorage middleware
- [ ] `app/stores/auth.ts` — auth slice (setUserInfo, logout)
- [ ] `app/i18n/index.ts` — i18n init (LanguageDetector, resources, fallbackLng)
- [ ] `app/i18n/locales/en.json` + `th.json` — translation keys by feature namespace
- [ ] `app/hooks/isClient.ts` — SSR-safe browser detection (`typeof window !== "undefined"`)
- [ ] `app/hooks/useNativeFetch.ts` — fetch wrapper with timeout, retry, abort
- [ ] `app/hooks/useI18n.ts` — translation + locale-aware formatting
- [ ] `app/hooks/useAuthStore.ts` — Redux auth selector
- [ ] `app/hooks/usePermission.ts` — resource-based RBAC
- [ ] `app/hooks/useTableSort.ts` — manages `{ sortBy, sortOrder }` state
- [ ] `app/hooks/useNavigation.ts` — navigate with query param helpers
- [ ] `app/hooks/useQueryParams.ts` — parse URL query params to typed object
- [ ] `app/hooks/useDateTime.ts` — live clock (updates every second)
- [ ] `app/hooks/useLookups.ts` — paginated dropdown options with debounced search
- [ ] `app/hooks/useMaskedInput.ts` — format input as phone, number, decimal while typing
- [ ] `app/provider/alert.tsx` + `toast.tsx` — global dialog/toast context
- [ ] `app/provider/sse.tsx` — Server-Sent Events provider
- [ ] `app/components/auth.tsx` — auth guard, redirects unauthenticated users to `/login`
- [ ] `app/components/` — UI primitives: Button, Input, Dialog, Table, Badge, Checkbox
- [ ] `app/config/navigationMenus.ts` — role-based menu items
- [ ] `app/utils/common.ts` — `getDisplayValue`, `logger`
- [ ] `app/utils/date.ts` — `formatDate`, `formatDateTime` with Buddhist Era support
- [ ] `app-start.sh` — `react-router-serve ./build/server/index.js` (for Docker)
- [ ] `Dockerfile` — 4-stage build: deps → production-deps → builder → runtime
