# Project — Claude Code Guidelines

## Tech Stack

| Layer | Library |
|---|---|
| Framework | React 19 + React Router v7 (file-based routes) |
| Language | TypeScript (strict) |
| Styling | Tailwind CSS v4 |
| Server State | TanStack Query v5 |
| Forms | react-hook-form v7 + zod v4 |
| Client State | Redux Toolkit |
| Virtualisation | @tanstack/react-virtual |
| Date | dayjs |
| i18n | i18next + react-i18next |
| Testing | Jest + React Testing Library |

---

## Project Layout

```
app/
├── api/               # TanStack Query hooks per domain (useGetXxx, useCreateXxx…)
├── assets/            # Global SVGs, images, logos
├── components/        # Shared, domain-agnostic UI primitives
├── config/            # App-level config (env, routes metadata)
├── config.ts          # Runtime env reader (window.ENV → VITE_*)
├── constants.tsx      # App-wide constants
├── features/          # Feature modules (see below)
├── hooks/             # Shared custom hooks (useI18n, isClient…)
├── i18n/locales/      # Translation JSON files
├── provider/          # React context providers (QueryClient, Redux…)
├── routes/            # File-based route components
├── stores/            # Redux slices
├── types.ts           # Global shared TypeScript types
└── utils/             # Shared pure utilities (date, pagination…)
```

---

## Feature Module Structure (UFMP)

Every feature lives under `app/features/[feature-name]/` and follows this layout:

```
app/features/[feature-name]/
├── index.ts                       # PUBLIC API — only allowed exports
├── [feature-name].config.ts       # Static constants, enums, display configs
├── [feature-name].schema.ts       # Zod schemas + inferred TypeScript types
├── [feature-name].service.ts      # API re-exports or DTO mappers
├── [feature-name].utils.ts        # Pure functions, mappers, formatters
├── [feature-name].hooks.ts        # Feature-specific custom hooks
├── components/                    # Presentational UI components
└── __tests__/                     # Unit + integration tests
```

---

## Layer Rules

### `[feature].config.ts` — Static constants
- Pagination options, status display maps, label maps, default params.
- Functions that need `t()` (i18n) must accept `t` as a parameter.
- No hooks, no API calls.

```ts
export const PER_PAGE_OPTIONS: number[] = [5, 10, 20, 50]

export function createStatusConfig(t: T): Record<Status, { label: string; className: string }> {
  return { active: { label: t('feature.status.active'), className: "bg-success-100 text-success-300" } }
}
```

### `[feature].schema.ts` — Zod + Types
- All Zod schemas go here. Types are **always** inferred (`z.infer<typeof …>`), never written manually.
- Use `.strict()` on API response schemas to block over-posting.
- Use `z.preprocess()` / `.trim()` for sanitisation.
- Schema factories that depend on `t()` follow the `createXxxSchema(t: T)` naming pattern.

```ts
export const ItemSchema = z.object({ id: z.number(), name: z.string() }).strict()
export type Item = z.infer<typeof ItemSchema>

export function createAddFormSchema(t: T) {
  return z.object({ name: z.string().min(1, t('common.error.required')).max(200).trim() })
}
export type AddFormValues = z.infer<ReturnType<typeof createAddFormSchema>>
```

### `[feature].service.ts` — API layer
- Re-export TanStack Query hooks from `@/api/[feature]`.
- Add DTO mappers here when the API shape differs from the UI model.
- Never call `fetch` directly — use the hooks from `app/api/`.

```ts
// thin re-export
export { useGetItems, useCreateItem, useUpdateItem, useDeleteItem } from "@/api/feature"

// default params for paginated lists
export const DEFAULT_PARAMS = { cursor: { limit: 20, next: null }, searchText: "" }
```

### `[feature].utils.ts` — Pure logic
- Pure, deterministic functions only. No hooks, no API calls, no `window`/`document`.
- Must be testable in isolation.
- DTO-to-UI mappers live here.

```ts
export function mapToItem(raw: RawItem): Item {
  return { id: raw.id, name: raw.name, createdBy: raw.createdBy }
}
```

### `[feature].hooks.ts` — Feature state
- Wrap `useQuery` / `useMutation` into named hooks. UI components must not know the fetch implementation.
- Combine `react-hook-form` with `zodResolver`.
- Return a structured object grouping: `data`, `state`, `filters`, `pagination`, `handlers`.
- Use private internal hooks composed into the public hook.

