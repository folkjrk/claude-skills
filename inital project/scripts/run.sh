#!/bin/bash
# =============================================================================
# Project Runner Script
# Based on PROJECT_MANUAL.md
# =============================================================================

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

print_header() {
  echo -e "\n${BOLD}${CYAN}==> $1${RESET}"
}

print_success() {
  echo -e "${GREEN}✔ $1${RESET}"
}

print_warn() {
  echo -e "${YELLOW}⚠ $1${RESET}"
}

print_error() {
  echo -e "${RED}✘ $1${RESET}"
}

print_divider() {
  echo -e "${CYAN}────────────────────────────────────────────────────────${RESET}"
}

usage() {
  echo ""
  print_divider
  echo -e "  ${BOLD}Project Runner${RESET}  ·  ${CYAN}./scripts/run.sh <command> [options]${RESET}"
  print_divider

  echo ""
  echo -e "  ${BOLD}Development${RESET}"
  echo -e "    ${CYAN}setup${RESET}              Full initial setup (install deps + create .env)"
  echo -e "    ${CYAN}install${RESET}            Install npm dependencies"
  echo -e "    ${CYAN}dev${RESET}                Start dev server  →  http://localhost:3000"

  echo ""
  echo -e "  ${BOLD}Production${RESET}"
  echo -e "    ${CYAN}build${RESET}              Compile SSR production bundle  →  ./build"
  echo -e "    ${CYAN}start${RESET}              Serve the production build (requires 'build' first)"

  echo ""
  echo -e "  ${BOLD}Quality${RESET}"
  echo -e "    ${CYAN}typecheck${RESET}          Run TypeScript type check"
  echo -e "    ${CYAN}test${RESET}               Run Jest test suite"
  echo -e "    ${CYAN}test:watch${RESET}         Run Jest in interactive watch mode"
  echo -e "    ${CYAN}test:coverage${RESET}      Run Jest and generate coverage report  →  ./coverage"
  echo -e "    ${CYAN}ci${RESET}                 Full CI pipeline: typecheck → test"

  echo ""
  echo -e "  ${BOLD}Docker${RESET}"
  echo -e "    ${CYAN}docker:build${RESET}       Build Docker image"
  echo -e "    ${CYAN}docker:run${RESET}         Run Docker container"
  echo -e "    ${CYAN}docker:build-run${RESET}   Build image then run container immediately"

  echo ""
  echo -e "  ${BOLD}Docker options${RESET}  (used with docker:* commands)"
  echo -e "    ${YELLOW}--tag${RESET}     <name>   Image tag            (default: cop-acp-web)"
  echo -e "    ${YELLOW}--version${RESET} <ver>    App version build arg (default: 1.0.0)"
  echo -e "    ${YELLOW}--api-url${RESET} <url>    VITE_API_URL at runtime"
  echo -e "    ${YELLOW}--port${RESET}    <port>   Host port mapping     (default: 3000)"

  echo ""
  echo -e "  ${BOLD}Feature (UFMP)${RESET}"
  echo -e "    ${CYAN}feature <name>${RESET}     Scaffold a new feature module in app/features/<name>/"

  echo ""
  echo -e "  ${BOLD}Help${RESET}"
  echo -e "    ${CYAN}help${RESET}               Show this message"
  echo -e "    ${CYAN}help <command>${RESET}     Show detailed help for a specific command"

  echo ""
  echo -e "  ${BOLD}Examples${RESET}"
  echo -e "    ${CYAN}./scripts/run.sh setup${RESET}"
  echo -e "    ${CYAN}./scripts/run.sh dev${RESET}"
  echo -e "    ${CYAN}./scripts/run.sh feature payment${RESET}"
  echo -e "    ${CYAN}./scripts/run.sh test:coverage${RESET}"
  echo -e "    ${CYAN}./scripts/run.sh docker:build --tag my-app --version 2.0.0${RESET}"
  echo -e "    ${CYAN}./scripts/run.sh docker:run   --tag my-app --api-url https://api.example.com${RESET}"
  echo -e "    ${CYAN}./scripts/run.sh docker:build-run --version 1.5.0 --api-url https://api.example.com${RESET}"
  echo ""
  print_divider
  echo ""
}

