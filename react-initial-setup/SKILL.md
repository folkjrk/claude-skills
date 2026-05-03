---
name: react-initial-setup
description: A comprehensive guideline for bootstrapping production-ready React projects with TypeScript, TanStack Query v5, custom Toast provider, and Feature-based architecture with generic CRUD utilities.
user-invocable: true
---

# React Initial Setup Guide

**Version:** 2.0
**Target Audience:** Full-stack React developers starting new projects
**Tech Stack:** React 18+, TypeScript, TanStack Query v5, native fetch wrapper, custom toast provider

---

## Before Starting a New Project

1. **Check latest package versions** — always verify the newest stable releases before bootstrapping.
2. **Scan for CVEs** — run `npm audit`, review GitHub Advisory warnings, or use a vulnerability scanner before install.
3. **Lock versions after approval** — pin or lock dependency versions once CVE-safe versions are confirmed.
4. **Prefer minimal dependencies** — avoid adding a package unless it solves a real need.

---

## Core Principles

1. **Type-First Development** — Define types/schemas BEFORE implementation
2. **Feature-Based Architecture** — Organize code by feature, not by file type
3. **Data Fetching Abstraction** — Use TanStack Query for server state, not raw fetch
4. **User Feedback** — Toast notifications for every async operation (success/error)
5. **Separation of Concerns** — API layer, business logic, and UI are strictly separated
6. **Generic-First Utilities** — Shared infrastructure (CRUD service, hooks) must be generic and reusable

---

## Project Structure

```text
src/
├── api/                          # 🔌 API CLIENT & REQUEST SETUP
│   ├── client.ts                 # Fetch wrapper: timeout, params, response parsing
│   ├── api.config.ts             # Single source of truth: base URL, timeout, endpoints
│   ├── create-crud-service.ts    # Generic CRUD service factory
│   └── query-client.ts           # TanStack Query client configuration
│
├── types/                        # 📝 GLOBAL TYPES & INTERFACES
│   ├── api.types.ts              # ApiResponse<T>, ErrorResponse, PaginatedResponse<T>
│   ├── common.types.ts           # Shared utility types
│   └── index.ts                  # Re-export all types
│
├── features/                     # 🎯 FEATURE MODULES
│   ├── auth/
│   │   ├── index.ts              # 🚪 Public API (barrel file)
│   │   ├── auth.schema.ts        # Zod schemas + inferred types
│   │   ├── auth.types.ts         # Feature-specific interfaces (NOT form types)
│   │   ├── auth.service.ts       # API calls (login, logout, refresh)
│   │   ├── auth.hooks.ts         # useLogin, useLogout, useCurrentUser
│   │   ├── auth.utils.ts         # Pure functions (token storage)
│   │   ├── components/
│   │   │   ├── LoginForm.tsx
│   │   │   ├── RegisterForm.tsx
│   │   │   └── AuthGuard.tsx
│   │   └── __tests__/
│   │
│   └── [other-features]/         # Same structure as auth/
│
├── shared/                       # 🤝 SHARED UTILITIES & COMPONENTS
│   ├── components/
│   │   ├── Button.tsx
│   │   ├── Modal.tsx
│   │   ├── Input.tsx
│   │   └── LoadingSpinner.tsx
│   ├── hooks/
│   │   ├── useAsync.ts
│   │   └── useDebounce.ts
│   ├── utils/
│   │   ├── date.utils.ts
│   │   └── formatter.utils.ts
│   └── constants/
│       ├── app.constants.ts
│       └── errors.constants.ts
│
├── hooks/                        # 🪝 APP-LEVEL HOOKS
│   ├── useQueryWithToast.ts      # TanStack Query v5 + toast (fixed for v5 API)
│   ├── useMutationWithToast.ts   # TanStack Mutation + toast + context merging
│   └── useToast.ts               # Re-export from ToastContext
│
├── context/                      # 📦 GLOBAL STATE
│   ├── ToastContext.tsx          # Toast provider + useToast with typed toast API
│   └── AppProvider.tsx           # Root provider wrapper
│
├── pages/                        # 📄 PAGE COMPONENTS
│   ├── HomePage.tsx
│   ├── LoginPage.tsx
│   ├── DashboardPage.tsx
│   └── NotFoundPage.tsx
│
├── App.tsx
├── main.tsx
└── index.css
```