```ts
return {
  data:       { rows },
  state:      { isPending, isError, dialogOpen },
  filters:    { searchText },
  pagination: { hasNext, hasPrevious, perPage },
  handlers:   { handleSearch, goToNextPage, openDialog },
}
```

### `components/` — Presentational components
- PascalCase filenames matching the exported component name.
- Receive props from hooks; no direct API calls inside components.
- Import shared UI primitives from `@/components/` (Dialog, Button, Table, DatePicker…).
- Import SVG icons as React components: `import UploadIcon from "@/assets/icons/upload.svg?react"`.

### `index.ts` — Public API
- The **only** file other features may import from.
- Export the main component(s), relevant hooks, config constants, and types.
- Never export internal implementation files.
- Internal files must **never** import from their own `index.ts`.

```ts
export { useFeatureTable } from "./feature.hooks"
export { PER_PAGE_OPTIONS } from "./feature.config"
export type { Item } from "./feature.schema"
export { FeatureTable } from "./components/FeatureTable"
export { FeatureDialog } from "./components/FeatureDialog"
```

---

## Cross-Cutting Rules

### Imports & Paths
- Use `@/` alias for all absolute imports from `app/`.
- Never import from another feature's internal files — only from its `index.ts`.
- Shared utilities used by 3+ features belong in `app/utils/` or `app/hooks/`.

### i18n
- Always use `useI18n()` hook (wraps `react-i18next`).
- Translation keys live in `app/i18n/locales/`.
- Pass `t` as a function argument to config/schema factories — never call hooks outside components/hooks.

### Styling
- Tailwind CSS v4 utility classes only.
- Use `clsx` or `tailwind-merge` for conditional class composition.
- Colour tokens: `bg-success-100`, `text-error-300`, `bg-grey-100`, etc. — match existing usage.

### Forms
- Always pair `useForm` with `zodResolver(schema)`.
- Use `useFieldArray` for dynamic field lists.
- Use `mode: "onChange"` for real-time validation feedback.

### API / Server State
- TanStack Query hooks live in `app/api/[domain].tsx`.
- Use `useQuery` for reads, `useMutation` for writes.
- Feature hooks wrap these — UI never calls `app/api` directly.

### Pagination
- Cursor-based pagination. Use `paginationNextPage` / `paginationPreviousPage` from `@/utils/pagination`.
- Keep `lastValidListRef` pattern to avoid empty flash on refetch.

### Virtualisation
- Use `@tanstack/react-virtual` (`useVirtualizer`) for long lists.
- Attach `tableBodyRef` to the scroll container; use `overscan: 10` as default.

---

## Naming Conventions

| Item | Convention | Example |
|---|---|---|
| Feature directories | `kebab-case` | `excel-import/` |
| Feature layer files | `[feature].[layer].ts` | `role.hooks.ts` |
| React components | `PascalCase.tsx` | `RoleDialog.tsx` |
| Hooks | `useXxx` | `useRoleTable` |
| Schema factories | `createXxxSchema` | `createAddRoleFormSchema` |
| Config factories | `createXxxConfig` | `createStatusConfig` |
| Type mappers | `mapToXxx` | `mapToRoleItem` |
| Query hooks (api/) | `useGetXxx`, `useCreateXxx`, `useUpdateXxx`, `useDeleteXxx` | `useGetRoleList` |

---

## Testing

- Unit tests: target `*.utils.ts` with 100% coverage.
- Integration tests: mock network with MSW; test hooks + service together.
- Component tests: React Testing Library; verify UI states driven by hook output.
- Test files live in `__tests__/` inside the feature directory.
- Global test setup: `jest.setup.js`, config: `jest.config.mjs`.

---

## Adding a New Feature — Checklist

1. Create `app/features/[feature-name]/` directory.
2. Add `[feature-name].config.ts` — constants, per-page options, display maps.
3. Add `[feature-name].schema.ts` — Zod schemas with `.strict()`, infer types.
4. Add `[feature-name].service.ts` — re-export API hooks, add `DEFAULT_PARAMS` if paginated.
5. Add `[feature-name].utils.ts` — pure mappers and helpers.
6. Add `[feature-name].hooks.ts` — compose API hooks + form logic, return structured object.
7. Add `components/` — presentational components consuming hooks via props.
8. Add `index.ts` — expose only the public surface.
9. Add `__tests__/` — unit tests for utils, integration tests for hooks.
10. Wire route in `app/routes/` and add API hooks to `app/api/` if needed.