usage_command() {
  local cmd="$1"
  echo ""
  print_divider
  case "$cmd" in
    setup)
      echo -e "  ${BOLD}setup${RESET} — Full initial project setup  (follows PROJECT_MANUAL.md)"
      print_divider
      echo ""
      echo -e "  Runs in order:"
      echo -e "    1. Checks that Node.js and npm are installed"
      echo -e "    2. Creates directory structure"
      echo -e "       app/{routes,components,hooks,stores,api,i18n/locales,utils,"
      echo -e "            config,provider,data,assets}  public/  types/  __mocks__/"
      echo -e "    3. Scaffolds config files (skips any that already exist)"
      echo -e "       vite.config.ts  react-router.config.ts  tailwind.config.ts"
      echo -e "       postcss.config.js  tsconfig.json  babel.config.cjs"
      echo -e "       babel-plugin-import-meta-transform.cjs  jest.config.mjs"
      echo -e "       jest.setup.js  __mocks__/fileMock.js  app-start.sh  .env"
      echo -e "    4. Scaffolds source files (skips any that already exist)"
      echo -e "       app/config.ts  app/types.ts  app/constants.tsx  app/field-lengths.ts"
      echo -e "       app/app.css  app/root.tsx  app/stores/index.ts  app/stores/auth.ts"
      echo -e "       app/i18n/index.ts  app/i18n/locales/{en,th}.json  app/hooks/isClient.ts"
      echo -e "       app/routes/_index.tsx  app/routes/login.tsx  app/routes/error.tsx  app/routes/\$.tsx"
      echo -e "    5. Runs ${CYAN}npm install${RESET} (if package.json exists)"
      echo ""
      echo -e "  Existing files are never overwritten — safe to re-run."
      echo ""
      echo -e "  ${BOLD}Usage:${RESET}  ./scripts/run.sh setup"
      echo -e "  ${BOLD}Next:${RESET}   Edit ${CYAN}.env${RESET} with real values, then run ${CYAN}./scripts/run.sh dev${RESET}"
      ;;
    dev)
      echo -e "  ${BOLD}dev${RESET} — Start the development server"
      print_divider
      echo ""
      echo -e "  Starts Vite in development mode with HMR."
      echo -e "  Automatically checks for ${CYAN}node_modules${RESET} and ${CYAN}.env${RESET} before starting."
      echo ""
      echo -e "  ${BOLD}URL:${RESET}    http://localhost:3000"
      echo -e "  ${BOLD}Usage:${RESET}  ./scripts/run.sh dev"
      ;;
    build)
      echo -e "  ${BOLD}build${RESET} — Build for production"
      print_divider
      echo ""
      echo -e "  Compiles the SSR production bundle using ${CYAN}npm run build${RESET}."
      echo -e "  Output goes to ${CYAN}./build${RESET}."
      echo ""
      echo -e "  ${BOLD}Usage:${RESET}  ./scripts/run.sh build"
      echo -e "  ${BOLD}Next:${RESET}   ./scripts/run.sh start"
      ;;
    start)
      echo -e "  ${BOLD}start${RESET} — Serve the production build"
      print_divider
      echo ""
      echo -e "  Requires the ${CYAN}./build${RESET} directory to exist."
      echo -e "  Run ${CYAN}build${RESET} first if it does not."
      echo ""
      echo -e "  ${BOLD}Usage:${RESET}  ./scripts/run.sh start"
      ;;
    typecheck)
      echo -e "  ${BOLD}typecheck${RESET} — Run TypeScript type check"
      print_divider
      echo ""
      echo -e "  Runs ${CYAN}tsc --noEmit${RESET} across the entire project."
      echo -e "  Does not produce output files."
      echo ""
      echo -e "  ${BOLD}Usage:${RESET}  ./scripts/run.sh typecheck"
      ;;
    test)
      echo -e "  ${BOLD}test${RESET} — Run Jest test suite"
      print_divider
      echo ""
      echo -e "  Runs all tests once and exits."
      echo ""
      echo -e "  ${BOLD}Usage:${RESET}  ./scripts/run.sh test"
      echo -e "  ${BOLD}See also:${RESET} test:watch  test:coverage"
      ;;
    test:watch)
      echo -e "  ${BOLD}test:watch${RESET} — Jest interactive watch mode"
      print_divider
      echo ""
      echo -e "  Re-runs tests on file changes. Best for active development."
      echo ""
      echo -e "  ${BOLD}Usage:${RESET}  ./scripts/run.sh test:watch"
      ;;
    test:coverage)
      echo -e "  ${BOLD}test:coverage${RESET} — Jest with coverage report"
      print_divider
      echo ""
      echo -e "  Runs all tests and generates an HTML coverage report."
      echo -e "  Output: ${CYAN}./coverage/lcov-report/index.html${RESET}"
      echo ""
      echo -e "  ${BOLD}Usage:${RESET}  ./scripts/run.sh test:coverage"
      ;;
    ci)
      echo -e "  ${BOLD}ci${RESET} — CI pipeline"
      print_divider
      echo ""
      echo -e "  Runs in order:"
      echo -e "    1. ${CYAN}typecheck${RESET}  — TypeScript check"
      echo -e "    2. ${CYAN}test${RESET}       — Full test suite"
      echo ""
      echo -e "  Exits with a non-zero code if either step fails."
      echo ""
      echo -e "  ${BOLD}Usage:${RESET}  ./scripts/run.sh ci"
      ;;
    docker:build)
      echo -e "  ${BOLD}docker:build${RESET} — Build Docker image"
      print_divider
      echo ""
      echo -e "  Builds the Docker image using the project Dockerfile."
      echo ""
      echo -e "  ${BOLD}Options:${RESET}"
      echo -e "    ${YELLOW}--tag${RESET}     <name>   Image name  (default: cop-acp-web)"
      echo -e "    ${YELLOW}--version${RESET} <ver>    APP_VERSION build arg (default: 1.0.0)"
      echo ""
      echo -e "  ${BOLD}Usage:${RESET}  ./scripts/run.sh docker:build --tag my-app --version 2.0.0"
      ;;
    docker:run)
      echo -e "  ${BOLD}docker:run${RESET} — Run Docker container"
      print_divider
      echo ""
      echo -e "  Starts a container from the built image."
      echo -e "  The container is removed automatically on exit (${CYAN}--rm${RESET})."
      echo ""
      echo -e "  ${BOLD}Options:${RESET}"
      echo -e "    ${YELLOW}--tag${RESET}     <name>   Image name  (default: cop-acp-web)"
      echo -e "    ${YELLOW}--api-url${RESET} <url>    Sets VITE_API_URL inside the container"
      echo -e "    ${YELLOW}--port${RESET}    <port>   Host port   (default: 3000)"
      echo ""
      echo -e "  ${BOLD}Usage:${RESET}  ./scripts/run.sh docker:run --tag my-app --api-url https://api.example.com"
      ;;
    docker:build-run)
      echo -e "  ${BOLD}docker:build-run${RESET} — Build then run"
      print_divider
      echo ""
      echo -e "  Combines ${CYAN}docker:build${RESET} and ${CYAN}docker:run${RESET} in one step."
      echo -e "  Accepts all options from both commands."
      echo ""
      echo -e "  ${BOLD}Usage:${RESET}  ./scripts/run.sh docker:build-run --version 1.5.0 --api-url https://api.example.com"
      ;;
    *)
      echo -e "  ${RED}No detailed help for '${cmd}'.${RESET}  Run ${CYAN}./scripts/run.sh help${RESET} for the full list."
      ;;
  esac
  echo ""
  print_divider
  echo ""
}

