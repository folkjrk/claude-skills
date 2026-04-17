---
name: react-best-practices
description: A practical guide to building scalable, maintainable, and high-performance frontend applications using React (18+/19) and TypeScript.

---

# Frontend Development Reference Guide (React + TypeScript)

**Version:** 2.0
**Last Updated:** February 2026
**Audience:** Full-stack developers building modern React applications

This comprehensive guide covers **frontend engineering best practices**, focusing on React with TypeScript, modern patterns (React 18+/19), performance optimization, and professional development workflows.

---

## Table of Contents

1. [Core Frontend Principles](#1-core-frontend-principles)
2. [TypeScript Integration](#2-typescript-integration)
3. [React Component Design](#3-react-component-design)
4. [Modern React Patterns (18+/19)](#4-modern-react-patterns-1819)
5. [State Management Best Practices](#5-state-management-best-practices)
6. [Performance Optimization](#6-performance-optimization)
7. [Web Vitals & Metrics](#7-web-vitals--metrics)
8. [Styling & UI Consistency](#8-styling--ui-consistency)
9. [Accessibility (a11y)](#9-accessibility-a11y)
10. [Error Handling & Boundaries](#10-error-handling--boundaries)
11. [Testing Strategy](#11-testing-strategy)
12. [Naming Conventions](#12-naming-conventions)
13. [Project Structure](#13-project-structure)
14. [Clean Code Practices](#14-clean-code-practices)
15. [Professional Frontend Mindset](#15-professional-frontend-mindset)

---

## 1. Core Frontend Principles

### 1.1 User-Centered Design

- **Clarity first:** Build interfaces with intuitive interactions and predictable behavior
- **Accessibility by default:** Consider screen readers, keyboard navigation, and ARIA attributes
- **State visibility:** Handle loading, empty, and error states explicitly—never leave users guessing
- **Progressive enhancement:** Start with core functionality, then layer on enhancements

> **💡 Tip:** Every UI state (loading, success, error, empty) should have a deliberate design. Blank screens confuse users.

---

### 1.2 Separation of Concerns

- **UI layer:** Components render data and handle user interactions
- **Business logic:** Lives in services, hooks, or utilities—not in JSX
- **Data fetching:** Separate from presentation (use custom hooks or libraries like React Query)
- **Composition over inheritance:** Build complex UIs from small, focused components

**Decision Framework:**

| Concern | Where it Belongs | Anti-Pattern |
|---------|------------------|--------------|
| API calls | Custom hooks, services | Inside component body |
| Validation logic | Utility functions, schemas (Zod) | Inline in JSX |
| UI rendering | Presentational components | Mixed with data fetching |
| Global state | Context, Zustand, Redux | Props drilling 5+ levels |

---

### 1.3 Maintainability & Scalability

- **Readable code wins:** Prioritize clarity over cleverness
- **Self-documenting:** Use descriptive names; comments explain **why**, not **what**
- **Testable by design:** Pure functions and isolated components are easier to test
- **Refactor continuously:** Don't let technical debt accumulate

---

### 1.4 Performance Awareness

- **Measure first, optimize second:** Use React DevTools Profiler and Lighthouse
- **Avoid premature optimization:** Write clean code first, optimize bottlenecks later
- **Understand trade-offs:** Developer experience vs. runtime performance, bundle size vs. features

> **⚠️ Warning:** Over-optimizing too early leads to complex, unmaintainable code. Profile first!

---

## 2. TypeScript Integration

### 2.1 Why TypeScript?

- **Type safety:** Catch errors at compile time, not runtime
- **Better IDE support:** Autocomplete, refactoring, and inline documentation
- **Self-documenting code:** Types serve as documentation
- **Refactoring confidence:** Rename variables, functions across the codebase safely

---

### 2.2 Core TypeScript Patterns

#### **Discriminated Unions (Tagged Unions)**

Use for state machines, API responses, or UI states:

```typescript
// API response types
type ApiResponse<T> =
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: string };

function UserProfile({ response }: { response: ApiResponse<User> }) {
  switch (response.status) {
    case 'loading':
      return <Spinner />;
    case 'success':
      return <UserCard user={response.data} />;
    case 'error':
      return <ErrorMessage error={response.error} />;
  }
}
```

**Benefits:**
- Exhaustive checks (TypeScript ensures all cases are handled)
- No invalid states (can't have `data` and `error` simultaneously)

---

#### **Generic Components**

Make components reusable across different data types:

```typescript
interface TableProps<T> {
  data: T[];
  columns: Column<T>[];
  onRowClick?: (row: T) => void;
}

function Table<T>({ data, columns, onRowClick }: TableProps<T>) {
  return (
    <table>
      <thead>
        <tr>
          {columns.map((col) => (
            <th key={col.key}>{col.header}</th>
          ))}
        </tr>
      </thead>
      <tbody>
        {data.map((row, idx) => (
          <tr key={idx} onClick={() => onRowClick?.(row)}>
            {columns.map((col) => (
              <td key={col.key}>{col.render(row)}</td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}

// Usage: type-safe for User and Product
<Table<User> data={users} columns={userColumns} />
<Table<Product> data={products} columns={productColumns} />
```

---

#### **Utility Types**

Leverage TypeScript's built-in utility types:

```typescript
// Pick specific props
type UserPreview = Pick<User, 'id' | 'name' | 'avatar'>;

// Make all props optional
type PartialUser = Partial<User>;

// Make all props required
type RequiredUser = Required<User>;

// Exclude properties
type UserWithoutPassword = Omit<User, 'password'>;

// Extract return type from function
type UserData = ReturnType<typeof fetchUser>;
```

---

#### **Props with Children**

```typescript
import { ReactNode } from 'react';

interface CardProps {
  title: string;
  children: ReactNode; // Accepts any valid React child
  variant?: 'default' | 'outlined' | 'elevated';
}

function Card({ title, children, variant = 'default' }: CardProps) {
  return (
    <div className={`card card--${variant}`}>
      <h2>{title}</h2>
      {children}
    </div>
  );
}
```

---

### 2.3 TypeScript Best Practices

✅ **Do:**
- Use `interface` for object shapes, `type` for unions/intersections
- Enable `strict: true` in `tsconfig.json`
- Use `as const` for readonly tuples/objects
- Prefer explicit types for public APIs (component props, function parameters)

❌ **Avoid:**
- `any` (use `unknown` if type is truly unknown)
- Type assertions (`as Type`) unless absolutely necessary
- Overly complex nested generics (keep it readable)

---

## 3. React Component Design

### 3.1 Functional Components & Hooks

- **Default to functional components:** Class components are legacy
- **Hooks first:** `useState`, `useEffect`, `useMemo`, `useCallback`
- **Custom hooks:** Extract reusable logic (e.g., `useAuth`, `useDebounce`)

```typescript
function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const handler = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(handler);
  }, [value, delay]);

  return debouncedValue;
}

// Usage
const searchQuery = useDebounce(inputValue, 300);
```

---

### 3.2 Single Responsibility Components

Each component should have **one clear purpose**:

| Component Type | Responsibility | Example |
|----------------|----------------|---------|
| **Presentational** | Display data, emit events | `UserCard`, `Button` |
| **Container** | Fetch data, manage state | `UserProfileContainer` |
| **Layout** | Structure pages | `DashboardLayout` |
| **Provider** | Share context | `ThemeProvider` |

**Example:**

```typescript
// ❌ Bad: Mixed responsibilities
function UserDashboard() {
  const [user, setUser] = useState(null);
  const [posts, setPosts] = useState([]);

  useEffect(() => {
    fetch('/api/user').then(res => res.json()).then(setUser);
    fetch('/api/posts').then(res => res.json()).then(setPosts);
  }, []);

  return (
    <div>
      <h1>{user?.name}</h1>
      {posts.map(post => <PostCard key={post.id} post={post} />)}
    </div>
  );
}

// ✅ Good: Separated concerns
function UserDashboard() {
  return (
    <DashboardLayout>
      <UserProfile />
      <PostList />
    </DashboardLayout>
  );
}

function UserProfile() {
  const { data: user, isLoading } = useUser();
  if (isLoading) return <Spinner />;
  return <UserCard user={user} />;
}

function PostList() {
  const { data: posts } = usePosts();
  return posts.map(post => <PostCard key={post.id} post={post} />);
}
```

---

### 3.3 Controlled vs Uncontrolled Components

**Controlled Components:**
- React state controls the input value
- Necessary for validation, formatting, or dynamic behavior

```typescript
function EmailInput() {
  const [email, setEmail] = useState('');

  return (
    <input
      type="email"
      value={email}
      onChange={(e) => setEmail(e.target.value.toLowerCase())}
    />
  );
}
```

**Uncontrolled Components:**
- DOM manages the value (use `ref`)
- Simpler for basic forms or file uploads

```typescript
function FileUpload() {
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleSubmit = () => {
    const file = fileInputRef.current?.files?.[0];
    console.log(file);
  };

  return <input type="file" ref={fileInputRef} />;
}
```

**Decision Guide:**
- **Use controlled** when you need real-time validation or transformations
- **Use uncontrolled** for simple forms or performance-critical inputs

---

## 4. Modern React Patterns (18+/19)

### 4.1 Suspense for Data Fetching

Suspend rendering until async resources (data, code) are ready:

```typescript
import { Suspense } from 'react';

function ProfilePage() {
  return (
    <Suspense fallback={<ProfileSkeleton />}>
      <UserProfile />
      <Suspense fallback={<PostsSkeleton />}>
        <UserPosts />
      </Suspense>
    </Suspense>
  );
}

// Works with libraries like React Query, SWR, or custom hooks
function UserProfile() {
  const user = useSuspenseQuery({ queryKey: ['user'], queryFn: fetchUser });
  return <div>{user.name}</div>;
}
```

**Benefits:**
- Declarative loading states
- Parallel data fetching (no waterfall)
- Automatic error boundaries integration

---

### 4.2 useTransition (Non-blocking Updates)

Mark state updates as **low priority** to keep the UI responsive:

```typescript
import { useState, useTransition } from 'react';

function SearchResults() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [isPending, startTransition] = useTransition();

  const handleSearch = (value: string) => {
    setQuery(value); // High priority (input stays responsive)

    startTransition(() => {
      // Low priority (can be interrupted)
      const filtered = hugeDataset.filter(item =>
        item.name.includes(value)
      );
      setResults(filtered);
    });
  };

  return (
    <>
      <input value={query} onChange={(e) => handleSearch(e.target.value)} />
      {isPending && <Spinner />}
      <ResultsList results={results} />
    </>
  );
}
```

**Use cases:**
- Filtering large lists
- Expensive computations
- Non-critical UI updates

---

### 4.3 Server Components (React 19)

Server Components run **on the server**, reducing bundle size and improving performance:

```typescript
// app/posts/[id]/page.tsx (Next.js 13+ App Router)

// Server Component (default in App Router)
async function PostPage({ params }: { params: { id: string } }) {
  const post = await fetchPost(params.id); // Direct database access

  return (
    <article>
      <h1>{post.title}</h1>
      <p>{post.content}</p>
      <CommentsList postId={post.id} /> {/* Client Component */}
    </article>
  );
}
```

**Key differences:**

| Feature | Server Component | Client Component |
|---------|------------------|------------------|
| **Where it runs** | Server | Browser |
| **Bundle size** | Zero JS sent | Included in bundle |
| **Can use** | Database, file system | Browser APIs, hooks |
| **Directive** | (default) | `'use client'` |

**When to use Server Components:**
- Data fetching (direct DB access)
- Static content rendering
- Large dependencies (e.g., markdown parsers)

---

### 4.4 Server Actions (React 19)

Submit forms and mutate data directly from components:

```typescript
'use server'; // Marks this as a Server Action

import { revalidatePath } from 'next/cache';

export async function createPost(formData: FormData) {
  const title = formData.get('title') as string;
  const content = formData.get('content') as string;

  await db.posts.create({ title, content });
  revalidatePath('/posts'); // Refresh the page
}

// In component
'use client';

import { createPost } from './actions';

function NewPostForm() {
  return (
    <form action={createPost}>
      <input name="title" required />
      <textarea name="content" required />
      <button type="submit">Publish</button>
    </form>
  );
}
```

**Benefits:**
- No API routes needed
- Progressive enhancement (works without JS)
- Type-safe RPC

---

## 5. State Management Best Practices

### 5.1 Server State vs. Client State

**Understanding the difference is critical:**

| Type | Definition | Examples | Tools |
|------|------------|----------|-------|
| **Server State** | Data from backend (async, cached) | User profile, posts, products | React Query, SWR, RTK Query |
| **Client State** | UI-only state | Modal open/close, form inputs | useState, Zustand, Context |

**Anti-pattern:**
Storing server data in Redux/Context (use specialized libraries instead).

---

### 5.2 State Placement Strategy

Follow this **decision tree**:

1. **Is it server data?** → Use React Query/SWR
2. **Is it URL state?** → Use search params/URL
3. **Is it used by 1 component?** → `useState`
4. **Is it shared by 2-3 components?** → Lift state up or use Context
5. **Is it global (used everywhere)?** → Zustand, Redux, Context

**Example with React Query:**

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

function UserProfile({ userId }: { userId: string }) {
  const queryClient = useQueryClient();

  // Server state: cached, auto-refetches
  const { data: user, isLoading } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
    staleTime: 5 * 60 * 1000, // 5 minutes
  });

  // Mutation: update server + invalidate cache
  const updateMutation = useMutation({
    mutationFn: updateUser,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user', userId] });
    },
  });

  if (isLoading) return <Spinner />;
  return <UserCard user={user} onUpdate={updateMutation.mutate} />;
}
```

---

### 5.3 Derived State

**Never duplicate state—compute it instead:**

```typescript
// ❌ Bad: Duplicating state
const [todos, setTodos] = useState(initialTodos);
const [completedTodos, setCompletedTodos] = useState([]);

const addTodo = (todo) => {
  setTodos([...todos, todo]);
  if (todo.completed) {
    setCompletedTodos([...completedTodos, todo]); // Easy to get out of sync!
  }
};

// ✅ Good: Derive from source of truth
const [todos, setTodos] = useState(initialTodos);
const completedTodos = useMemo(
  () => todos.filter(t => t.completed),
  [todos]
);
```

---

### 5.4 Immutability

**Always create new objects/arrays:**

```typescript
// ❌ Bad: Mutating state
const handleComplete = (id) => {
  const todo = todos.find(t => t.id === id);
  todo.completed = true; // MUTATION!
  setTodos(todos);
};

// ✅ Good: Immutable update
const handleComplete = (id) => {
  setTodos(todos.map(t =>
    t.id === id ? { ...t, completed: true } : t
  ));
};
```

**For complex nested updates, use Immer:**

```typescript
import { useImmer } from 'use-immer';

const [state, updateState] = useImmer(initialState);

updateState(draft => {
  draft.user.profile.name = 'Alice'; // Looks like mutation, but safe!
});
```

---

## 6. Performance Optimization

### 6.1 Rendering Optimization

#### **React.memo**

Prevent re-renders when props haven't changed:

```typescript
const UserCard = React.memo(({ user }: { user: User }) => {
  return <div>{user.name}</div>;
});

// Only re-renders if `user` changes (shallow comparison)
```

**When to use:**
- Pure components (same props = same output)
- Components that render frequently
- Large lists of items

---

#### **useMemo**

Memoize expensive computations:

```typescript
function ProductList({ products, filters }: Props) {
  const filteredProducts = useMemo(() => {
    return products.filter(p =>
      p.category === filters.category &&
      p.price >= filters.minPrice &&
      p.price <= filters.maxPrice
    );
  }, [products, filters]); // Only recompute when these change

  return filteredProducts.map(p => <ProductCard key={p.id} product={p} />);
}
```

**When to use:**
- Expensive calculations (sorting, filtering large arrays)
- Creating objects/arrays passed as props (prevents referential inequality)

---

#### **useCallback**

Memoize callback functions:

```typescript
function TodoList({ todos }: Props) {
  const [filter, setFilter] = useState('all');

  // Without useCallback, this creates a new function on every render
  const handleToggle = useCallback((id: string) => {
    toggleTodo(id);
  }, []); // Empty deps = stable reference

  return todos.map(todo => (
    <TodoItem key={todo.id} todo={todo} onToggle={handleToggle} />
  ));
}
```

**When to use:**
- Callbacks passed to memoized children
- Dependencies in other hooks (useEffect, useMemo)

---

### 6.2 Lists & Keys

**Always use stable, unique keys:**

```typescript
// ❌ Bad: Index as key (breaks on reorder/insert)
{items.map((item, index) => <Item key={index} {...item} />)}

// ✅ Good: Unique ID
{items.map(item => <Item key={item.id} {...item} />)}

// ✅ Good: Composite key (if no ID)
{items.map(item => <Item key={`${item.category}-${item.name}`} {...item} />)}
```

**Why?**
- React uses keys to track elements during reconciliation
- Incorrect keys cause:
  - Lost component state
  - Unnecessary re-renders
  - Form input bugs

---

### 6.3 Code Splitting

**Load code only when needed:**

```typescript
import { lazy, Suspense } from 'react';

// Lazy load heavy components
const AdminPanel = lazy(() => import('./AdminPanel'));
const Chart = lazy(() => import('./Chart'));

function Dashboard() {
  const { user } = useAuth();

  return (
    <div>
      <h1>Dashboard</h1>

      {user.isAdmin && (
        <Suspense fallback={<Spinner />}>
          <AdminPanel />
        </Suspense>
      )}

      <Suspense fallback={<div>Loading chart...</div>}>
        <Chart data={data} />
      </Suspense>
    </div>
  );
}
```

**Benefits:**
- Smaller initial bundle
- Faster page loads
- Pay-as-you-go code loading

---

### 6.4 Virtual Scrolling

For **long lists** (1000+ items), render only visible items:

```typescript
import { useVirtualizer } from '@tanstack/react-virtual';

function VirtualList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 50, // Row height
  });

  return (
    <div ref={parentRef} style={{ height: '400px', overflow: 'auto' }}>
      <div style={{ height: `${virtualizer.getTotalSize()}px` }}>
        {virtualizer.getVirtualItems().map(virtualRow => (
          <div
            key={virtualRow.index}
            style={{
              position: 'absolute',
              top: 0,
              transform: `translateY(${virtualRow.start}px)`,
            }}
          >
            {items[virtualRow.index].name}
          </div>
        ))}
      </div>
    </div>
  );
}
```

---

## 7. Web Vitals & Metrics

### 7.1 Core Web Vitals

Google's **user-centric performance metrics**:

| Metric | What it Measures | Target | Impact |
|--------|------------------|--------|--------|
| **LCP** (Largest Contentful Paint) | Time to render largest element | < 2.5s | Perceived load speed |
| **INP** (Interaction to Next Paint) | Responsiveness to user input | < 200ms | Interactivity |
| **CLS** (Cumulative Layout Shift) | Visual stability (unexpected shifts) | < 0.1 | Visual stability |

---

### 7.2 Improving LCP

**Strategies:**
1. **Optimize images:**
   - Use modern formats (WebP, AVIF)
   - Add `width`/`height` attributes
   - Use `loading="lazy"` for below-the-fold images
   - Prioritize above-the-fold images: `<img fetchpriority="high" />`

2. **Reduce render-blocking resources:**
   - Defer non-critical JS: `<script defer>`
   - Inline critical CSS

3. **Use CDN** for static assets

4. **Server-side rendering (SSR)** for content-heavy pages

```typescript
// Next.js image optimization
import Image from 'next/image';

<Image
  src="/hero.jpg"
  alt="Hero"
  width={1200}
  height={600}
  priority // Preload LCP image
/>
```

---

### 7.3 Improving INP

**Strategies:**
1. **Debounce expensive operations** (search, filters)
2. **Use `useTransition`** for non-urgent updates
3. **Virtualize long lists** (react-virtual, react-window)
4. **Break up long tasks** (yield to main thread)

```typescript
// Debounced search input
const debouncedSearch = useDebounce(query, 300);

useEffect(() => {
  if (debouncedSearch) {
    fetchResults(debouncedSearch);
  }
}, [debouncedSearch]);
```

---

### 7.4 Improving CLS

**Strategies:**
1. **Reserve space for dynamic content:**
   ```css
   .skeleton {
     min-height: 200px; /* Prevents shift when content loads */
   }
   ```

2. **Use `aspect-ratio` for images/videos:**
   ```css
   img {
     aspect-ratio: 16 / 9;
     width: 100%;
     height: auto;
   }
   ```

3. **Avoid inserting content above existing content** (unless user-initiated)

4. **Load fonts efficiently:**
   ```css
   @font-face {
     font-family: 'CustomFont';
     font-display: swap; /* Show fallback until custom font loads */
   }
   ```

---

### 7.5 Monitoring Tools

- **Lighthouse:** Audits in Chrome DevTools
- **Web Vitals Extension:** Real-time metrics in browser
- **Vercel Analytics / Cloudflare Web Analytics:** Production monitoring
- **React DevTools Profiler:** Component render performance

```typescript
// Track Web Vitals programmatically
import { onCLS, onINP, onLCP } from 'web-vitals';

onCLS(console.log);
onINP(console.log);
onLCP(console.log);
```

---

## 8. Styling & UI Consistency

### 8.1 Scalable Styling Strategy

Choose **one approach** and stick to it:

| Approach | Pros | Cons | Best For |
|----------|------|------|----------|
| **Tailwind CSS** | Fast, small bundle, utility-first | Verbose HTML, learning curve | Rapid prototyping, design systems |
| **CSS Modules** | Scoped styles, standard CSS | Boilerplate, no dynamic theming | Component libraries |
| **Styled Components** | Dynamic styling, theming | Runtime cost, larger bundle | Design-heavy apps |
| **CSS-in-JS (Emotion)** | Framework-agnostic, powerful | Complexity | Advanced use cases |

---

### 8.2 Design Tokens

**Centralize design values:**

```typescript
// styles/tokens.ts
export const tokens = {
  colors: {
    primary: '#3b82f6',
    secondary: '#8b5cf6',
    danger: '#ef4444',
    text: '#1f2937',
    background: '#ffffff',
  },
  spacing: {
    xs: '0.25rem',
    sm: '0.5rem',
    md: '1rem',
    lg: '1.5rem',
    xl: '2rem',
  },
  typography: {
    fontFamily: 'Inter, sans-serif',
    sizes: {
      sm: '0.875rem',
      base: '1rem',
      lg: '1.125rem',
      xl: '1.25rem',
    },
  },
  shadows: {
    sm: '0 1px 2px rgba(0,0,0,0.05)',
    md: '0 4px 6px rgba(0,0,0,0.1)',
  },
};
```

**Use in Tailwind:**

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: tokens.colors,
      spacing: tokens.spacing,
    },
  },
};
```

---

### 8.3 Responsive Design

**Mobile-first approach:**

```css
/* Base styles (mobile) */
.card {
  padding: 1rem;
  font-size: 0.875rem;
}

/* Tablet */
@media (min-width: 768px) {
  .card {
    padding: 1.5rem;
    font-size: 1rem;
  }
}

/* Desktop */
@media (min-width: 1024px) {
  .card {
    padding: 2rem;
    font-size: 1.125rem;
  }
}
```

**With Tailwind:**

```tsx
<div className="p-4 text-sm md:p-6 md:text-base lg:p-8 lg:text-lg">
  Responsive card
</div>
```

---

## 9. Accessibility (a11y)

### 9.1 Semantic HTML

**Use the right element for the job:**

| Element | Purpose | Don't Use |
|---------|---------|-----------|
| `<button>` | Clickable actions | `<div onClick>` |
| `<nav>` | Navigation menus | `<div class="nav">` |
| `<main>` | Primary content | `<div class="main">` |
| `<article>` | Self-contained content | `<div class="post">` |
| `<label>` | Form labels | `<span>` next to input |

```tsx
// ❌ Bad
<div onClick={handleClick}>Click me</div>

// ✅ Good
<button onClick={handleClick}>Click me</button>
```

---

### 9.2 ARIA Attributes

**When semantic HTML isn't enough:**

```tsx
// Screen reader text
<button aria-label="Close modal">
  <XIcon /> {/* No visible text */}
</button>

// Live regions (announce updates)
<div role="status" aria-live="polite">
  {successMessage}
</div>

// Expandable sections
<button
  aria-expanded={isOpen}
  aria-controls="content-panel"
  onClick={() => setIsOpen(!isOpen)}
>
  Toggle
</button>
<div id="content-panel" hidden={!isOpen}>
  Content here
</div>
```

---

### 9.3 Keyboard Navigation

**Ensure all interactive elements are keyboard-accessible:**

```tsx
function Modal({ isOpen, onClose }: ModalProps) {
  const closeButtonRef = useRef<HTMLButtonElement>(null);

  // Focus close button when modal opens
  useEffect(() => {
    if (isOpen) {
      closeButtonRef.current?.focus();
    }
  }, [isOpen]);

  // Close on Escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };

    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
      return () => document.removeEventListener('keydown', handleEscape);
    }
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div role="dialog" aria-modal="true">
      <button ref={closeButtonRef} onClick={onClose}>
        Close
      </button>
      {/* Modal content */}
    </div>
  );
}
```

---

### 9.4 Color Contrast

**Ensure text is readable:**

- **WCAG AA (minimum):** 4.5:1 for normal text, 3:1 for large text
- **WCAG AAA (enhanced):** 7:1 for normal text, 4.5:1 for large text

**Tools:**
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- Chrome DevTools (Lighthouse accessibility audit)

---

## 10. Error Handling & Boundaries

### 10.1 Error Boundary Component

**Catch React errors gracefully:**

```typescript
import { Component, ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
  onError?: (error: Error, errorInfo: React.ErrorInfo) => void;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('ErrorBoundary caught:', error, errorInfo);
    this.props.onError?.(error, errorInfo);

    // Send to error tracking service
    // logErrorToService(error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback || (
        <div role="alert">
          <h2>Something went wrong</h2>
          <p>{this.state.error?.message}</p>
          <button onClick={() => this.setState({ hasError: false, error: null })}>
            Try again
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

// Usage
function App() {
  return (
    <ErrorBoundary fallback={<ErrorPage />}>
      <Dashboard />
    </ErrorBoundary>
  );
}
```

---

### 10.2 Async Error Handling

**Handle API failures gracefully:**

```typescript
function UserProfile({ userId }: Props) {
  const { data, error, isLoading, refetch } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
    retry: 3, // Retry failed requests
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
  });

  if (isLoading) return <Spinner />;

  if (error) {
    return (
      <ErrorMessage
        title="Failed to load profile"
        message={error.message}
        onRetry={refetch}
      />
    );
  }

  return <UserCard user={data} />;
}
```

---

### 10.3 Form Validation

**Validate early and show clear errors:**

```typescript
import { z } from 'zod';

const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

type LoginForm = z.infer<typeof loginSchema>;

function LoginForm() {
  const [errors, setErrors] = useState<Record<string, string>>({});

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);

    const result = loginSchema.safeParse({
      email: formData.get('email'),
      password: formData.get('password'),
    });

    if (!result.success) {
      const fieldErrors = result.error.flatten().fieldErrors;
      setErrors({
        email: fieldErrors.email?.[0] ?? '',
        password: fieldErrors.password?.[0] ?? '',
      });
      return;
    }

    // Submit form
    login(result.data);
  };

  return (
    <form onSubmit={handleSubmit}>
      <div>
        <label htmlFor="email">Email</label>
        <input id="email" name="email" type="email" required />
        {errors.email && <span role="alert">{errors.email}</span>}
      </div>

      <div>
        <label htmlFor="password">Password</label>
        <input id="password" name="password" type="password" required />
        {errors.password && <span role="alert">{errors.password}</span>}
      </div>

      <button type="submit">Log in</button>
    </form>
  );
}
```

---

## 11. Testing Strategy

### 11.1 Testing Pyramid

| Test Type | Coverage | Speed | Cost | Tools |
|-----------|----------|-------|------|-------|
| **Unit** | 70% | Fast | Low | Vitest, Jest |
| **Integration** | 20% | Medium | Medium | React Testing Library |
| **E2E** | 10% | Slow | High | Playwright, Cypress |

---

### 11.2 Unit Testing (Vitest + React Testing Library)

**Test user behavior, not implementation:**

```typescript
import { render, screen, fireEvent } from '@testing-library/react';
import { expect, test } from 'vitest';
import Counter from './Counter';

test('increments counter on button click', () => {
  render(<Counter />);

  const button = screen.getByRole('button', { name: /increment/i });
  const count = screen.getByText(/count: 0/i);

  expect(count).toBeInTheDocument();

  fireEvent.click(button);
  expect(screen.getByText(/count: 1/i)).toBeInTheDocument();
});
```

**Custom hook testing:**

```typescript
import { renderHook, act } from '@testing-library/react';
import { expect, test } from 'vitest';
import useCounter from './useCounter';

test('useCounter increments correctly', () => {
  const { result } = renderHook(() => useCounter(0));

  expect(result.current.count).toBe(0);

  act(() => {
    result.current.increment();
  });

  expect(result.current.count).toBe(1);
});
```

---

### 11.3 Integration Testing

**Test multiple components working together:**

```typescript
import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { expect, test, vi } from 'vitest';
import UserProfile from './UserProfile';

test('displays user profile after loading', async () => {
  const mockFetch = vi.fn().mockResolvedValue({
    id: '1',
    name: 'Alice',
    email: 'alice@example.com',
  });

  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });

  render(
    <QueryClientProvider client={queryClient}>
      <UserProfile userId="1" fetchUser={mockFetch} />
    </QueryClientProvider>
  );

  expect(screen.getByText(/loading/i)).toBeInTheDocument();

  await waitFor(() => {
    expect(screen.getByText('Alice')).toBeInTheDocument();
  });

  expect(mockFetch).toHaveBeenCalledWith('1');
});
```

---

### 11.4 E2E Testing (Playwright)

**Test critical user flows:**

```typescript
import { test, expect } from '@playwright/test';

test('user can complete checkout', async ({ page }) => {
  await page.goto('http://localhost:3000');

  // Add item to cart
  await page.getByRole('button', { name: /add to cart/i }).click();

  // Go to checkout
  await page.getByRole('link', { name: /cart/i }).click();
  await page.getByRole('button', { name: /checkout/i }).click();

  // Fill form
  await page.fill('input[name="email"]', 'test@example.com');
  await page.fill('input[name="address"]', '123 Main St');

  // Submit order
  await page.getByRole('button', { name: /place order/i }).click();

  // Verify success
  await expect(page.getByText(/order confirmed/i)).toBeVisible();
});
```

---

### 11.5 Testing Best Practices

✅ **Do:**
- Test user-facing behavior, not implementation details
- Use data-testid only as a last resort (prefer accessible queries)
- Mock external dependencies (APIs, timers)
- Keep tests isolated (no shared state)

❌ **Avoid:**
- Testing internal state or methods
- Relying on CSS classes or HTML structure
- Brittle tests that break on minor UI changes

---

## 12. Naming Conventions

### 12.1 File Naming

| File Type | Convention | Example |
|-----------|------------|---------|
| **Components** | PascalCase | `UserProfile.tsx`, `ButtonGroup.tsx` |
| **Hooks** | camelCase, `use` prefix | `useAuth.ts`, `useDebounce.ts` |
| **Utils** | camelCase | `formatDate.ts`, `validateEmail.ts` |
| **Constants** | camelCase or UPPER_SNAKE | `routes.ts`, `API_BASE_URL.ts` |
| **Types** | PascalCase | `User.ts`, `ApiResponse.ts` |

---

### 12.2 Variable Naming

| Type | Convention | Example |
|------|------------|---------|
| **Boolean** | `is`, `has`, `should` prefix | `isLoading`, `hasError`, `shouldRender` |
| **Arrays** | Plural noun | `users`, `products`, `items` |
| **Functions** | Verb + noun | `fetchUser`, `handleClick`, `validateForm` |
| **Event handlers** | `handle` or `on` prefix | `handleSubmit`, `onClose` |
| **Constants** | UPPER_SNAKE_CASE | `MAX_RETRIES`, `API_TIMEOUT` |

---

### 12.3 Component Prop Naming

```typescript
interface ButtonProps {
  // Booleans: is/has/should prefix
  isLoading?: boolean;
  isDisabled?: boolean;

  // Event handlers: on* prefix
  onClick?: () => void;
  onHover?: () => void;

  // Data: descriptive nouns
  label: string;
  icon?: ReactNode;

  // Enums: descriptive names
  variant?: 'primary' | 'secondary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
}
```

---

## 13. Project Structure

### 13.1 Recommended Folder Structure

```
src/
├── app/                    # App shell & providers
│   ├── App.tsx
│   ├── Providers.tsx
│   ├── ErrorBoundary.tsx
│   └── Layout.tsx
│
├── routes/                 # Route-level components
│   ├── dashboard/
│   │   ├── DashboardPage.tsx
│   │   └── index.ts
│   ├── login/
│   │   └── LoginPage.tsx
│   └── NotFound.tsx
│
├── components/             # Reusable UI components
│   ├── common/             # Button, Input, Modal
│   ├── layout/             # Header, Sidebar, Footer
│   ├── feedback/           # Toast, Spinner, Alert
│   └── data-display/       # Table, Card, List
│
├── hooks/                  # Custom React hooks
│   ├── useAuth.ts
│   ├── useDebounce.ts
│   └── useLocalStorage.ts
│
├── services/               # API clients & external services
│   ├── api/
│   │   ├── users.ts
│   │   └── posts.ts
│   └── auth.ts
│
├── utils/                  # Pure utility functions
│   ├── formatDate.ts
│   ├── validateEmail.ts
│   └── cn.ts               # className utility (clsx)
│
├── types/                  # TypeScript type definitions
│   ├── user.ts
│   ├── post.ts
│   └── api.ts
│
├── constants/              # Static configuration
│   ├── routes.ts
│   ├── api.ts
│   └── roles.ts
│
├── styles/                 # Global styles & design tokens
│   ├── globals.css
│   └── tokens.ts
│
└── index.tsx               # Entry point
```

---

### 13.2 Component Co-location

**Keep related files together:**

```
components/
└── UserProfile/
    ├── UserProfile.tsx       # Main component
    ├── UserProfile.test.tsx  # Tests
    ├── UserProfile.module.css # Styles (if CSS Modules)
    ├── UserAvatar.tsx        # Sub-component (not reusable elsewhere)
    └── index.ts              # Barrel export
```

---

### 13.3 Barrel Exports

**Simplify imports:**

```typescript
// components/common/index.ts
export { Button } from './Button';
export { Input } from './Input';
export { Modal } from './Modal';

// Usage
import { Button, Input, Modal } from '@/components/common';
```

> **⚠️ Warning:** Barrel exports can hurt tree-shaking. Use sparingly for frequently imported groups.

---

## 14. Clean Code Practices

### 14.1 Readable Code

**Self-documenting code > comments:**

```typescript
// ❌ Bad
const d = new Date().getTime(); // Get current timestamp
const x = d + 86400000; // Add 1 day

// ✅ Good
const now = Date.now();
const oneDayInMs = 24 * 60 * 60 * 1000;
const tomorrow = now + oneDayInMs;
```

---

### 14.2 Avoid Deep Nesting

**Flatten JSX and control flow:**

```typescript
// ❌ Bad
function Dashboard() {
  if (user) {
    if (user.isActive) {
      if (user.subscriptionLevel === 'premium') {
        return <PremiumDashboard user={user} />;
      } else {
        return <FreeDashboard user={user} />;
      }
    } else {
      return <InactiveBanner />;
    }
  } else {
    return <LoginPrompt />;
  }
}

// ✅ Good
function Dashboard() {
  if (!user) return <LoginPrompt />;
  if (!user.isActive) return <InactiveBanner />;

  const isPremium = user.subscriptionLevel === 'premium';
  return isPremium ? <PremiumDashboard user={user} /> : <FreeDashboard user={user} />;
}
```

---

### 14.3 Small, Focused Functions

**Functions should do one thing:**

```typescript
// ❌ Bad: Too many responsibilities
function processUser(user: User) {
  const validated = validateUser(user);
  const normalized = normalizeUser(validated);
  const saved = saveUser(normalized);
  sendEmail(saved.email);
  logActivity(saved.id);
  return saved;
}

// ✅ Good: Separate concerns
function validateAndSaveUser(user: User): User {
  const validated = validateUser(user);
  const normalized = normalizeUser(validated);
  return saveUser(normalized);
}

function notifyUser(user: User) {
  sendEmail(user.email);
  logActivity(user.id);
}
```

---

### 14.4 Meaningful Comments

**Comment the "why", not the "what":**

```typescript
// ❌ Bad: Obvious comment
// Set loading to true
setLoading(true);

// ✅ Good: Explains reasoning
// Fetch user first because permissions depend on user role
const user = await fetchUser();
const permissions = await fetchPermissions(user.role);

// ✅ Good: Documents edge case
// Safari requires a manual click event to play audio
audioElement.play().catch(() => {
  showPlayButton(); // Fallback to manual play
});
```

---

## 15. Professional Frontend Mindset

### 15.1 Think in Systems, Not Pages

- **Build reusable components**, not one-off solutions
- **Design design systems**: Consistent spacing, colors, typography
- **Component libraries**: Button, Input, Modal variants

---

### 15.2 Communicate Trade-offs

When making technical decisions, articulate:
- **Performance impact:** "Adds 50KB to bundle"
- **Maintenance cost:** "Requires updating 3 services"
- **Alternative approaches:** "We could also use X, but it's less battle-tested"

---

### 15.3 Continuous Improvement

- **Refactor incrementally:** Don't wait for "the perfect time"
- **Learn from production:** Monitor errors, performance metrics
- **Stay updated:** Follow React RFCs, framework changelogs

---

### 15.4 Collaborate Effectively

- **Code reviews:** Be constructive, not critical
- **Documentation:** Write README files for complex features
- **Knowledge sharing:** Pair program, write internal guides

---

## Summary: The Complete Frontend Engineer

A strong frontend engineer:
- ✅ Writes **type-safe, maintainable code** with TypeScript
- ✅ Embraces **modern React patterns** (Suspense, Server Components, Transitions)
- ✅ Distinguishes **server state from client state**
- ✅ Optimizes for **Web Vitals** (LCP, INP, CLS)
- ✅ Tests **user behavior**, not implementation details
- ✅ Follows **consistent naming conventions**
- ✅ Builds **accessible, performant UIs**
- ✅ Handles **errors gracefully**
- ✅ Structures projects for **long-term scalability**

---

**Next Steps:**
1. **Audit your codebase** against this reference
2. **Set up tooling** (Prettier, ESLint, TypeScript strict mode)
3. **Implement Error Boundaries** in your app
4. **Measure Web Vitals** in production
5. **Write tests** for critical flows

---

**Maintained by:** Full-Stack Development Team
**Contributing:** Submit improvements via pull request
**License:** Internal use only

---

*This document is a living reference. Update it as best practices evolve.*