---

## Step 1: Setup Types First

### 1.1 Global API Types (`src/types/api.types.ts`)

```typescript
// All API responses share this envelope — services always use ApiResponse<T>
export type ApiResponse<T> = {
  success: boolean;
  data: T;
  message: string;
  timestamp: string;
};

export type ErrorResponse = {
  success: false;
  message: string;
  errors?: Record<string, string[]>;
  code: string;
};

export type PaginationMeta = {
  page: number;
  limit: number;
  total: number;
  pages: number;
};

export type PaginatedResponse<T> = {
  data: T[];
  meta: PaginationMeta;
};

// Auth DTOs
export type LoginRequest = {
  email: string;
  password: string;
};

export type LoginResponse = {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    email: string;
    name: string;
    role: 'admin' | 'user' | 'guest';
  };
};

export type RefreshTokenResponse = {
  accessToken: string;
};
```

### 1.2 Common Types (`src/types/common.types.ts`)

```typescript
export type QueryParams = Record<string, string | number | boolean | null | undefined>;

export type ID = string | number;

export type Nullable<T> = T | null;
```

### 1.3 Feature-Level Types (`src/features/auth/auth.types.ts`)

```typescript
// Feature-specific interfaces — NOT form validation types (those live in *.schema.ts)
export type AuthUser = {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'user' | 'guest';
  avatar?: string;
  createdAt: Date;
};

export type AuthState = {
  user: AuthUser | null;
  isAuthenticated: boolean;
  isLoading: boolean;
};
```

### 1.4 Zod Schemas (`src/features/auth/auth.schema.ts`)

```typescript
import { z } from 'zod';

export const loginSchema = z
  .object({
    email: z.string().email('Invalid email address').max(255),
    password: z.string().min(6, 'Password must be at least 6 characters').max(255),
    rememberMe: z.boolean().optional().default(false),
  })
  .strict();

// Infer types from Zod — never define form types manually in auth.types.ts
export type LoginFormValues = z.infer<typeof loginSchema>;

export const registerSchema = z
  .object({
    email: z.string().email('Invalid email').max(255),
    password: z.string().min(8, 'At least 8 characters'),
    confirmPassword: z.string(),
    name: z.string().min(2).max(100),
  })
  .strict()
  .refine((d) => d.password === d.confirmPassword, {
    message: 'Passwords do not match',
    path: ['confirmPassword'],
  });

export type RegisterFormValues = z.infer<typeof registerSchema>;
```

---

## Step 2: API Client & Configuration

### 2.1 API Configuration — Single Source of Truth (`src/api/api.config.ts`)

```typescript
// All timeouts, base URL, and endpoints live here — never define them elsewhere
export const API_CONFIG = {
  BASE_URL: import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000/api',
  TIMEOUT_MS: 15_000,
  RETRY_COUNT: 3,
  RETRY_DELAY_MS: 1_000,

  ENDPOINTS: {
    AUTH: {
      LOGIN: '/auth/login',
      LOGOUT: '/auth/logout',
      REFRESH: '/auth/refresh',
      REGISTER: '/auth/register',
      ME: '/auth/me',
    },
    DASHBOARD: {
      STATS: '/dashboard/stats',
      USERS: '/dashboard/users',
    },
  },
} as const;
```

### 2.2 Fetch Wrapper (`src/api/client.ts`)