check_node() {
  if ! command -v node &>/dev/null; then
    print_error "Node.js is not installed. Please install Node.js first."
    exit 1
  fi
  print_success "Node.js $(node -v) found"
}

check_npm() {
  if ! command -v npm &>/dev/null; then
    print_error "npm is not installed."
    exit 1
  fi
  print_success "npm $(npm -v) found"
}

check_docker() {
  if ! command -v docker &>/dev/null; then
    print_error "Docker is not installed or not running."
    exit 1
  fi
  print_success "Docker found"
}

check_env() {
  if [ ! -f ".env" ]; then
    print_warn ".env file not found. Creating from template..."
    cat > .env <<'EOF'
VITE_API_URL=http://localhost:8080/api
VITE_COGNITO_ENDPOINT=https://<your-cognito-domain>.amazoncognito.com
VITE_COGNITO_AUTH_CLIENT_ID=<client-id>
VITE_COGNITO_AUTH_REDIRECT_URL=http://localhost:8080/api/auth/cb
VITE_COGNITO_LOGOUT_URL=https://<your-cognito-domain>.amazoncognito.com/logout
VITE_IS_DEBUG=true
EOF
    print_warn ".env created with placeholder values. Please update before running."
  else
    print_success ".env file exists"
  fi
}

check_node_modules() {
  if [ ! -d "node_modules" ]; then
    print_warn "node_modules not found. Running npm install..."
    npm install
  else
    print_success "node_modules found"
  fi
}

cmd_install() {
  print_header "Installing dependencies"
  check_node
  check_npm
  npm install
  print_success "Dependencies installed"
}

cmd_dev() {
  print_header "Starting development server"
  check_node_modules
  check_env
  echo -e "  ${CYAN}URL:${RESET} http://localhost:3000"
  npm run dev
}

cmd_build() {
  print_header "Building for production"
  check_node_modules
  npm run build
  print_success "Build complete → ./build"
}

cmd_start() {
  print_header "Serving production build"
  if [ ! -d "build" ]; then
    print_error "No build directory found. Run '$0 build' first."
    exit 1
  fi
  npm run start
}

cmd_typecheck() {
  print_header "Running TypeScript type check"
  check_node_modules
  npm run typecheck
  print_success "Type check passed"
}

cmd_test() {
  print_header "Running tests"
  check_node_modules
  npm run test
}

cmd_test_watch() {
  print_header "Running tests in watch mode"
  check_node_modules
  npm run test:watch
}

cmd_test_coverage() {
  print_header "Running tests with coverage"
  check_node_modules
  npm run test:coverage
  print_success "Coverage report → ./coverage"
}

cmd_docker_build() {
  local tag="${DOCKER_TAG:-cop-acp-web}"
  local version="${APP_VERSION:-1.0.0}"

  print_header "Building Docker image"
  check_docker
  echo -e "  ${CYAN}Image:${RESET}   $tag"
  echo -e "  ${CYAN}Version:${RESET} $version"

  docker build \
    --build-arg APP_VERSION="$version" \
    -t "$tag" \
    .

  print_success "Docker image built: $tag"
}

cmd_docker_run() {
  local tag="${DOCKER_TAG:-cop-acp-web}"
  local port="${HOST_PORT:-3000}"
  local api_url="${API_URL:-http://localhost:8080/api}"

  print_header "Running Docker container"
  check_docker
  echo -e "  ${CYAN}Image:${RESET}   $tag"
  echo -e "  ${CYAN}Port:${RESET}    $port → 3000"
  echo -e "  ${CYAN}API URL:${RESET} $api_url"

  docker run --rm \
    -p "${port}:3000" \
    -e VITE_API_URL="$api_url" \
    "$tag" \
    /app-start.sh
}

cmd_docker_build_run() {
  cmd_docker_build
  cmd_docker_run
}

scaffold_dirs() {
  print_header "Creating directory structure"
  local dirs=(
    "app/routes"
    "app/components/__tests__"
    "app/hooks"
    "app/stores"
    "app/api"
    "app/i18n/locales"
    "app/utils"
    "app/config"
    "app/provider"
    "app/data"
    "app/assets"
    "public"
    "types"
    "__mocks__"
  )
  for d in "${dirs[@]}"; do
    mkdir -p "$d"
    print_success "  $d"
  done
}

