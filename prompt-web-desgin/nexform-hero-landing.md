# Nexform° — Full-Screen Hero Landing Page

Build a full-screen hero landing page for an innovation studio called **"Nexform°"** using **React, TypeScript, Vite, and Tailwind CSS**. Here is every detail.

---

## COLORS & THEME

The entire page uses a pure black background: `background: #000000`. All text is white (`#ffffff`). There are no other accent colors — the visual interest comes entirely from the 3D video background and typography.

In `index.css`:

```css
:root {
  --font-sans: 'Inter', 'Helvetica Neue', Arial, sans-serif;
}
body {
  background: #000;
  color: #fff;
  font-family: var(--font-sans);
  cursor: none; /* hide default cursor — custom cursor is used */
}
```

---

## FONTS

Load Inter from Google Fonts in `index.html`:

```html
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600&display=swap" rel="stylesheet" />
```

The entire page uses `font-family: var(--font-sans)`. Font weights used:

- Logo: `font-weight: 500`
- Nav links: `font-weight: 400`
- Hero body text: `font-weight: 400`
- Bottom bar labels: `font-weight: 400`, `letter-spacing: 0.08em`, uppercase

---

## BACKGROUND VIDEO (mouse-scrub controlled)

- A full-screen `<video>` element: `position: fixed; inset: 0; width: 100%; height: 100%; z-index: 0; object-fit: cover; object-position: center center`.
- Video source URL: `https://pub-86dc5b5484314368ac5436a674b0d919.r2.dev/prompts%20(i've%20added%20them%20to%20the%20motionsites)/Innovation%20Studio.mp4`
- The video is `muted`, `playsInline`, `preload="auto"`. It does **NOT** autoplay.
- The video scrubs forward/backward based on horizontal mouse movement. Add a `mousemove` listener on `window`. Track `prevX`, compute `delta = currentX - prevX`. Convert to time offset: `(delta / window.innerWidth) * SENSITIVITY * video.duration` where `SENSITIVITY = 0.9`. Clamp `targetTime` between `0` and `video.duration`. Assign `video.currentTime` directly and use an `onSeeked` handler to queue the next seek if `targetTime` has drifted, preventing seek-flooding.
- The 3D video content is a parametric undulating sphere/dot-grid surface — gray spheres arranged in a wave pattern on black. The video also includes floating 3D objects (a metallic arrow, an abstract shape) that drift into/out of frame as the user scrubs. No video controls, no UI chrome.

---

## CUSTOM CURSOR

Replace the default system cursor with a custom two-part element that follows the mouse:

**Structure (rendered in a `<div>` with `position: fixed; pointer-events: none; z-index: 100`):**

1. **Glass sphere**: A `div`, `~90px × 90px`, `border-radius: 50%`, with a blurred glass-diffusion appearance:

   ```css
   background: radial-gradient(circle at 38% 38%, rgba(200,200,200,0.55), rgba(120,120,120,0.15));
   backdrop-filter: blur(8px);
   box-shadow: inset 0 1px 2px rgba(255,255,255,0.4), 0 4px 24px rgba(0,0,0,0.4);
   ```

   Centered on the cursor position via `transform: translate(-50%, -50%)`.

2. **Dotted ring SVG**: An `<svg>` element, `~160px × 160px`, centered on the same cursor position. Draw a `<circle>` at `cx="80" cy="80" r="72"` with `stroke="white"`, `strokeWidth="1"`, `fill="none"`, `strokeDasharray="2 8"`, `strokeLinecap="round"`. The ring slowly rotates: add a CSS animation `@keyframes spin { to { transform: rotate(360deg); } }` applied as `animation: spin 12s linear infinite` on the SVG.

**Movement**: Use `mousemove` on `window` to set a `cursorPos` state `{ x, y }`. Apply `left: cursorPos.x; top: cursorPos.y` via inline style. Add a `0.12s` CSS transition on `left` and `top` for a smooth lag effect: `transition: left 0.12s ease-out, top 0.12s ease-out`.

---

## NAVBAR (fixed, z-index: 20)

Fixed to top, full width. Background: transparent (page bg shows through). Padding: `px-8 py-5`. Flex row, `justify-between`, `items-center`.

**Logo (left):**
Flex row with `gap-2`. Text `"Nexform°"` (use the degree symbol `°` directly in JSX). Font size `text-[18px] sm:text-[20px]`, `font-weight: 500`, white, `letter-spacing: -0.01em`, `font-family: var(--font-sans)`.

**Center nav links (visible on md+, hidden on mobile):**
Flex row, `gap-10`. Two links:

- `"Studios—"` (em dash `—` appended directly to the word, no space before it)
- `"Labs"`

Font size `text-[15px]`, `font-weight: 400`, white, `opacity-80`. Hover: `opacity-100`, `transition-opacity duration-200`. The `"Studios—"` link conveys it has a submenu but no dropdown is required — it is a plain anchor.

**Menu button (right):**
A circular `<button>`, `w-9 h-9`, `border border-white/40 rounded-full`, `flex items-center justify-center`. Inside: three horizontal lines each `w-4 h-[1.5px] bg-white`, spaced with `gap-[3.5px]` in a flex column. On toggle, animate to an `×` shape: top bar rotates `45deg` and translates `+5px Y`, middle bar opacity `0`, bottom bar rotates `-45deg` and translates `-5px Y`. All transitions `duration-250`.