```typescript
import { API_CONFIG } from './api.config';
import type { ApiResponse, QueryParams } from '@/types';

export class ApiError extends Error {
  constructor(
    public status: number,
    public apiMessage: string,
    public validationErrors?: Record<string, string[]>,
  ) {
    super(apiMessage || `HTTP ${status}`);
    this.name = 'ApiError';
  }
}

// Unwrap ApiResponse<T> envelope and throw if success=false
export function unwrapResponse<T>(response: ApiResponse<T>): T {
  if (!response.success) {
    throw new ApiError(0, response.message);
  }
  return response.data;
}

function buildUrl(path: string, params?: QueryParams): string {
  const base = `${API_CONFIG.BASE_URL}${path}`;
  if (!params) return base;
  const qs = new URLSearchParams(
    Object.entries(params)
      .filter(([, v]) => v != null)
      .map(([k, v]) => [k, String(v)]),
  ).toString();
  return qs ? `${base}?${qs}` : base;
}

async function parseResponse<T>(response: Response): Promise<T> {
  const contentType = response.headers.get('content-type') ?? '';
  if (contentType.includes('application/json')) return response.json();
  if (contentType.includes('application/') || contentType.includes('octet-stream')) {
    return response.blob() as Promise<unknown> as Promise<T>;
  }
  return response.text() as Promise<unknown> as Promise<T>;
}

type RequestOptions = {
  params?: QueryParams;
  signal?: AbortSignal;
};

async function request<T>(
  path: string,
  init: RequestInit,
  options?: RequestOptions,
): Promise<T> {
  const timeoutSignal = AbortSignal.timeout(API_CONFIG.TIMEOUT_MS);
  const signals = [timeoutSignal];
  if (options?.signal) signals.push(options.signal);
  const combinedSignal = signals.length > 1 ? AbortSignal.any(signals) : timeoutSignal;

  const isFormData = init.body instanceof FormData;
  const response = await fetch(buildUrl(path, options?.params), {
    ...init,
    headers: isFormData
      ? init.headers
      : { 'Content-Type': 'application/json', ...(init.headers ?? {}) },
    credentials: 'include',
    signal: combinedSignal,
  });

  if (!response.ok) {
    const body = await response.json().catch(() => null);
    throw new ApiError(response.status, body?.message ?? response.statusText, body?.errors);
  }

  return parseResponse<T>(response);
}

export const apiClient = {
  get: <T>(path: string, options?: RequestOptions) =>
    request<T>(path, { method: 'GET' }, options),

  post: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>(path, { method: 'POST', body: JSON.stringify(body) }, options),

  put: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>(path, { method: 'PUT', body: JSON.stringify(body) }, options),

  patch: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>(path, { method: 'PATCH', body: JSON.stringify(body) }, options),

  delete: <T>(path: string, options?: RequestOptions) =>
    request<T>(path, { method: 'DELETE' }, options),

  postFormData: <T>(path: string, formData: FormData, options?: RequestOptions) =>
    request<T>(path, { method: 'POST', body: formData }, options),
};
```

### 2.3 Generic CRUD Service Factory (`src/api/create-crud-service.ts`)

```typescript
import { apiClient, unwrapResponse } from './client';
import type { ApiResponse, PaginatedResponse, QueryParams, ID } from '@/types';

/**
 * Creates a fully-typed CRUD service for any entity.
 *
 * Usage:
 *   export const productService = createCrudService<Product, CreateProductDTO>('/products');
 *   const products = await productService.getAll({ page: 1, limit: 20 });
 */
export function createCrudService<
  TEntity extends { id: ID },
  TCreate = Omit<TEntity, 'id'>,
  TUpdate = Partial<TCreate>,
>(basePath: string) {
  return {
    getAll: async (params?: QueryParams): Promise<TEntity[]> => {
      const res = await apiClient.get<ApiResponse<TEntity[]>>(basePath, { params });
      return unwrapResponse(res);
    },

    getPaginated: async (params?: QueryParams): Promise<PaginatedResponse<TEntity>> => {
      const res = await apiClient.get<ApiResponse<PaginatedResponse<TEntity>>>(basePath, {
        params,
      });
      return unwrapResponse(res);
    },

    getById: async (id: ID): Promise<TEntity> => {
      const res = await apiClient.get<ApiResponse<TEntity>>(`${basePath}/${id}`);
      return unwrapResponse(res);
    },

    create: async (data: TCreate): Promise<TEntity> => {
      const res = await apiClient.post<ApiResponse<TEntity>>(basePath, data);
      return unwrapResponse(res);
    },

    update: async (id: ID, data: TUpdate): Promise<TEntity> => {
      const res = await apiClient.put<ApiResponse<TEntity>>(`${basePath}/${id}`, data);
      return unwrapResponse(res);
    },

    patch: async (id: ID, data: Partial<TUpdate>): Promise<TEntity> => {
      const res = await apiClient.patch<ApiResponse<TEntity>>(`${basePath}/${id}`, data);
      return unwrapResponse(res);
    },

    remove: async (id: ID): Promise<void> => {
      await apiClient.delete<void>(`${basePath}/${id}`);
    },
  };
}
```