scaffold_config_files() {
  print_header "Creating config files"

  # .env
  if [ ! -f ".env" ]; then
    cat > .env <<'EOF'
VITE_API_URL=http://localhost:8080/api
VITE_COGNITO_ENDPOINT=https://<your-cognito-domain>.amazoncognito.com
VITE_COGNITO_AUTH_CLIENT_ID=<client-id>
VITE_COGNITO_AUTH_REDIRECT_URL=http://localhost:8080/api/auth/cb
VITE_COGNITO_LOGOUT_URL=https://<your-cognito-domain>.amazoncognito.com/logout
VITE_IS_DEBUG=true
EOF
    print_success "  .env  (update placeholder values before running)"
  else
    print_success "  .env  (already exists, skipped)"
  fi

  # vite.config.ts
  scaffold_file "vite.config.ts" <<'EOF'
import { reactRouter } from "@react-router/dev/vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";
import tsconfigPaths from "vite-tsconfig-paths";
import svgr from "vite-plugin-svgr";

export default defineConfig({
  plugins: [tailwindcss(), reactRouter(), tsconfigPaths(), svgr()],
  server: { port: 3000 },
  ssr: {
    noExternal: ["react-simple-maps", "d3-geo", "d3-array", "d3-scale"],
  },
  build: { sourcemap: true },
});
EOF

  # react-router.config.ts
  scaffold_file "react-router.config.ts" <<'EOF'
import type { Config } from "@react-router/dev/config";

export default {
  ssr: true,
} satisfies Config;
EOF

  # tailwind.config.ts
  scaffold_file "tailwind.config.ts" <<'EOF'
import type { Config } from "tailwindcss";

export default {
  content: ["./app/**/*.{js,ts,jsx,tsx}", "./index.html"],
  theme: {
    extend: {
      colors: {
        primary:    { 50:"#F2FBF9",100:"#D2F5F0",200:"#A5EAE1",300:"#70D8CD",400:"#47C0B7",500:"#29A39B",600:"#1E837F",700:"#1C6967",800:"#1B5453",900:"#1B4645",950:"#0A2729" },
        secondary:  { 50:"#FDF2F8",100:"#FCE7F3",200:"#FBCFE9",300:"#F9A8D6",400:"#F472B9",500:"#EA3291",600:"#EB2992",700:"#BE1861",800:"#9D1750",900:"#831845",950:"#500726" },
        gray:       { 50:"#F7F8F7",100:"#EEF0F0",200:"#D9DEDD",300:"#B3BDBB",400:"#919F9C",500:"#738480",600:"#5D6C69",700:"#4C5856",800:"#414B4A",900:"#394140",950:"#262B2A" },
        info:       { 50:"#FDF2F8",100:"#EFF8FF",200:"#DEF1FF",300:"#00AAFF",400:"#0085D4" },
        warning:    { 50:"#FEFEEA",100:"#FFFDC2",200:"#FEC203",300:"#CE8D00" },
        success:    { 50:"#EEF8F4",100:"#D0FBE3",200:"#009460",300:"#00BC54" },
        error:      { 50:"#FEF2F2",100:"#FEE2E2",200:"#DF2526",300:"#BC191C" },
        background: { 50:"#F6F6F6",100:"#FFFFFF" },
      },
      fontFamily: {
        sarabun: ["Sarabun", "sans-serif"],
        kanit:   ["Kanit",   "sans-serif"],
      },
      spacing: { "18": "4.5rem" },
    },
  },
} satisfies Config;
EOF

  # postcss.config.js
  scaffold_file "postcss.config.js" <<'EOF'
export default {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};
EOF

  # tsconfig.json
  scaffold_file "tsconfig.json" <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noEmit": true,
    "paths": { "@/*": ["./app/*"] }
  },
  "include": ["app", "types"]
}
EOF

  # babel.config.cjs
  scaffold_file "babel.config.cjs" <<'EOF'
module.exports = function (api) {
  api.cache(true);
  const importMetaPlugin = require('./babel-plugin-import-meta-transform.cjs');
  return {
    presets: [
      ['@babel/preset-env', { targets: { node: 'current' } }],
      '@babel/preset-typescript',
      ['@babel/preset-react', { runtime: 'automatic' }],
    ],
    plugins: [importMetaPlugin],
  };
};
EOF

  # babel-plugin-import-meta-transform.cjs
  scaffold_file "babel-plugin-import-meta-transform.cjs" <<'EOF'
module.exports = function (babel) {
  const { types: t } = babel;
  return {
    name: 'import-meta-transform',
    visitor: {
      MemberExpression(path) {
        if (
          path.node.object?.type === 'MetaProperty' &&
          path.node.object.meta?.name === 'import' &&
          path.node.object.property?.name === 'meta'
        ) {
          path.replaceWith(
            t.memberExpression(
              t.memberExpression(t.identifier('global'), t.identifier('import')),
              t.identifier('meta')
            )
          );
        }
      },
    },
  };
};
EOF

  # jest.config.mjs
  scaffold_file "jest.config.mjs" <<'EOF'
