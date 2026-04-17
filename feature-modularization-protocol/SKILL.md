---
name: feature-modularization-protocol
description: A protocol for modularizing complex React/TS features into scalable, testable, and maintainable structures using UFMP. Use when refactoring large components or designing new complex features.
user-invocable: true
---

# Feature Modularization Protocol (UFMP) v3

This skill provides a standardized framework for transforming monolithic React components into high-quality, professional-grade feature modules.

## Core Mandate: Separation of Concerns (SoC)

Every complex feature MUST be decomposed into distinct layers within a dedicated feature directory. This ensures high cohesion and low coupling.

## Recommended Structure

```text
src/features/[feature-name]/
├── index.ts                 # 🚪 PUBLIC API: Exports only allowed elements
├── [feature-name].config.ts  # ⚙️ STATIC: Metadata, Enums, Default Values
├── [feature-name].schema.ts  # 📜 RULES: Zod Schema & TypeScript Types
├── [feature-name].service.ts # 🌐 DATA: API Calls, Fetching Logic (DTOs)
├── [feature-name].utils.ts   # 🧠 LOGIC: Pure Functions, Formatters, Math
├── [feature-name].hooks.ts   # ⚓ STATE: Feature-specific Custom Hooks (React Query)
├── [feature-name].context.tsx # 📦 STATE: Local Feature Context (if complex)
├── components/               # 🧩 VIEW: UI Fragments (Presentational)
├── assets/                   # 🎨 ASSETS: SVGs, Images, CSS for this feature
└── __tests__/                # 🧪 TEST: Unit (Utils) and Integration (MSW)
```

## Layer Guidelines & Best Practices

### 1. Naming & Scaling

- **Naming Convention:** Use `kebab-case` for file names (e.g., `weather-settings.utils.ts`) and `PascalCase` for React components.
- **Adaptive Scaling:** Small features (< 100 lines) may combine layers into a single file until complexity warrants separation.
- **Rule of Three:** If a component/utility is shared by > 3 features, move it to `src/shared` or `src/components`.

### 2. Validation & Security (`*.schema.ts`)

- **Strict Validation:** Use `.strict()` or `.strip()` in Zod schemas to prevent "Over-Posting" and ignore unauthorized fields.
- **Input Sanitization:** Use `z.preprocess()` to trim/sanitize inputs. Use `.max()` to prevent memory-exhaustion attacks.
- **Single Source of Truth:** Types MUST be inferred: `export type FormValues = z.infer<typeof featureSchema>;`.

### 3. Pure Logic & Utils (`*.utils.ts`)

- **Immutability:** Never mutate inputs. Functions must be "Pure" (Deterministic).
- **Isolation:** No React hooks, no API calls, no browser globals (window/document) unless injected as dependencies.
- **Testing:** 100% unit test coverage mandatory.

### 4. Custom Hooks & Server State (`*.hooks.ts`)

- **Encapsulation:** Wrap `useQuery` and `useMutation` (React Query/SWR). The UI should not know about fetch implementation.
- **Form Integration:** Combine `react-hook-form` with `zodResolver`. Use `useWatch` for granular performance.
- **Error Handling:** Catch service errors and transform them into UI-ready messages/states.

### 5. Service Layer & DTOs (`*.service.ts`)

- **DTO (Data Transfer Object):** Map raw API responses to UI models _here_. The rest of the feature should only use the UI models.
- **Security:** Use the "Least Privilege" principle for payloads.
- **Abstraction:** Use a standardized `apiClient` instance (Axios/Fetch) with interceptors for auth/logging.

### 6. Local State Management (`*.context.tsx`)

- **Feature Context:** Use for complex features where prop-drilling exceeds 3 levels within the same feature.
- **Performance:** Split contexts if one part of the state updates much more frequently than others.

### 7. Public API & Boundaries (`index.ts`)

- **Isolation:** NEVER import from another feature's internal files. Communication must happen via `index.ts`.
- **Barrel File:** Only export the main component, the schema (for external validation), and necessary types.
- **Circular Deps:** Internal files MUST NEVER import from their own `index.ts`.

## Advanced Testing Strategy (`__tests__/`)

- **Unit Tests:** Target `utils.ts` for logic.
- **Integration Tests:** Use **Mock Service Worker (MSW)** to intercept network calls. Test the `hooks.ts` and `service.ts` together to ensure correct data flow.
- **Component Tests:** Use React Testing Library to verify UI behavior based on various hook states.

## Security Checklist

1. **No Hardcoded Secrets:** Check `*.config.ts` for keys or PII.
2. **Double-Lock Validation:** Client validation is for UX; Server validation is for Security.
3. **Data Masking:** Mask sensitive info in `utils.ts` before passing to the View.
4. **Strict Schema:** Ensure `.strict()` is used on sensitive API payloads.

## Refactoring Workflow

1. **Extract Constants:** To `.config.ts`.
2. **Define Schema:** To `.schema.ts` (using Zod `.strict()`).
3. **Isolate Logic:** To `.utils.ts`.
4. **Create Hooks:** To `.hooks.ts` (with MSW for testing).
5. **Componentize:** Break JSX into `components/`.
6. **Seal the Module:** Create `index.ts`.
7. **Verify:** Run tests in `__tests__/`.
