---
name: react-feature-guideline
description: Project setup guidelines for React + TypeScript feature modules using UFMP. Generates a CLAUDE.md tailored to the current project by reading its stack, conventions, and existing features. Use when starting a new project or onboarding Claude to an existing one.
---

# React Feature Guideline — Project Setup

When this skill is invoked, your job is to **read the current project** and produce a `CLAUDE.md` at the project root that documents:

1. Tech stack (from `package.json`)
2. Project layout (from directory structure)
3. Feature module structure following UFMP
4. Layer rules with real code examples from the project
5. Cross-cutting conventions (imports, i18n, styling, forms, API, pagination)
6. Naming conventions
7. Testing approach
8. A step-by-step checklist for adding a new feature

---

## How to execute

1. Read `package.json` to identify the actual stack.
2. Explore the top-level `app/` or `src/` directory structure.
3. Find an existing feature module and read each layer file (`.config.ts`, `.schema.ts`, `.service.ts`, `.utils.ts`, `.hooks.ts`, `index.ts`) as reference examples.
4. Read one component from `components/` inside the feature.
5. Generate `CLAUDE.md` at the project root using the template below, filled with **real code snippets from the project** — not generic placeholders.

---

## CLAUDE.md Template

```markdown
# [Project Name] — Claude Code Guidelines

## Tech Stack

| Layer | Library |
|---|---|
| Framework | [e.g. React 19 + React Router v7] |
| Language | TypeScript (strict) |
| Styling | [e.g. Tailwind CSS v4] |
| Server State | [e.g. TanStack Query v5] |
| Forms | [e.g. react-hook-form + zod] |
| Client State | [e.g. Redux Toolkit] |
| Testing | [e.g. Jest + React Testing Library] |
[...add/remove rows based on actual package.json]

---

## Project Layout

[Generate from actual directory tree]

---

## Feature Module Structure (UFMP)

Every feature lives under `[features-root]/[feature-name]/` and follows this layout:

[feature-name]/
├── index.ts                       # PUBLIC API — only allowed exports
├── [feature-name].config.ts       # Static constants, enums, display configs
├── [feature-name].schema.ts       # Zod schemas + inferred TypeScript types
├── [feature-name].service.ts      # API re-exports or DTO mappers
├── [feature-name].utils.ts        # Pure functions, mappers, formatters
├── [feature-name].hooks.ts        # Feature-specific custom hooks
├── components/                    # Presentational UI components
└── __tests__/                     # Unit + integration tests

Existing features: [list them]

---

## Layer Rules

### `[feature].config.ts` — Static constants
[rules + real code snippet from project]

### `[feature].schema.ts` — Zod + Types
[rules + real code snippet from project]

### `[feature].service.ts` — API layer
[rules + real code snippet from project]

### `[feature].utils.ts` — Pure logic
[rules + real code snippet from project]

### `[feature].hooks.ts` — Feature state
[rules + real code snippet from project]

### `components/` — Presentational components
[rules]

### `index.ts` — Public API
[rules + real code snippet from project]

---

## Cross-Cutting Rules

### Imports & Paths
- Use `@/` alias (or project equivalent) for absolute imports.
- Never import from another feature's internal files — only from its `index.ts`.
- Shared utilities used by 3+ features belong in `[shared-utils-dir]/`.

### Styling
[document actual approach: Tailwind / CSS Modules / styled-components, etc.]

### Forms
[document if react-hook-form + zod, or other form library]

### API / Server State
[document TanStack Query patterns or SWR or plain fetch]

### Pagination
[document cursor / offset / infinite scroll pattern used]

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
| Query hooks | `useGetXxx`, `useCreateXxx`, `useUpdateXxx`, `useDeleteXxx` | `useGetRoleList` |

---

## Testing

[Document test file locations, framework config files, and patterns used]

---

## Adding a New Feature — Checklist

1. Create `[features-root]/[feature-name]/` directory.
2. Add `[feature-name].config.ts` — constants, per-page options, display maps.
3. Add `[feature-name].schema.ts` — Zod schemas with `.strict()`, infer types.
4. Add `[feature-name].service.ts` — re-export API hooks, add `DEFAULT_PARAMS` if paginated.
5. Add `[feature-name].utils.ts` — pure mappers and helpers.
6. Add `[feature-name].hooks.ts` — compose API hooks + form logic, return structured object.
7. Add `components/` — presentational components consuming hooks via props.
8. Add `index.ts` — expose only the public surface.
9. Add `__tests__/` — unit tests for utils, integration tests for hooks.
10. Wire route and add API hooks if needed.
```

---

## Layer Rules (invariant across projects)

These rules apply regardless of project — use them when writing the CLAUDE.md:

### config.ts
- No hooks, no API calls, no side effects.
- i18n-dependent display maps must accept `t` as a parameter: `createXxxConfig(t: T)`.

### schema.ts
- All types inferred from Zod: `export type Foo = z.infer<typeof FooSchema>`.
- Use `.strict()` on API response schemas.
- Use `.trim()` / `.max()` on user input fields.
- Schema factories that need `t()`: `createXxxSchema(t: T)`.

### service.ts
- Re-export query hooks from `api/` layer. Never call `fetch` directly here.
- Place `DEFAULT_PARAMS` for paginated resources in this file.

### utils.ts
- Pure functions only — deterministic, no side effects, no React hooks.
- 100% unit test coverage target.
- DTO → UI model mappers live here.

### hooks.ts
- Wrap `useQuery` / `useMutation` — UI must not know fetch details.
- Pair `useForm` with `zodResolver`.
- Return structured shape: `{ data, state, filters, pagination, handlers }`.
- Compose private internal hooks into the public hook.

### components/
- Receive all state via props from hooks — no direct API calls.
- PascalCase filenames.

### index.ts
- Single public surface for the feature.
- Never re-export internal implementation details.
- Internal files must never import from their own `index.ts`.