export default {
  testEnvironment: "jsdom",
  setupFilesAfterEnv: ["<rootDir>/jest.setup.js"],
  coverageProvider: "v8",
  moduleNameMapper: {
    "^@/(.*)\\.svg\\?react$": "<rootDir>/__mocks__/fileMock.js",
    "^@/(.*)$":               "<rootDir>/app/$1",
    "\\.(css|less|scss|sass)$": "identity-obj-proxy",
    "\\.(jpg|jpeg|png|gif|svg|ttf|woff|woff2|mp4|webm|wav|mp3)$": "<rootDir>/__mocks__/fileMock.js",
  },
  transform: { "^.+\\.(ts|tsx|js|jsx)$": "babel-jest" },
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
EOF

  # jest.setup.js
  scaffold_file "jest.setup.js" <<'EOF'
require("@testing-library/jest-dom");
const { TextEncoder, TextDecoder } = require("util");

global.TextEncoder = TextEncoder;
global.TextDecoder = TextDecoder;

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

global.ResizeObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(), unobserve: jest.fn(), disconnect: jest.fn(),
}));

global.IntersectionObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(), unobserve: jest.fn(), disconnect: jest.fn(),
}));

Object.defineProperty(window, "matchMedia", {
  writable: true,
  value: jest.fn().mockImplementation((query) => ({
    matches: false, media: query, onchange: null,
    addListener: jest.fn(), removeListener: jest.fn(),
    addEventListener: jest.fn(), removeEventListener: jest.fn(),
    dispatchEvent: jest.fn(),
  })),
});

window.scrollTo = jest.fn();

const originalError = console.error;
const originalWarn  = console.warn;
beforeAll(() => {
  console.error = (...args) => {
    if (typeof args[0] === "string" &&
      (args[0].includes("Warning: ReactDOM.render is deprecated") ||
       args[0].includes("not wrapped in act") ||
       args[0].includes("hydration error"))) return;
    originalError.call(console, ...args);
  };
  console.warn = (...args) => {
    if (typeof args[0] === "string" &&
      (args[0].includes("Warning:") || args[0].includes("useLayoutEffect"))) return;
    originalWarn.call(console, ...args);
  };
});
afterAll(() => {
  console.error = originalError;
  console.warn  = originalWarn;
});
EOF

  # __mocks__/fileMock.js
  scaffold_file "__mocks__/fileMock.js" <<'EOF'
module.exports = "test-file-stub";
EOF

  # app-start.sh
  scaffold_file "app-start.sh" <<'EOF'
#!/bin/sh -ex
/node_modules/.bin/react-router-serve ./build/server/index.js
EOF
  chmod +x app-start.sh
}