### 2.4 TanStack Query Client (`src/api/query-client.ts`)

```typescript
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,
      retry: 2,
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 0,
    },
  },
});
```

---

## Step 3: Service Layer

### 3.1 Auth Service (`src/features/auth/auth.service.ts`)

```typescript
import { apiClient, unwrapResponse } from '@/api/client';
import { API_CONFIG } from '@/api/api.config';
import type { ApiResponse, LoginRequest, LoginResponse, RefreshTokenResponse } from '@/types';

// All API calls live here — always use ApiResponse<T> and unwrapResponse
export const authService = {
  async login(credentials: LoginRequest): Promise<LoginResponse> {
    const res = await apiClient.post<ApiResponse<LoginResponse>>(
      API_CONFIG.ENDPOINTS.AUTH.LOGIN,
      credentials,
    );
    return unwrapResponse(res);
  },

  async register(data: {
    email: string;
    password: string;
    name: string;
  }): Promise<LoginResponse> {
    const res = await apiClient.post<ApiResponse<LoginResponse>>(
      API_CONFIG.ENDPOINTS.AUTH.REGISTER,
      data,
    );
    return unwrapResponse(res);
  },

  async logout(): Promise<void> {
    await apiClient.post(API_CONFIG.ENDPOINTS.AUTH.LOGOUT);
    authService.clearTokens();
  },

  async refreshToken(refreshToken: string): Promise<RefreshTokenResponse> {
    const res = await apiClient.post<ApiResponse<RefreshTokenResponse>>(
      API_CONFIG.ENDPOINTS.AUTH.REFRESH,
      { refreshToken },
    );
    return unwrapResponse(res);
  },

  async getMe(): Promise<LoginResponse['user']> {
    const res = await apiClient.get<ApiResponse<LoginResponse['user']>>(
      API_CONFIG.ENDPOINTS.AUTH.ME,
    );
    return unwrapResponse(res);
  },

  saveTokens(accessToken: string, refreshToken: string) {
    localStorage.setItem('accessToken', accessToken);
    localStorage.setItem('refreshToken', refreshToken);
  },

  clearTokens() {
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
  },

  getAccessToken(): string | null {
    return localStorage.getItem('accessToken');
  },
};
```

---

## Step 4: Toast Provider

### 4.1 Toast Context (`src/context/ToastContext.tsx`)

