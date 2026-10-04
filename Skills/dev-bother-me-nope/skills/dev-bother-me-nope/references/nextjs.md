# NextJS Custom Skill

# Folder Structure

when creating a new NextJS project, the following folder structure should be used
my-app/
├── src/
│ ├── app/ # NEXT.JS APP ROUTER (Routing Layer only)
│ │ ├── (auth)/ # Route Group: Grouping without affecting URL
│ │ │ ├── login/
│ │ │ │ └── page.tsx # Route page component
│ │ │ └── layout.tsx # Auth-specific shared UI
│ │ ├── (dashboard)/
│ │ │ └── dashboard/
│ │ │ └── page.tsx
│ │ ├── api/ # API Route Handlers (REST endpoints)
│ │ │ └── webhooks/
│ │ │ └── route.ts
│ │ ├── layout.tsx # Global Root Layout
│ │ ├── page.tsx # Homepage
│ │ └── globals.css # Global Tailwind/CSS rules
│ │
│ ├── features/ # FEATURE MODULES (The core of your business logic)
│ │ ├── auth/ # Isolated domain logic
│ │ │ ├── components/ # Feature-specific UI components
│ │ │ ├── hooks/ # Feature-specific hooks
│ │ │ ├── services/ # Feature API calls / logic
│ │ │ └── tests/ # Tests files
│ │ └── billing/
│ │
│ ├── shared/ # REUSABLE LAYER (Cross-feature code)
│ │ ├── components/ # Base UI primitives (Button, Input, Modal)
│ │ ├── hooks/ # Global React hooks (useDebounce, useAuth)
│ │ ├── utils/ # Pure utility functions (cn formatting)
│ │ ├── types/ # Shared TypeScript definitions
│ │ └── tests/ # Tests files
│ │
│ ├── lib/ # THIRD-PARTY CONFIGS / SERVER LAYER
│ | ├── prisma.ts # Database client singletons
│ | ├── actions/ # Server Actions ("use server" files)
│ | ├── auth.ts # Auth configurations (e.g., NextAuth/Auth.js)
│ | └── tests/ # Tests files
| |
| └── tests/ # Tests for pages/routes/etc.
|
├── public/ # Static assets (images, fonts, favicons)
├── next.config.ts # Next.js configurations
└── tsconfig.json # TypeScript configurations