scaffold_source_files() {
  print_header "Creating source files"

  # app/config.ts
  scaffold_file "app/config.ts" <<'EOF'
import isClient from "@/hooks/isClient";

const getEnv = () => {
  try {
    const importMeta = (0, eval)("import.meta");
    if (importMeta?.env) return importMeta.env;
  } catch { /* fall through */ }
  return (globalThis as any).import?.meta?.env || {};
};

const env = getEnv();

const DefaultConfig = {
  Debug:                  env.VITE_IS_DEBUG,
  ApiUrl:                 env.VITE_API_URL,
  CognitoAuthClientId:    env.VITE_COGNITO_AUTH_CLIENT_ID,
  CognitoAuthRedirectUrl: env.VITE_COGNITO_AUTH_REDIRECT_URL,
  CognitoEndpoint:        env.VITE_COGNITO_ENDPOINT,
  AppVersion:             env.VITE_APP_VERSION,
  LogoutUrl:              env.VITE_COGNITO_LOGOUT_URL,
};

export default () => {
  let config = { ...DefaultConfig } as any;

  if (isClient() && (window as any).ENV) {
    config = { ...config, ...(window as any).ENV };
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
EOF

  # app/types.ts
  scaffold_file "app/types.ts" <<'EOF'
export type PaginationType = {
  page:    number;
  perPage: number;
  total:   number;
};

export type ApiResponse<T> = {
  success:    boolean;
  data:       T;
  message?:   string;
  pagination?: PaginationType;
};

export type UserData = {
  id:          string;
  email:       string;
  fullName:    string;
  role:        "admin" | "pharmacist" | "RAPD";
  permissions: Record<string, { read: boolean; create: boolean; update: boolean; delete: boolean }>;
};
EOF

  # app/constants.tsx
  scaffold_file "app/constants.tsx" <<'EOF'
export const COL_WIDTH_XS  = 60;
export const COL_WIDTH_SM  = 100;
export const COL_WIDTH_MD  = 150;
export const COL_WIDTH_LG  = 200;
export const COL_WIDTH_XL  = 280;

export const PER_PAGE_OPTIONS = [10, 20, 50, 100];
EOF

  # app/field-lengths.ts
  scaffold_file "app/field-lengths.ts" <<'EOF'
export const FIELD_MAX = {
  name:    100,
  email:   255,
  phone:   20,
  address: 500,
  note:    1000,
};
EOF

  # app/app.css
  scaffold_file "app/app.css" <<'EOF'
@import "tailwindcss";
EOF

  # app/stores/index.ts
  scaffold_file "app/stores/index.ts" <<'EOF'
import { configureStore } from "@reduxjs/toolkit";
import authReducer from "./auth";

const localStorageMiddleware = (store: any) => (next: any) => (action: any) => {
  const result = next(action);
  const state  = store.getState();
  localStorage.setItem("app-state", JSON.stringify({
    ...state,
    auth: { ...state.auth, isAuthenticated: undefined },
  }));
  return result;
};

const preloadedState = JSON.parse(localStorage.getItem("app-state") ?? "{}");

export const store = configureStore({
  reducer: { 
  //@ts-ignore
  auth: authReducer },
  preloadedState,
  //@ts-ignore
  middleware: (getDefault) => getDefault().concat(localStorageMiddleware),
});

export type RootState   = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
EOF

  # app/stores/auth.ts
  scaffold_file "app/stores/auth.ts" <<'EOF'
import { createSlice, PayloadAction } from "@reduxjs/toolkit";
import { UserData } from "@/types";

const authSlice = createSlice({
  name: "auth",
  initialState: { user: null as UserData | null },
  reducers: {
    setUserInfo: (state, action: PayloadAction<UserData>) => { state.user = action.payload; },
    logout:      (state) => { state.user = null; },
  },
});

export const { setUserInfo, logout } = authSlice.actions;
export default authSlice.reducer;
EOF

  # app/i18n/index.ts
  scaffold_file "app/i18n/index.ts" <<'EOF'
import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import LanguageDetector from "i18next-browser-languagedetector";
import en from "./locales/en.json";
import th from "./locales/th.json";

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources:   { en: { translation: en }, th: { translation: th } },
    fallbackLng: "th",
    detection:   { order: ["localStorage"], lookupLocalStorage: "i18nextLng" },
    react:       { useSuspense: false },
  });

export default i18n;
EOF

  # app/i18n/locales/en.json
  scaffold_file "app/i18n/locales/en.json" <<'EOF'
{
  "common": {
    "save":   "Save",
    "cancel": "Cancel",
    "delete": "Delete",
    "search": "Search",
    "error":  { "required": "This field is required" }
  }
}
EOF

  # app/i18n/locales/th.json
  scaffold_file "app/i18n/locales/th.json" <<'EOF'
{
  "common": {
    "save":   "บันทึก",
    "cancel": "ยกเลิก",
    "delete": "ลบ",
    "search": "ค้นหา",
    "error":  { "required": "กรุณากรอกข้อมูล" }
  }
}
EOF

  # app/hooks/isClient.ts
  scaffold_file "app/hooks/isClient.ts" <<'EOF'
export default function isClient(): boolean {
  return typeof window !== "undefined";
}
EOF

  # app/routes/_index.tsx
  scaffold_file "app/routes/_index.tsx" <<'EOF'
import { Outlet } from "react-router";

export default function IndexPage() {
  return <Outlet />;
}
EOF

  # app/routes/login.tsx
  scaffold_file "app/routes/login.tsx" <<'EOF'
import { useEffect } from "react";
import { useLocation, useNavigate } from "react-router";
import { useDispatch } from "react-redux";
import { logout } from "@/stores/auth";
import useConfig from "@/config";

export default function Login() {
  const dispatch   = useDispatch();
  const config     = useConfig();
  const navigate   = useNavigate();
  const { state }  = useLocation();
  const isLogout   = state?.isLogout;

  useEffect(() => {
    if (isLogout) dispatch(logout());
  }, [isLogout]);

  return (
    <div className="min-h-screen flex items-center justify-center">
      <button
        className="px-6 py-2 bg-primary-400 hover:bg-primary-500 text-white rounded-2xl"
        onClick={() => { window.location.href = config.getCognitoLoginUrl(); }}
      >
        เข้าสู่ระบบ
      </button>
    </div>
  );
}
EOF

  # app/routes/$.tsx
  # IMPORTANT: use useEffect + navigate — never access window during render (SSR unsafe)
  scaffold_file "app/routes/\$.tsx" <<'EOF'
import { useEffect } from "react";
import { useLocation, useNavigate } from "react-router";

export default function CatchAll() {
  const location = useLocation();
  const navigate = useNavigate();

  useEffect(() => {
    if (location.pathname === "/401") {
      navigate("/error?message=401&details=Unauthorized", { replace: true });
    } else {
      navigate("/error?message=404&details=Page not found", { replace: true });
    }
  }, [location.pathname, navigate]);

  return null;
}
EOF

  # app/routes/error.tsx
  # IMPORTANT: must be a route file — if placed in components/ there is no /error route
  # and $.tsx will redirect to itself in an infinite loop.
  scaffold_file "app/routes/error.tsx" <<'EOF'
import { useNavigate, useSearchParams } from "react-router";
import useConfig from "@/config";

export default function ErrorPage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const config   = useConfig();

  const message = searchParams.get("message");
  const details = searchParams.get("details");
  const stack   = searchParams.get("stack");

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="flex flex-col items-center gap-4 text-center">
        <p className="text-7xl font-bold text-gray-300">{message}</p>
        <p className="text-gray-400 text-xl">{details}</p>
        {stack && (
          <pre className="max-w-2xl max-h-48 overflow-auto text-sm text-gray-400 border rounded-md p-3">
            {stack}
          </pre>
        )}
        <button
          className="mt-8 px-6 py-2 bg-primary-400 hover:bg-primary-500 text-white rounded-2xl"
          onClick={() => navigate("/")}
        >
          Home
        </button>
        <p className="text-gray-300 text-xs mt-16">{config.AppVersion}</p>
      </div>
    </div>
  );
}
EOF

  # app/root.tsx
  scaffold_file "app/root.tsx" <<'EOF'
