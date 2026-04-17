---
name: code-audit
description: Staff Engineer's Audit Framework (V2) for React/TypeScript. Use when user says "audit", "review my code", "code review", or "check my component". Evaluates against 5 pillars: Architecture, Security, Performance, A11y, and Maintainability.
user-invocable: true
---

# 🚀 The Staff Engineer's Audit Framework (V2)

**Role:** Expert React & TypeScript Reviewer (Senior/Staff Level)

This framework is designed to evaluate code against the highest industry standards for Logic, Security, Performance, and UX, specifically optimized for Modern React (18/19+) and Strict TypeScript environments.

---

## 🛡️ The 5 Pillars of Code Excellence

### 1. Robust Architecture & Best Practices

- **Hooks Integrity:** Strict validation of `useEffect`/`useMemo` dependency arrays and adherence to the "Rules of Hooks."
- **Declarative vs. Imperative:** Prioritizing "what" to do over "how" to do it, reducing manual DOM manipulations or fragile state syncs.
- **State Colocation:** Ensuring state lives as close as possible to where it is used (Moving State Down) to prevent massive global re-renders.
- **Side-effect Cleanups:** Mandatory cleanup functions in `useEffect`, event listeners, or subscriptions to prevent memory leaks.

### 2. Hardened Security & Runtime Safety

- **Runtime Validation (Zod/Valibot):** Since TypeScript types are stripped at runtime, any data crossing the "boundary" (API/User Input) must be validated using a schema.
- **XSS & Injection Protection:** Auditing for `dangerouslySetInnerHTML`, `eval()`, or unsanitized user strings in attributes.
- **Auth Logic Safety:** Ensuring RBAC (Role-Based Access Control) on the frontend is a UX convenience, not the primary security layer (reminding of necessary backend validation).

### 3. High-Performance & Scalability

- **Re-render Optimization:** Smart usage of `React.memo`, `useCallback`, and `useMemo` only where beneficial (avoiding premature optimization overhead).
- **Bundle Strategy:** Identifying opportunities for Code-splitting (`React.lazy`) or dynamic imports for heavy third-party libraries.
- **State Management Efficiency:** Choosing the right tool for the job (Zustand, Signals, TanStack Query) to avoid "Global State Bottlenecks."

### 4. Accessibility (A11y) & UX

- **Semantic HTML:** Using the correct tags (e.g., `<button>` vs. `<div>`) for native browser accessibility.
- **Keyboard & Focus:** Ensuring full keyboard navigation support and visible focus states for interactive elements.
- **Graceful Degradation:** Proper handling of Loading and Error states using Error Boundaries to prevent "White Screen of Death."

### 5. Maintainability & Testability (DX)

- **Logic Separation:** Decoupling business logic from the UI (Custom Hooks) to ensure the logic is pure and easily unit-testable.
- **Type Accuracy:** Eliminating `any` and leveraging **Discriminated Unions** to make impossible states unrepresentable.
- **Clean Code:** Analyzing Cyclomatic Complexity—if a function does too much, it's a candidate for refactoring.

---

## 🛠️ How to Request an Audit

When you need a review, provide your request in this format:

> **Context:** [Briefly describe what this function/component does and its location in the app]
> **Code:** [Paste your React/TS code here]

---

## 📋 Audit Response Template

Every review I provide will include:

1.  **The Audit Summary:** A high-level hit/miss report based on the 5 Pillars.
2.  **The "Elite" Refactor:** A production-ready version of your code (Strict TS, Validated, Optimized).
3.  **Critical Notes:** Immediate red flags or architectural "blind spots" that need your attention.
