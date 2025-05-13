# Modern Web Stack Starter

**Core Technologies**  
✅ React 19 (Stable)  
✅ React Router v7  
✅ ShadCN UI (v0.8+)  
✅ Tailwind CSS v3.4  
✅ Firebase v10+  
✅ Vite 5+  
✅ TypeScript 5.3+  

## Technology Choices Summary

| Technology       | Purpose                          | Key Benefits                                                                 |
|------------------|----------------------------------|-----------------------------------------------------------------------------|
| **React Router 7** | Core Routing Framework          | Official template ensures compatibility with React 19                      |
| **ShadCN UI**    | Component Library               | Pre-configured in template with Tailwind integration                       |
| **Firebase**     | Backend-as-a-Service            | Zero-config setup through environment variables                            |

---
## Project Setup Guide

### 1. Create Base Project (Official Template)
```
npx create-react-router@latest my-project
cd my-project
```

This creates a project with:
- React 19 (stable)
- React Router v7 (pre-configured)
- Vite 5+ build system
- TypeScript 5.3+

Note: Chrome DevTools making automatic requests to /.well-known/appspecific/com.chrome.devtools.json during development, which will lead to an error in development when `npm run dev`. To fix this use the following `vite.config.ts`.

```TypeScript
// vite.config.ts
import { reactRouter } from "@react-router/dev/vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";
import tsconfigPaths from "vite-tsconfig-paths";

export default defineConfig({
  plugins: [tailwindcss(), reactRouter(), tsconfigPaths()],
  server: {
    port: 5173,
    strictPort: true,
    proxy: {
      '/.well-known/appspecific/com.chrome.devtools.json': {
        target: 'http://localhost:5173', // Required dummy target
        bypass: (req, res, options) => {
          res.statusCode = 204;
          res.end();
          return true; // Bypass further processing
        }
      }
    }
  }
});
```
### 2. Install ShadCN CLI (v2.5+)

```
# Install ShadCN UI core
npx shadcn@latest init
```
During setup:

✔ Which style would you like to use? › New York

✔ Which color would you like to use as base color? › Neutral

✔ Add CSS variables for colors? … Yes

✔ How to resolve React 19 peer deps: › Use --force

```
# Add components
npx shadcn@latest add button
npx shadcn@latest add card
npx shadcn@latest add dropdown-menu
```

### 3. Firebase Integration
```
npm install firebase @react-firebase/auth
```

Create `.env.local`:
```
VITE_FIREBASE_API_KEY=your-key
VITE_FIREBASE_AUTH_DOMAIN=your-domain
VITE_FIREBASE_PROJECT_ID=your-id
```

Add Firebase init in `src/lib/firebase.ts`:
```
import { initializeApp } from 'firebase/app'
import { getAuth } from 'firebase/auth'

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
}

export const app = initializeApp(firebaseConfig)
export const auth = getAuth(app)
```

## 4. Development Workflow

```
# Start dev server
npm run dev

# Build for production
npm run build

# Preview build
npm run preview
```