import type { LinksFunction, LoaderFunctionArgs } from "react-router";
import {
  isRouteErrorResponse,
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
  useLoaderData,
  useLocation,
} from "react-router";
import type { Route } from "./+types/root";
import { Provider as ReduxProvider } from "react-redux";
import { I18nextProvider } from "react-i18next";
import { store } from "@/stores";
import i18n from "@/i18n";
import { AlertProvider } from "@/provider/alert";
import { ToastProvider } from "@/provider/toast";
import { SSEProvider } from "@/provider/sse";
import { Auth } from "@/components/auth";
import ClientOnly from "@/components/client-only";
import "./app.css";

export const links: LinksFunction = () => [
  { rel: "preconnect", href: "https://fonts.googleapis.com" },
];

// Pass server-side env to the client (SSR runtime config pattern)
export async function loader({ request: _ }: LoaderFunctionArgs) {
  return {
    ENV: {
      VITE_API_URL:                  process.env.VITE_API_URL,
      VITE_COGNITO_ENDPOINT:         process.env.VITE_COGNITO_ENDPOINT,
      VITE_COGNITO_AUTH_CLIENT_ID:   process.env.VITE_COGNITO_AUTH_CLIENT_ID,
      VITE_COGNITO_AUTH_REDIRECT_URL: process.env.VITE_COGNITO_AUTH_REDIRECT_URL,
      VITE_COGNITO_LOGOUT_URL:       process.env.VITE_COGNITO_LOGOUT_URL,
      VITE_IS_DEBUG:                 process.env.VITE_IS_DEBUG,
    },
  };
}