```typescript
import {
  createContext,
  useCallback,
  useContext,
  useState,
  type ReactNode,
} from 'react';

type ToastType = 'success' | 'error' | 'warning' | 'info' | 'loading';

type Toast = {
  id: string;
  type: ToastType;
  message: string;
  detail?: string;
};

type ToastAPI = {
  success: (message: string, detail?: string) => string;
  error: (message: string, detail?: string) => string;
  warning: (message: string, detail?: string) => string;
  info: (message: string, detail?: string) => string;
  loading: (message: string) => string;
  dismiss: (id: string) => void;
};

type ToastContextValue = { toast: ToastAPI };

const ToastContext = createContext<ToastContextValue | null>(null);

const AUTO_DISMISS_MS = 4_000;

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const dismiss = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const show = useCallback(
    (type: ToastType, message: string, detail?: string): string => {
      const id = crypto.randomUUID();
      setToasts((prev) => [...prev, { id, type, message, detail }]);
      if (type !== 'loading') {
        setTimeout(() => dismiss(id), AUTO_DISMISS_MS);
      }
      return id;
    },
    [dismiss],
  );

  const toast: ToastAPI = {
    success: (msg, detail) => show('success', msg, detail),
    error: (msg, detail) => show('error', msg, detail),
    warning: (msg, detail) => show('warning', msg, detail),
    info: (msg, detail) => show('info', msg, detail),
    loading: (msg) => show('loading', msg),
    dismiss,
  };

  return (
    <ToastContext.Provider value={{ toast }}>
      {children}
      <div className="fixed top-4 left-1/2 z-50 flex flex-col gap-2 -translate-x-1/2 min-w-80">
        {toasts.map((t) => (
          <div
            key={t.id}
            role="alert"
            className="rounded-lg shadow-lg px-4 py-3 bg-white border flex gap-3 items-start"
          >
            <span className="font-semibold flex-1">{t.message}</span>
            {t.detail && <span className="text-xs text-slate-500 mt-0.5">{t.detail}</span>}
            <button
              onClick={() => dismiss(t.id)}
              aria-label="Dismiss"
              className="text-slate-400 hover:text-slate-700 shrink-0"
            >
              ✕
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast must be used inside <ToastProvider>');
  return ctx;
}
```

### 4.2 Re-export Hook (`src/hooks/useToast.ts`)

```typescript
// Centralised re-export so imports read: import { useToast } from '@/hooks/useToast'
export { useToast } from '@/context/ToastContext';
```

---

## Step 5: Custom Hooks with TanStack Query v5

### 5.1 Query Hook with Toast (`src/hooks/useQueryWithToast.ts`)

> **TanStack Query v5 change:** `onSuccess`/`onError` were removed from `useQuery` options.
> Use `useEffect` + `dataUpdatedAt` / `errorUpdatedAt` to detect state transitions instead.

```typescript
import { useEffect } from 'react';
import { useQuery, type UseQueryOptions, type UseQueryResult } from '@tanstack/react-query';
import { useToast } from './useToast';

type UseQueryWithToastOptions<TData, TError> = UseQueryOptions<TData, TError> & {
  showSuccessToast?: boolean;
  successMessage?: string;
  showErrorToast?: boolean;
  errorMessage?: string | ((error: TError) => string);
};

export function useQueryWithToast<TData = unknown, TError = Error>(
  options: UseQueryWithToastOptions<TData, TError>,
): UseQueryResult<TData, TError> {
  const { toast } = useToast();
  const {
    showSuccessToast = false,
    successMessage = 'Loaded successfully',
    showErrorToast = true,
    errorMessage,
    ...queryOptions
  } = options;

  const result = useQuery<TData, TError>(queryOptions);

  // Fires only when new data arrives (dataUpdatedAt timestamp changes)
  useEffect(() => {
    if (result.isSuccess && result.isFetchedAfterMount && showSuccessToast) {
      toast.success(successMessage);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [result.dataUpdatedAt]);

  // Fires only when a new error is recorded (errorUpdatedAt timestamp changes)
  useEffect(() => {
    if (result.isError && showErrorToast) {
      const message =
        typeof errorMessage === 'function'
          ? errorMessage(result.error as TError)
          : (errorMessage ?? 'An error occurred');
      toast.error(message);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [result.errorUpdatedAt]);

  return result;
}
```

### 5.2 Mutation Hook with Toast (`src/hooks/useMutationWithToast.ts`)