**Mobile overlay (z-index: 19):**
`position: fixed; inset: 0; background: rgba(0,0,0,0.97); backdrop-filter: blur(12px)`. Flex column, `justify-center`, `px-10`, `gap-10`. Links: `"Studios"`, `"Labs"` at `text-[36px] font-medium`. Fades in with `opacity 0→1` and `translateY(12px)→0` over `0.3s`. Hidden on `md+`.

---

## HERO SECTION (z-index: 10)

`position: relative; height: 100vh; display: flex; align-items: center`. Horizontal padding: `pl-[36%] pr-8 md:pl-[34%]`. Overflow hidden.

The hero content sits in the right ~60% of the viewport (the left ~34% shows the 3D cursor element against the video with nothing blocking it).

**Content container** (`max-w-[620px]`, relative, `z-index: 10`):

### Slide system

There are **2 slides** that auto-advance every **5 seconds**. Implement a `useInterval` hook. Track `activeSlide` (0 or 1). On change, the outgoing slide fades out (`opacity: 0, translateY(-6px)`) and the incoming slide fades in (`opacity: 0→1, translateY(6px)→0`) over `0.5s ease`.

**Slide 0:**

- Headline: `"Development of "` + `<span className="underline underline-offset-4 decoration-1">"spatial engines"</span>` + `" for constructing and animating immersive experiences — Procedural systems for generating and evolving visual forms."`
- CTA link: `"View Case Study—"`

**Slide 1:**

- Headline: `"Exploration of "` + `<span className="underline underline-offset-4 decoration-1">"neural networks"</span>` + `" for designing and rendering digital interfaces — Algorithmic frameworks for composing and refining aesthetics."`
- CTA link: `"Browse Projects—"`

**Headline styling:** `font-size: clamp(22px, 2.6vw, 38px)`, `line-height: 1.28`, `font-weight: 400`, `color: white`, `margin-bottom: 20px`.

**CTA link styling:** `font-size: text-[15px]`, `font-weight: 400`, white, `opacity-70`. Hover: `opacity-100`, `transition-opacity duration-150`. No underline by default. The `—` em dash is appended inline (no space before it). `margin-bottom: 28px`.

### Slide dots

Flex row, `gap-[6px]`, `margin-top: 0` (directly below the CTA). Each dot: `w-[6px] h-[6px] rounded-full`. Active dot: `bg-white opacity-100`. Inactive dot: `bg-white opacity-30`. `transition: opacity 0.3s`.

---

## BOTTOM BAR (fixed, z-index: 10, bottom: 0)

`position: fixed; bottom: 0; left: 0; right: 0`. Padding: `px-8 pb-7`. Three columns using `display: grid; grid-template-columns: 1fr 1fr 1fr`.

**Left column:**

- Top: `"2"` — `text-[11px]`, white, `opacity-50`, `margin-bottom: 10px`.
- Below: A short paragraph — `font-size: text-[11px]`, `line-height: 1.55`, `max-width: 380px`, `opacity-60`:
  > `"Computational methods for streamlining industrial workflows and minimizing resource usage through "` + `<a className="underline underline-offset-2 decoration-white/50">"algorithmic refinement"</a>` + `" as an emerging approach in interface architecture. Applications across digital infrastructure."`

**Center column:**

- `text-align: center`. Single character: `"H"` — `text-[11px]`, white, `opacity-30`.

**Right column:**

- `text-align: right`. Two stacked labels (flex column, `items-end`, `gap-1`):
  - `"DESIGN ENGINEER"` — `text-[10px]`, `letter-spacing: 0.1em`, `text-transform: uppercase`, white, `opacity-40`.
  - `"DYNAMIC INTERFACE ENGINE"` — `text-[10px]`, `letter-spacing: 0.1em`, `text-transform: uppercase`, white, `opacity-40`.
- Also in the right column, `"W"` at `text-[11px]`, white, `opacity-30`, positioned above the two labels (or use absolute positioning at `bottom: 28px right: 32px` for `W`).

---

## LAYOUT SUMMARY

```
┌─────────────────────────────────────────────────┐
│ Nexform°           Studios—    Labs         [☰]  │  ← fixed navbar
├─────────────────────────────────────────────────┤
│                                                 │
│  [cursor sphere]   Development of spatial       │
│  [dotted ring ]    engines for constructing     │  ← 100vh, video bg
│                    and animating immersive...   │
│                    View Case Study—             │
│                    ● ○                          │
│                                                 │
├─────────────────────────────────────────────────┤
│ 2           H                               W   │  ← fixed bottom bar
│ Computational                  DESIGN ENGINEER  │
│ methods...              DYNAMIC INTERFACE ENGINE│
└─────────────────────────────────────────────────┘
```

---

## DEPENDENCIES

Only React, ReactDOM, Tailwind CSS, and Vite. No other UI libraries or animation libraries. All animations are CSS transitions and `@keyframes`. No Framer Motion, GSAP, or Three.js.