// IMPORTANT: All providers live here so they wrap EVERY route (including /login and /error).
// Do NOT move providers inside the inner app component — the login page renders via <Outlet />
// outside that tree and will crash without Redux/i18n context.
export function Layout({ children }: { children: React.ReactNode }) {
  const config = useLoaderData<typeof loader>();
  return (
    <html lang="th">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <Meta />
        <Links />
        <script
          dangerouslySetInnerHTML={{
            __html: `window.ENV = ${JSON.stringify(config?.ENV)}`,
          }}
        />
      </head>
      <body className="bg-background-50 text-gray-900" suppressHydrationWarning>
        <ReduxProvider store={store}>
          <AlertProvider>
            <ToastProvider>
              <I18nextProvider i18n={i18n}>
                <SSEProvider>
                  <Auth>
                    {children}
                  </Auth>
                </SSEProvider>
              </I18nextProvider>
            </ToastProvider>
          </AlertProvider>
        </ReduxProvider>
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

export function ErrorBoundary({ error }: Route.ErrorBoundaryProps) {
  let message = "Unknown Error";
  let details = "A server error occurred";
  let stack: string | undefined;

  if (isRouteErrorResponse(error)) {
    message = error.status === 404 ? "404" : "Error";
    details = error.status === 404 ? "Page not found" : error.statusText || details;
  } else if (import.meta.env.DEV && error instanceof Error) {
    details = error.message;
    stack = error.stack;
  }

  return (
    <div className="min-h-svh flex items-center justify-center p-6">
      <div className="max-w-2xl w-full rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h1 className="text-2xl font-semibold text-gray-900">{message}</h1>
        <p className="mt-2 text-gray-600">{details}</p>
        {stack && (
          <pre className="mt-4 max-h-64 overflow-auto rounded-lg bg-gray-50 p-4 text-xs text-gray-700">
            {stack}
          </pre>
        )}
      </div>
    </div>
  );
}

// App is routing logic only — providers are in Layout above.
export default function App() {
  const location = useLocation();
  if (location.pathname.startsWith("/static")) return null;
  const isPublic = location.pathname === "/login" || location.pathname === "/error";
  if (isPublic) return <Outlet />;
  return (
    <ClientOnly fallback={<div className="min-h-svh" />}>
      <Outlet />
    </ClientOnly>
  );
}
EOF
}

# Helper: write a file only if it does not already exist
scaffold_file() {
  local path="$1"
  if [ -f "$path" ]; then
    print_warn "  $path  (already exists, skipped)"
    cat > /dev/null  # drain the heredoc
  else
    cat > "$path"
    print_success "  $path"
  fi
}

cmd_setup() {
  print_header "Full project setup  (following PROJECT_MANUAL.md)"
  check_node
  check_npm

  echo ""
  echo -e "  ${BOLD}Step 1/3${RESET} — Directory structure"
  scaffold_dirs

  echo ""
  echo -e "  ${BOLD}Step 2/3${RESET} — Config & source files"
  scaffold_config_files
  scaffold_source_files

  echo ""
  echo -e "  ${BOLD}Step 3/3${RESET} — Install dependencies"
  if [ ! -f "package.json" ]; then
    print_warn "package.json not found — skipping npm install."
    print_warn "Add your package.json then run:  ./scripts/run.sh install"
  else
    cmd_install
  fi

  echo ""
  print_divider
  print_success "Setup complete."
  echo -e "  Next steps:"
  echo -e "    1. Edit ${CYAN}.env${RESET} with real values"
  echo -e "    2. Run ${CYAN}./scripts/run.sh dev${RESET}"
  print_divider
  echo ""
}

cmd_ci() {
  print_header "CI pipeline: typecheck + test"
  check_node_modules
  npm run typecheck
  print_success "TypeScript check passed"
  npm run test
  print_success "All tests passed"
}

cmd_feature() {
  local name="$1"

  if [ -z "$name" ]; then
    print_error "Feature name is required."
    echo -e "  Usage: ${CYAN}./scripts/run.sh feature <name>${RESET}"
    echo -e "  Example: ${CYAN}./scripts/run.sh feature payment${RESET}"
    exit 1
  fi

  local dir="app/features/$name"

  if [ -d "$dir" ]; then
    print_error "Feature '$name' already exists at $dir"
    exit 1
  fi

  print_header "Scaffolding feature: $name"

  mkdir -p "$dir/components"
  mkdir -p "$dir/__tests__"
  print_success "  $dir/components/"
  print_success "  $dir/__tests__/"

  # [feature].config.ts
  cat > "$dir/$name.config.ts" <<EOF
export const PER_PAGE_OPTIONS: number[] = [5, 10, 20, 50]
EOF
  print_success "  $dir/$name.config.ts"

  # [feature].schema.ts
  cat > "$dir/$name.schema.ts" <<EOF
import { z } from "zod"

export const ${name^}ItemSchema = z.object({
  id: z.number(),
}).strict()

export type ${name^}Item = z.infer<typeof ${name^}ItemSchema>
EOF
  print_success "  $dir/$name.schema.ts"

  # [feature].service.ts
  cat > "$dir/$name.service.ts" <<EOF
// Re-export TanStack Query hooks from @/api/$name
// export { useGet${name^}List, useCreate${name^}, useUpdate${name^}, useDelete${name^} } from "@/api/$name"
EOF
  print_success "  $dir/$name.service.ts"

  # [feature].utils.ts
  cat > "$dir/$name.utils.ts" <<EOF
import type { ${name^}Item } from "./$name.schema"

// Pure mappers — no hooks, no API calls, no window/document
// export function mapTo${name^}Item(raw: unknown): ${name^}Item { ... }
EOF
  print_success "  $dir/$name.utils.ts"

  # [feature].hooks.ts
  cat > "$dir/$name.hooks.ts" <<EOF
// Feature hooks — compose API hooks + form logic here
// Return shape: { data, state, filters, pagination, handlers }
//
// export function use${name^}Table() {
//   return {
//     data:       { rows: [] },
//     state:      { isPending: false, isError: false },
//     filters:    { searchText: "" },
//     pagination: { hasNext: false, hasPrevious: false, perPage: 20 },
//     handlers:   {},
//   }
// }
EOF
  print_success "  $dir/$name.hooks.ts"

  # index.ts
  cat > "$dir/index.ts" <<EOF
// Public API — only export what other features need
// export { use${name^}Table } from "./$name.hooks"
// export { PER_PAGE_OPTIONS } from "./$name.config"
// export type { ${name^}Item } from "./$name.schema"
EOF
  print_success "  $dir/index.ts"

  echo ""
  print_divider
  print_success "Feature '$name' scaffolded at $dir"
  echo -e "  Next steps:"
  echo -e "    1. Define your Zod schema in ${CYAN}$dir/$name.schema.ts${RESET}"
  echo -e "    2. Add API hooks to ${CYAN}app/api/$name.tsx${RESET} and re-export from ${CYAN}$dir/$name.service.ts${RESET}"
  echo -e "    3. Build out ${CYAN}$dir/$name.hooks.ts${RESET} with useQuery/useMutation"
  echo -e "    4. Add components in ${CYAN}$dir/components/${RESET}"
  echo -e "    5. Expose public surface via ${CYAN}$dir/index.ts${RESET}"
  echo -e "    6. Wire route in ${CYAN}app/routes/${RESET}"
  print_divider
  echo ""
}

# Parse options
DOCKER_TAG="cop-acp-web"
APP_VERSION="1.0.0"
API_URL=""
HOST_PORT="3000"
COMMAND=""
HELP_TARGET=""
FEATURE_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)     DOCKER_TAG="$2"; shift 2 ;;
    --version) APP_VERSION="$2"; shift 2 ;;
    --api-url) API_URL="$2"; shift 2 ;;
    --port)    HOST_PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [ -z "$COMMAND" ]; then
        COMMAND="$1"
      elif [ "$COMMAND" = "help" ] && [ -z "$HELP_TARGET" ]; then
        HELP_TARGET="$1"
      elif [ "$COMMAND" = "feature" ] && [ -z "$FEATURE_NAME" ]; then
        FEATURE_NAME="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$COMMAND" ]; then
  usage
  exit 1
fi

case "$COMMAND" in
  help)
    if [ -n "$HELP_TARGET" ]; then
      usage_command "$HELP_TARGET"
    else
      usage
    fi
    ;;
  install)           cmd_install ;;
  dev)               cmd_dev ;;
  build)             cmd_build ;;
  start)             cmd_start ;;
  typecheck)         cmd_typecheck ;;
  test)              cmd_test ;;
  test:watch)        cmd_test_watch ;;
  test:coverage)     cmd_test_coverage ;;
  docker:build)      cmd_docker_build ;;
  docker:run)        cmd_docker_run ;;
  docker:build-run)  cmd_docker_build_run ;;
  setup)             cmd_setup ;;
  ci)                cmd_ci ;;
  feature)           cmd_feature "$FEATURE_NAME" ;;
  *)
    print_error "Unknown command: '$COMMAND'"
    echo -e "  Run ${CYAN}./scripts/run.sh help${RESET} to see available commands."
    echo ""
    exit 1
    ;;
esac