```typescript
import {
  useMutation,
  type UseMutationOptions,
  type UseMutationResult,
} from '@tanstack/react-query';
import { useToast } from './useToast';

type UseMutationWithToastOptions<
  TData,
  TError,
  TVariables,
  TUserContext,
> = Omit<
  UseMutationOptions<TData, TError, TVariables, TUserContext>,
  'onMutate'
> & {
  loadingMessage?: string;
  successMessage?: string | ((data: TData) => string);
  errorMessage?: string | ((error: TError) => string);
  // onMutate may return any context — it is merged with the internal loading toast id
  onMutate?: (variables: TVariables) => Promise<TUserContext> | TUserContext;
};

type InternalContext<TUserContext> = {
  loadingToastId: string;
  userContext: TUserContext | undefined;
};

export function useMutationWithToast<
  TData = unknown,
  TError = Error,
  TVariables = void,
  TUserContext = void,
>(
  options: UseMutationWithToastOptions<TData, TError, TVariables, TUserContext>,
): UseMutationResult<TData, TError, TVariables, InternalContext<TUserContext>> {
  const { toast } = useToast();
  const {
    loadingMessage = 'Processing...',
    successMessage = 'Done',
    errorMessage = 'Something went wrong',
    onMutate: userOnMutate,
    onSuccess: userOnSuccess,
    onError: userOnError,
    onSettled: userOnSettled,
    ...mutationOptions
  } = options;

  return useMutation<TData, TError, TVariables, InternalContext<TUserContext>>({
    ...mutationOptions,

    onMutate: async (variables) => {
      // Run user's onMutate first (e.g. optimistic updates), then show loading toast
      const userContext = await userOnMutate?.(variables) as TUserContext | undefined;
      const loadingToastId = toast.loading(loadingMessage);
      return { loadingToastId, userContext };
    },

    onSuccess: (data, variables, ctx) => {
      toast.dismiss(ctx?.loadingToastId ?? '');
      toast.success(typeof successMessage === 'function' ? successMessage(data) : successMessage);
      userOnSuccess?.(data, variables, ctx?.userContext as TUserContext);
    },

    onError: (error, variables, ctx) => {
      toast.dismiss(ctx?.loadingToastId ?? '');
      toast.error(typeof errorMessage === 'function' ? errorMessage(error) : errorMessage);
      userOnError?.(error, variables, ctx?.userContext as TUserContext);
    },

    onSettled: (data, error, variables, ctx) => {
      userOnSettled?.(data, error, variables, ctx?.userContext as TUserContext);
    },
  });
}
```

### 5.3 Auth Feature Hooks (`src/features/auth/auth.hooks.ts`)

```typescript
import { useQuery } from '@tanstack/react-query';
import { useMutationWithToast } from '@/hooks/useMutationWithToast';
import { authService } from './auth.service';
import type { LoginFormValues, RegisterFormValues } from './auth.schema';
import type { AuthUser } from './auth.types';

export function useLogin() {
  return useMutationWithToast({
    mutationFn: (credentials: LoginFormValues) =>
      authService.login({ email: credentials.email, password: credentials.password }),
    successMessage: 'Login successful!',
    errorMessage: (err: Error) => err.message || 'Login failed',
    onSuccess: (data) => {
      authService.saveTokens(data.accessToken, data.refreshToken);
    },
  });
}

export function useRegister() {
  return useMutationWithToast({
    mutationFn: (values: RegisterFormValues) =>
      authService.register({ email: values.email, password: values.password, name: values.name }),
    successMessage: 'Registration successful!',
    errorMessage: 'Registration failed',
    onSuccess: (data) => {
      authService.saveTokens(data.accessToken, data.refreshToken);
    },
  });
}

export function useLogout() {
  return useMutationWithToast({
    mutationFn: () => authService.logout(),
    successMessage: 'Logged out',
    errorMessage: 'Logout failed',
  });
}

export function useCurrentUser() {
  return useQuery<AuthUser>({
    queryKey: ['currentUser'],
    queryFn: () => authService.getMe() as Promise<AuthUser>,
    enabled: !!authService.getAccessToken(),
  });
}
```

---

## Step 6: UI Components (Presentational)

### 6.1 Login Form (`src/features/auth/components/LoginForm.tsx`)

```typescript
import { useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useNavigate } from 'react-router-dom';
import { useLogin } from '../auth.hooks';
import { loginSchema, type LoginFormValues } from '../auth.schema';

export function LoginForm() {
  const navigate = useNavigate();
  const loginMutation = useLogin();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginFormValues>({
    resolver: zodResolver(loginSchema),
    mode: 'onBlur',
  });

  useEffect(() => {
    if (loginMutation.isSuccess) navigate('/dashboard');
  }, [loginMutation.isSuccess, navigate]);

  const isPending = loginMutation.isPending;

  return (
    <form onSubmit={handleSubmit((data) => loginMutation.mutate(data))}>
      <div>
        <label htmlFor="email">Email</label>
        <input id="email" type="email" {...register('email')} disabled={isPending} />
        {errors.email && <span className="error">{errors.email.message}</span>}
      </div>

      <div>
        <label htmlFor="password">Password</label>
        <input id="password" type="password" {...register('password')} disabled={isPending} />
        {errors.password && <span className="error">{errors.password.message}</span>}
      </div>

      <button type="submit" disabled={isPending}>
        {isPending ? 'Logging in...' : 'Login'}
      </button>
    </form>
  );
}
```

---

## Step 7: Feature Public API (`src/features/auth/index.ts`)

```typescript
// Only export what external consumers need — hide internal modules
export { LoginForm, RegisterForm, AuthGuard } from './components';
export { useLogin, useRegister, useLogout, useCurrentUser } from './auth.hooks';
export type { AuthUser, AuthState } from './auth.types';
export { loginSchema, registerSchema, type LoginFormValues, type RegisterFormValues } from './auth.schema';
```

---

## Step 8: App Entry Point (`src/main.tsx`)

```typescript
import React from 'react';
import ReactDOM from 'react-dom/client';
import { QueryClientProvider } from '@tanstack/react-query';
import { ToastProvider } from './context/ToastContext';
import { queryClient } from './api/query-client';
import App from './App';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <ToastProvider>
        <App />
      </ToastProvider>
    </QueryClientProvider>
  </React.StrictMode>,
);
```

---

## Development Workflow

### Create a Feature from Scratch

```bash
# 1. Define types (feature-specific interfaces)
#    src/features/[feature]/[feature].types.ts

# 2. Define Zod validation schema (also generates TypeScript types)
#    src/features/[feature]/[feature].schema.ts

# 3. Create service layer — two options:
#    a) Simple CRUD:  export const [feature]Service = createCrudService<Entity>('/[path]')
#    b) Custom logic: src/features/[feature]/[feature].service.ts

# 4. Create hooks using useMutationWithToast / useQueryWithToast
#    src/features/[feature]/[feature].hooks.ts

# 5. Build components (hooks only, no direct API calls)
#    src/features/[feature]/components/

# 6. Expose public API via barrel file
#    src/features/[feature]/index.ts
```

---

## Best Practices Checklist

✅ **Types First**
- API DTOs defined before writing services
- Zod schemas are the single source for form validation types
- Never duplicate type definitions between `*.types.ts` and `*.schema.ts`

✅ **Single Config Source**
- Base URL, timeouts, and endpoints only in `api.config.ts`
- `apiClient` imports from `api.config.ts` — no hardcoded values

✅ **Consistent Response Handling**
- All services use `ApiResponse<T>` as the generic parameter
- Always call `unwrapResponse()` — never access `.data` directly

✅ **API Abstraction**
- Simple CRUD → `createCrudService<T>(basePath)` 
- Complex logic → `*.service.ts` with `apiClient` + `unwrapResponse`
- Components never call `apiClient` directly

✅ **Data Fetching**
- `useQueryWithToast` for queries (read)
- `useMutationWithToast` for mutations (write/update/delete)
- Toast notifications are automatic — components don't call `useToast` for API feedback

✅ **TanStack Query v5 Compliance**
- No `onSuccess`/`onError` in `useQuery` options (removed in v5)
- Use `dataUpdatedAt`/`errorUpdatedAt` deps for side-effects

✅ **Public API Boundaries**
- Import from `features/[feature]/index.ts` only
- Never import from `*.service.ts`, `*.hooks.ts`, or `*.schema.ts` directly

---

## Common Patterns

### Pattern 1: Instant CRUD Feature with `createCrudService`

```typescript
// features/products/product.types.ts
export type Product = { id: string; name: string; price: number };
export type CreateProductDTO = Omit<Product, 'id'>;

// features/products/product.service.ts
import { createCrudService } from '@/api/create-crud-service';
import type { Product, CreateProductDTO } from './product.types';

export const productService = createCrudService<Product, CreateProductDTO>('/products');

// features/products/product.hooks.ts
import { useQueryWithToast } from '@/hooks/useQueryWithToast';
import { useMutationWithToast } from '@/hooks/useMutationWithToast';
import { useQueryClient } from '@tanstack/react-query';
import { productService } from './product.service';

export function useProducts(params?: { page?: number; limit?: number }) {
  return useQueryWithToast({
    queryKey: ['products', params],
    queryFn: () => productService.getAll(params),
    showErrorToast: true,
    errorMessage: 'Failed to load products',
  });
}

export function useCreateProduct() {
  const queryClient = useQueryClient();
  return useMutationWithToast({
    mutationFn: productService.create,
    successMessage: 'Product created',
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['products'] }),
  });
}
```

### Pattern 2: Optimistic Updates (with Context Merging)

```typescript
// TUserContext = snapshot type for rollback
type ItemSnapshot = Item[];

const { mutate } = useMutationWithToast<void, Error, Item, ItemSnapshot>({
  mutationFn: (updated) => itemService.update(updated.id, updated),
  successMessage: 'Saved',

  onMutate: async (updated) => {
    await queryClient.cancelQueries({ queryKey: ['items'] });
    const snapshot = queryClient.getQueryData<Item[]>(['items']) ?? [];
    queryClient.setQueryData(['items'], (old: Item[] = []) =>
      old.map((item) => (item.id === updated.id ? { ...item, ...updated } : item)),
    );
    return snapshot; // returned as TUserContext — accessible in onError
  },

  onError: (_err, _vars, snapshot) => {
    if (snapshot) queryClient.setQueryData(['items'], snapshot);
  },

  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['items'] });
  },
});
```

### Pattern 3: Paginated List with Filters

```typescript
import { useState } from 'react';
import { useQueryWithToast } from '@/hooks/useQueryWithToast';
import { productService } from '@/features/products';

export function useProductList() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');

  const query = useQueryWithToast({
    queryKey: ['products', { page, search }],
    queryFn: () => productService.getPaginated({ page, limit: 20, search: search || undefined }),
    errorMessage: 'Failed to load products',
  });

  return { ...query, page, setPage, search, setSearch };
}
```

### Pattern 4: Dependent Queries

```typescript
export function useUserWithPosts(userId?: string) {
  const user = useQueryWithToast<User>({
    queryKey: ['user', userId],
    queryFn: () => userService.getById(userId!),
    enabled: !!userId,
  });

  const posts = useQueryWithToast<Post[]>({
    queryKey: ['posts', user.data?.id],
    queryFn: () => postService.getAll({ userId: user.data!.id }),
    enabled: !!user.data?.id,
    errorMessage: 'Failed to load posts',
  });

  return { user, posts };
}
```

---

## Environment Variables (`.env.local`)

```bash
VITE_API_BASE_URL=http://localhost:3000/api
VITE_APP_NAME=MyApp
VITE_ENV=development
```

---

## Package Dependencies

> Before installing, verify the latest stable version and scan for CVEs.
> Run `npm audit` after install. Replace `latest` with pinned versions after review.

```json
{
  "dependencies": {
    "react": "latest",
    "react-dom": "latest",
    "react-router-dom": "latest",
    "@tanstack/react-query": "latest",
    "zod": "latest",
    "react-hook-form": "latest",
    "@hookform/resolvers": "latest"
  },
  "devDependencies": {
    "typescript": "latest",
    "@types/react": "latest",
    "@types/react-dom": "latest",
    "vite": "latest",
    "@tanstack/react-query-devtools": "latest"
  }
}
```

---

## Next Steps

1. Copy project structure and install dependencies
2. Fill in `VITE_API_BASE_URL` in `.env.local`
3. Define `ApiResponse<T>` shape to match your backend envelope
4. Add feature endpoints to `API_CONFIG.ENDPOINTS`
5. Bootstrap first feature using `createCrudService` or custom service
6. Verify toasts appear automatically on mutation success/error
