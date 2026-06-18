# UI Wireframes Reference

> Source visuals: [`docs/ui-preview/app-ui-preview.html`](../../ui-preview/app-ui-preview.html) (mobile) · [`docs/ui-preview/web-ui-preview.html`](../../ui-preview/web-ui-preview.html) (web)
>
> Use these diagrams during implementation to understand layout structure, component placement, and navigation without opening the HTML files.

---

## Design Tokens

| Token       | Value     | Usage                              |
|-------------|-----------|-------------------------------------|
| `--primary` | `#4F46E5` | Buttons, active nav, links          |
| `--primary-dark` | `#3730A3` | Hover states, gradient end     |
| `--income`  | `#10B981` | Positive amounts, success states    |
| `--expense` | `#EF4444` | Negative amounts, danger, over-budget |
| `--warning` | `#F59E0B` | 80–99% budget usage                |
| `--sidebar` | `#0F172A` | Web sidebar background              |
| `--bg`      | `#F1F5F9` | App / page background               |
| `--surface` | `#FFFFFF` | Cards, panels, modals               |
| `--border`  | `#E2E8F0` | Dividers, input outlines            |
| `--text-primary` | `#1E293B` | Headings, values                |
| `--text-secondary` | `#64748B` | Labels, metadata              |
| `--text-hint` | `#94A3B8` | Placeholders, timestamps          |

**Typography:** Inter / System UI · `700` headings · `600` labels · `400` body

**Radii:** Cards `12px` · Chips/Badges `20px` · Buttons & Inputs `8px`

**Money rule:** API returns integers (cents). Always divide by 100 at the UI layer. Never store or compute with floats.

---

## Navigation Flow

### Mobile (Bottom Tab Bar)

```
[Splash] ──→ [Login / Register]
                    │
                    ↓  (JWT stored in flutter_secure_storage)
             [Dashboard M2]
            /    │      │    \
           ↓     ↓      ↓     ↓
       [Txns] [Add ↑] [Reports] [Notifs]
        M3     M4       M5        M6
                                  │
                             [Workspaces M7]
```

**Tab bar — always visible on authenticated screens:**
```
┌──────────────────────────────────────────────────┐
│  🏠 Home   💸 Txns   [➕] Add   📊 Reports   🔔  │
│            (active = indigo fill)                │
└──────────────────────────────────────────────────┘
```

### Web (Left Sidebar — permanent)

```
Logo + Workspace Switcher
  ├── 🏠 Dashboard             /dashboard
  ├── 💸 Transactions          /transactions
  ├── 📊 Reports               /reports
  ├── 🎯 Budgets               /budgets
  ├── 🔄 Recurring             /recurring
  ── [Workspace section] ───────────────
  ├── 👥 Members               /members
  ├── ⚙️  Settings              /settings
  └── 🔔 Notifications  [N]    /notifications
  ──────────────────────────────────────
  [AH] User name + email        (footer)
```

---

## Mobile Screens · 320 × 640 (Phone Frame)

---

### M1 · Login

```
┌──────────────────────────────────┐
│ ●●●○○                     9:41  │  ← status bar
├──────────────────────────────────┤
│                                  │
│          ┌────────────┐          │
│          │   💰 LOGO  │          │
│          └────────────┘          │
│           ExpenseTracker         │
│       Track smarter together     │
│                                  │
│  Email address                   │
│  ┌────────────────────────────┐  │
│  │  ahmad@example.com         │  │
│  └────────────────────────────┘  │
│  Password              Forgot? → │
│  ┌────────────────────────────┐  │
│  │  ••••••••           [👁]  │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │         SIGN IN            │  │  ← primary (#4F46E5)
│  └────────────────────────────┘  │
│                                  │
│         ────── or ──────         │
│                                  │
│  ┌─────────────┐ ┌─────────────┐ │
│  │  🔵 Google  │ │  🍎 Apple   │ │
│  └─────────────┘ └─────────────┘ │
│                                  │
│   No account yet?  [Sign up] → │
└──────────────────────────────────┘
```

**API:** `POST /auth/login` · `POST /auth/google` · `POST /auth/apple`
**On success:** store access + refresh tokens → navigate to M2

---

### M2 · Dashboard

```
┌──────────────────────────────────┐
│  Family Budget 🏠    🔔₃  [AH]  │  ← workspace name · notif badge · avatar
├──────────────────────────────────┤
│  ┌──────────────────────────────┐│
│  │  Net Balance         Jun ▾  ││  ← month picker
│  │                              ││
│  │       $2,450.00              ││  ← large, white on indigo
│  │                              ││
│  │  ↑ Income    $5,200.00       ││
│  │  ↓ Expenses  $2,750.00       ││
│  └──────────────────────────────┘│
│                                  │
│  Recent Transactions  View all → │
│  ┌──────────────────────────────┐│
│  │ 🍕 Starbucks        -$6.50  ││  ← red amount
│  │    Food · Jun 17             ││
│  ├──────────────────────────────┤│
│  │ 🛒 Walmart         -$87.40  ││
│  │    Shopping · Jun 16         ││
│  ├──────────────────────────────┤│
│  │ 💼 Salary          +$4,200  ││  ← green amount
│  │    Income · Jun 1            ││
│  └──────────────────────────────┘│
│                                  │
│  Budgets               Manage →  │
│  🏠 Housing  ████████████████ 100%│  ← red (≥100%)
│  🍕 Food     ████████████░░░░  78%│  ← amber (80–99%)
│  🚗 Transport███░░░░░░░░░░░░░  38%│  ← green (<80%)
├──────────────────────────────────┤
│  🏠      💸      ➕      📊    🔔 │
└──────────────────────────────────┘
```

**API:** `GET /workspaces/:id/transactions?limit=5` · `GET /workspaces/:id/budgets`
`GET /workspaces/:id/reports?period=monthly&month=YYYY-MM`

---

### M3 · Transactions

```
┌──────────────────────────────────┐
│ ←  Transactions        [⊞] [🔍] │  ← filter icon · search
├──────────────────────────────────┤
│ [All] [Expense] [Income] [Month] │  ← chip filters (multi-select)
├──────────────────────────────────┤
│  Jun 17                          │  ← date group header
│  ┌──────────────────────────────┐│
│  │ 🍕  Starbucks      -$6.50  ←││  swipe left → delete
│  │     Food · Ahmad             ││  swipe right → edit sheet
│  └──────────────────────────────┘│
│  ┌──────────────────────────────┐│
│  │ 🍕  McDonald's    -$12.80   ││
│  │     Food · Sara              ││
│  └──────────────────────────────┘│
│  Jun 16                          │
│  ┌──────────────────────────────┐│
│  │ 🛒  Walmart        -$87.40  ││
│  │     Shopping · Ahmad         ││
│  └──────────────────────────────┘│
│  ┌──────────────────────────────┐│
│  │ ⚡  Electric Bill  -$94.20  ││
│  │     Utilities · Ahmad        ││
│  └──────────────────────────────┘│
│  Jun 1                           │
│  ┌──────────────────────────────┐│
│  │ 💼  Salary        +$4,200   ││
│  │     Income · Ahmad           ││
│  └──────────────────────────────┘│
├──────────────────────────────────┤
│  🏠      💸      ➕      📊    🔔 │
└──────────────────────────────────┘
```

**API:** `GET /workspaces/:id/transactions?page=1&limit=20&type=EXPENSE`
**Swipe delete:** `DELETE /workspaces/:id/transactions/:txnId` (confirm dialog first)

---

### M4 · Add / Edit Transaction (Bottom Sheet)

```
┌──────────────────────────────────┐
│                                  │
│   [dim overlay — tap to close]   │
│                                  │
│                                  │
│  ┌────────────────────────────┐  │
│  │ ▬▬▬▬▬ drag handle ▬▬▬▬▬   │  │
│  │  Add Transaction        ✕  │  │
│  │                            │  │
│  │  ┌──────────┐ ┌──────────┐ │  │
│  │  │ EXPENSE  │ │  INCOME  │ │  │  ← toggle (red / green)
│  │  └──────────┘ └──────────┘ │  │
│  │                            │  │
│  │  ┌────────────────────┐    │  │
│  │  │     $  0.00        │    │  │  ← large numeric input
│  │  └────────────────────┘    │  │
│  │                            │  │
│  │  Description               │  │
│  │  ┌────────────────────┐    │  │
│  │  │  e.g. Starbucks    │    │  │
│  │  └────────────────────┘    │  │
│  │                            │  │
│  │  Category        Date      │  │
│  │  ┌──────────┐ ┌──────────┐ │  │
│  │  │ 🍕 Food▾ │ │ Jun 17 ▾ │ │  │  ← category sub-sheet
│  │  └──────────┘ └──────────┘ │  │
│  │                            │  │
│  │  ┌────────────────────┐    │  │
│  │  │       SAVE         │    │  │  ← primary btn
│  │  └────────────────────┘    │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘
```

**API:** `POST /workspaces/:id/transactions` (create) · `PUT /workspaces/:id/transactions/:id` (edit)
**Category list:** `GET /workspaces/:id/categories`
**Amount:** entered as display string `$12.50` → store as integer `1250` (cents)

---

### M5 · Reports

```
┌──────────────────────────────────┐
│ ←  Reports                Jun ▾ │  ← month/range picker
├──────────────────────────────────┤
│  ┌──────────┐ ┌─────────┐ ┌────┐│
│  │ Income   │ │ Expenses│ │ Net││  ← 3-stat row
│  │ $5,200   │ │ $2,750  │ │$2,450│
│  └──────────┘ └─────────┘ └────┘│
│                                  │
│  Spending by Category            │
│  ┌──────────────────────────────┐│
│  │         ╭───╮                ││
│  │        /     \               ││
│  │       │   ○   │ ■ Housing 44%││  ← donut chart
│  │        \     /  ■ Food    11%││
│  │         ╰───╯   ■ Utilities14%│
│  │                 ■ Shopping11%││
│  │                 ■ Other   20%││
│  └──────────────────────────────┘│
│                                  │
│  Spending Trend (6 months)       │
│  ┌──────────────────────────────┐│
│  │ $6k ▓                        ││
│  │ $4k ▓  ▓               ▓    ││  ← income bars
│  │ $2k ▓  ▓  ■  ■  ■  ■  ■    ││  ← expense line
│  │     Jan Feb Mar Apr May Jun  ││
│  └──────────────────────────────┘│
│                                  │
│  [⬇ Export CSV]  [⬇ Export PDF] │
├──────────────────────────────────┤
│  🏠      💸      ➕      📊    🔔 │
└──────────────────────────────────┘
```

**API:** `GET /workspaces/:id/reports?period=monthly&month=2026-06`
**Export:** `GET /workspaces/:id/reports/export?format=csv` · `?format=pdf`
Response shape: `{ income, expenses, net, byCategory[], trend[] }`

---

### M6 · Notifications

```
┌──────────────────────────────────┐
│ ←  Notifications     [Mark all] │
├──────────────────────────────────┤
│  TODAY                           │
│  ┌──────────────────────────────┐│
│  │● 🔴 Budget Alert             ││  ← unread: indigo left border + dot
│  │  Food budget reached 80%     ││
│  │  $312 of $400 spent          ││
│  │  2 minutes ago               ││
│  └──────────────────────────────┘│
│  ┌──────────────────────────────┐│
│  │● 🔴 Budget Alert             ││
│  │  Housing at 100%             ││
│  │  $1,200 of $1,200 spent      ││
│  │  1 hour ago                  ││
│  └──────────────────────────────┘│
│  YESTERDAY                       │
│  ┌──────────────────────────────┐│
│  │  🔄 Recurring Reminder       ││  ← read (no dot)
│  │  Netflix $15.99 charged      ││
│  │  Jun 15                      ││
│  └──────────────────────────────┘│
│  ┌──────────────────────────────┐│
│  │  📧 Workspace Invite         ││
│  │  Sara invited you to "Work"  ││
│  │  [Accept]      [Decline]     ││  ← INVITE type has action btns
│  └──────────────────────────────┘│
│                                  │
├──────────────────────────────────┤
│  🏠      💸      ➕      📊    🔔 │
└──────────────────────────────────┘
```

**Types:** `BUDGET_ALERT` · `RECURRING_REMINDER` · `MONTHLY_SUMMARY` · `INVITE`
**API:** `GET /workspaces/:id/notifications` · `PATCH /notifications/:id/read`
`PATCH /notifications/read-all` · WebSocket `/notifications` (real-time push)

---

### M7 · Workspaces

```
┌──────────────────────────────────┐
│ ←  Workspaces            [+ New] │
├──────────────────────────────────┤
│  Your Workspaces                 │
│  ┌──────────────────────────────┐│
│  │ 🏠 Family Budget        ✓   ││  ← ✓ = currently active workspace
│  │    Owner · 3 members · USD   ││
│  └──────────────────────────────┘│
│  ┌──────────────────────────────┐│
│  │ 💼 Work Expenses             ││
│  │    Admin · 8 members · USD   ││
│  └──────────────────────────────┘│
│  ┌──────────────────────────────┐│
│  │ 🎮 Personal Hobbies          ││
│  │    Owner · 1 member · USD    ││
│  └──────────────────────────────┘│
│                                  │
│  ┌──────────────────────────────┐│
│  │   +  Create New Workspace    ││
│  └──────────────────────────────┘│
│                                  │
│  Invite Link (Family Budget)     │
│  ┌──────────────────────────────┐│
│  │ app.ex…/invite/abc123   [⎘] ││  ← copy to clipboard
│  └──────────────────────────────┘│
│  [⬇ Share]      [⟳ Regenerate]  │
│                                  │
├──────────────────────────────────┤
│  🏠      💸      ➕      📊    🔔 │
└──────────────────────────────────┘
```

**API:** `GET /workspaces` · `POST /workspaces` · `POST /workspaces/:id/invite-link`
Invite link TTL: 72 hours. Regenerate invalidates old token.
Accept flow: `POST /workspaces/accept-invite?token=abc123` (handles 404/409/410)

---

## Web Screens · ≥ 1200px (Browser Frame)

### Common Authenticated Shell

All authenticated web screens share this outer layout:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●  [💰 Page Title ×]  [+]   [← → ↺]  [🔒 app.expensetracker.io/path     ] │  ← browser chrome
├──────────────────┬───────────────────────────────────────────────────────────────┤
│  [💰] Expense    │  Page Title                     [actions…]      🔔  [AH]     │  ← topbar
│  [WS Name]  ▾   ├───────────────────────────────────────────────────────────────┤
│  ────────────    │                                                               │
│  🏠 Dashboard    │                                                               │
│  💸 Transactions │                  MAIN CONTENT AREA                           │
│  📊 Reports      │                                                               │
│  🎯 Budgets      │                                                               │
│  🔄 Recurring    │                                                               │
│  ────────────    │                                                               │
│  👥 Members      │                                                               │
│  ⚙️  Settings     │                                                               │
│  🔔 Notifs [3]   │                                                               │
│  ────────────    │                                                               │
│  [AH] Ahmad H.   │                                                               │
│  ahmad@ex…       │                                                               │
└──────────────────┴───────────────────────────────────────────────────────────────┘
  ←── 220px ──→    ←──────────────────── fluid (~980px+) ─────────────────────────→
```

Active sidebar item: indigo pill background (`#4F46E5`). Inactive: `#94A3B8` text, transparent bg.

---

### W1 · Login (Web)

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●  [💰 Sign In ×]  [+]    [← → ↺]  [🔒 app.expensetracker.io/login      ] │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│     ┌─────────────────────────┐          ┌──────────────────────────────────┐   │
│     │                         │          │  [💰]  ExpenseTracker            │   │
│     │   💰 EXPENSE TRACKER    │          │                                  │   │
│     │                         │          │  Welcome back                    │   │
│     │  Track, analyse, and    │          │  Sign in to your account         │   │
│     │  optimise finances      │          │                                  │   │
│     │  across teams.          │          │  Email address                   │   │
│     │                         │          │  ┌──────────────────────────┐   │   │
│     │  ✓ Shared budgets       │          │  │  ahmad@example.com        │   │   │
│     │  ✓ Real-time notifs     │          │  └──────────────────────────┘   │   │
│     │  ✓ Reports & exports    │          │  Password              Forgot? → │   │
│     │  ✓ Recurring rules      │          │  ┌──────────────────────────┐   │   │
│     │                         │          │  │  ••••••••                │   │   │
│     └─────────────────────────┘          │  └──────────────────────────┘   │   │
│           Branding panel                 │  ┌──────────────────────────┐   │   │
│           (indigo gradient)              │  │        SIGN IN           │   │   │
│                                          │  └──────────────────────────┘   │   │
│                                          │        ────── or ──────          │   │
│                                          │  ┌────────────┐ ┌────────────┐  │   │
│                                          │  │ 🔵 Google  │ │ 🍎 Apple   │  │   │
│                                          │  └────────────┘ └────────────┘  │   │
│                                          │  No account?  [Create one free]  │   │
│                                          └──────────────────────────────────┘   │
│                                                  Login card (400px, white)       │
└──────────────────────────────────────────────────────────────────────────────────┘
```

No sidebar — unauthenticated layout. Background: `linear-gradient(135deg, #EEF2FF, #F8FAFC)`.

---

### W2 · Dashboard (Web)

```
┌──────────────────┬───────────────────────────────────────────────────────────────┐
│  💰 Expense      │  Dashboard     [Jun 2026 ▾]  [📅 Date Range]  [+ Add Txn] 🔔│
│  [FB] Family ▾   ├───────────────────────────────────────────────────────────────┤
│  ─────────────   │ ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌───────────┐│
│  🏠 Dashboard ◀  │ │ Net Bal 💰 │  │ Income  📈 │  │ Expenses 📉│  │ Savings 🎯││
│  💸 Transactions │ │ $2,450     │  │ $5,200     │  │ $2,750     │  │ 47%       ││
│  📊 Reports      │ │ ↑+12% May  │  │ Salary+Fre.│  │ ↑+$180    │  │ Goal: 40% ││
│  🎯 Budgets      │ └────────────┘  └────────────┘  └────────────┘  └───────────┘│
│  🔄 Recurring    │                                                               │
│  ─────────────   │ ┌──────────────────────────────┐  ┌─────────────────────────┐│
│  👥 Members      │ │ Income vs Expenses (6 months) │  │ Budget Progress         ││
│  ⚙️  Settings     │ │ $6k │▓                        │  │ 🏠 Housing ████████ 100%││
│  🔔 Notifs [3]   │ │ $4k │▓ ▓                  ▓   │  │ 🍕 Food    ██████░░  78%││
│  ─────────────   │ │ $2k │▓ ▓  ▓  ▓  ▓  ■  ■      │  │ 🚗 Transport ███░░░  38%││
│  [AH] Ahmad H.   │ │ $0  │■ ■  ■  ■  ■           │  │ 🛒 Shopping █████░░  62%││
│  ahmad@ex…       │ │     Jan Feb Mar Apr May Jun    │  │ ⚡ Utilities █████░░  63%││
│                  │ │  ▓ Income  ■ Expenses           │  │                 Manage →││
│                  │ └──────────────────────────────┘  └─────────────────────────┘│
│                  │ ┌───────────────────────────────────────────────────────────┐ │
│                  │ │ Recent Transactions                          View all →    │ │
│                  │ ├──────────┬────────────────────┬─────────┬──────┬──────────┤ │
│                  │ │ Date     │ Description         │ Category│  By  │ Amount   │ │
│                  │ ├──────────┼────────────────────┼─────────┼──────┼──────────┤ │
│                  │ │ Jun 17   │ Starbucks           │ 🍕 Food │  AH  │ -$6.50   │ │
│                  │ │ Jun 16   │ Walmart Grocery     │ 🛒 Shop │  AH  │ -$87.40  │ │
│                  │ │ Jun 16   │ Electric Bill       │ ⚡ Util │  AH  │ -$94.20  │ │
│                  │ │ Jun 1    │ Monthly Salary      │ 💼 Inc  │  AH  │ +$4,200  │ │
│                  │ └──────────┴────────────────────┴─────────┴──────┴──────────┘ │
└──────────────────┴───────────────────────────────────────────────────────────────┘
```

"+ Add Transaction" → modal dialog overlay (not page navigation).
KPI row uses 4-column CSS grid; chart + budget use 2-column split (~60% / ~38%).

---

### W3 · Transactions (Web — Filter Panel + Table)

```
┌──────────────────┬───────────────────────────────────────────────────────────────┐
│  💰 Expense      │ Transactions  [🔍 Search…] [⬇ CSV] [⬇ PDF]  [+ Add Txn]    │
│  [FB] Family ▾   ├─────────────────────┬─────────────────────────────────────────┤
│  ─────────────   │  FILTER PANEL 240px │ [All (24)]  [Expenses (18)]  [Income(6)]│
│  🏠 Dashboard    │  ─────────────────  ├────────────────────────────────────────┤│
│  💸 Txns      ◀  │  Date Range         │ ☐ │ Date   │ Description  │Cat│By│Amount ││
│  📊 Reports      │  [Jun 1, 2026   ]   ├───┼────────┼──────────────┼───┼──┼───────┤│
│  🎯 Budgets      │  [Jun 17, 2026  ]   │☐  │ Jun 17 │ Starbucks    │🍕 │AH│ -$6   ││
│  🔄 Recurring    │                     │☐  │ Jun 17 │ McDonald's   │🍕 │SR│ -$12  ││
│  ─────────────   │  Type               │☐  │ Jun 16 │ Walmart      │🛒 │AH│ -$87  ││
│  👥 Members      │  ☑ All             │☐  │ Jun 16 │ Electric Bill│⚡ │AH│ -$94  ││
│  ⚙️  Settings     │  ☐ Expense         │☐  │ Jun 15 │ Netflix 🔄   │🎭 │🔄│ -$16  ││
│  🔔 Notifs [3]   │  ☐ Income          │☐  │ Jun 1  │ Monthly Sal. │💼 │AH│+$4,200││
│  ─────────────   │                     │☐  │ Jun 1  │ Freelance    │💻 │AH│+$1,000││
│  [AH] Ahmad H.   │  Category           ├───┴────────┴──────────────┴───┴──┴───────┤│
│                  │  ☐ 🍕 Food         │       ← Prev  [1] 2 3  Next →   7 of 24  ││
│                  │  ☐ 🏠 Housing      └─────────────────────────────────────────────┘
│                  │  ☐ 🛒 Shopping                                                 │
│                  │  ☐ ⚡ Utilities                                                 │
│                  │  ☐ 💼 Income                                                   │
│                  │                                                                 │
│                  │  Added By                                                       │
│                  │  ☐ Ahmad H.                                                    │
│                  │  ☐ Sara R.                                                     │
│                  │  ☐ Mike K.                                                     │
│                  │  [Apply Filters]                                                │
│                  │   Clear all                                                     │
└──────────────────┴─────────────────────────────────────────────────────────────────┘
```

🔄 icon on Netflix = auto-created by recurring rule processor.
**API:** `GET /workspaces/:id/transactions?page=1&limit=20&type=EXPENSE&categoryId=&userId=`
**Export:** `GET /workspaces/:id/reports/export?format=csv&startDate=&endDate=`

---

### W4 · Reports & Analytics (Web)

```
┌──────────────────┬───────────────────────────────────────────────────────────────┐
│  💰 Expense      │ Reports & Analytics     [📅 Jun 2026 ▾]  [⬇ CSV]  [⬇ PDF]  │
│  [FB] Family ▾   ├───────────────────────────────────────────────────────────────┤
│  ─────────────   │ ┌────────────┐  ┌─────────────┐  ┌────────────┐  ┌──────────┐│
│  🏠 Dashboard    │ │ Income     │  │ Expenses    │  │ Net Balance│  │ Txns     ││
│  💸 Transactions │ │ $5,200     │  │ $2,750      │  │ $2,450     │  │ 24       ││
│  📊 Reports   ◀  │ └────────────┘  └─────────────┘  └────────────┘  └──────────┘│
│  🎯 Budgets      │                                                               │
│  🔄 Recurring    │ ┌────────────────────────────┐  ┌──────────────────────────┐ │
│  ─────────────   │ │ Spending by Category        │  │ Budget vs Actual         │ │
│  👥 Members      │ │         ╭───╮               │  │ 🏠 Housing  ████████ 100%│ │
│  ⚙️  Settings     │ │        / ○   \              │  │ 🍕 Food     ██████░   78%│ │
│  🔔 Notifs [3]   │ │        \     /              │  │ 🚗 Transport ████░░   38%│ │
│  ─────────────   │ │         ╰───╯               │  │ 🛒 Shopping  ██████░  62%│ │
│  [AH] Ahmad H.   │ │  ■ Housing  44%  $1,200     │  │ ⚡ Utilities  ██████░  63%│ │
│                  │ │  ■ Food     11%   $312      │  └──────────────────────────┘ │
│                  │ │  ■ Utilities 14%  $380      │                               │
│                  │ │  ■ Shopping 11%   $290      │                               │
│                  │ │  ■ Other    20%   $568      │                               │
│                  │ └────────────────────────────┘                                │
│                  │                                                               │
│                  │ ┌───────────────────────────────────────────────────────────┐ │
│                  │ │ Daily Spending Heatmap — 2026                  Less ░▒▓█ More│
│                  │ │ ░░▒░░░░░▒▒░░░░░░░░▒▒▒░░░░░░░░▒░░▒▒░░░░░░▓▓█▓▓░▒▒▒░░░   │ │
│                  │ │  Jan      Feb      Mar     Apr      May      Jun           │ │
│                  │ └───────────────────────────────────────────────────────────┘ │
└──────────────────┴───────────────────────────────────────────────────────────────┘
```

**API:** `GET /workspaces/:id/reports?period=monthly&month=2026-06`
Response: `{ income, expenses, net, byCategory: [{categoryId, name, amount, pct}], trend: [{month, income, expenses}] }`
**Heatmap:** derived client-side from transactions list, grouped by day.

---

### W5 · Workspace Settings (Web)

```
┌──────────────────┬───────────────────────────────────────────────────────────────┐
│  💰 Expense      │ Workspace Settings                                            │
│  [FB] Family ▾   ├───────────────────────────────────────────────────────────────┤
│  ─────────────   │ ┌───────────────────┐  ┌────────────────────────────────────┐ │
│  🏠 Dashboard    │ │ ▶ General         │  │ Workspace Details                  │ │
│  💸 Transactions │ │   Members         │  │ ┌──────────────────────────────┐   │ │
│  📊 Reports      │ │   Currency        │  │ │ Name: Family Budget 🏠       │   │ │
│  🎯 Budgets      │ │   Notifications   │  │ └──────────────────────────────┘   │ │
│  🔄 Recurring    │ │   Categories      │  │ ┌──────────────────────────────┐   │ │
│  ─────────────   │ │   Danger Zone     │  │ │ Currency: USD  (locked)      │   │ │
│  👥 Members      │ └───────────────────┘  │ └──────────────────────────────┘   │ │
│  ⚙️  Settings  ◀  │   Settings sub-nav     │ [Save Changes]                     │ │
│  🔔 Notifs [3]   │                         │                                    │ │
│  ─────────────   │                         │ Members (3)   [✉️ Invite Member]   │ │
│  [AH] Ahmad H.   │                         │ ┌──────────────────────────────┐   │ │
│                  │                         │ │[AH] Ahmad Hassan (you) OWNER  │   │ │
│                  │                         │ │[SR] Sara Rahman        ADMIN ✕│   │ │
│                  │                         │ │[MK] Mike Kim          MEMBER ✕│   │ │
│                  │                         │ └──────────────────────────────┘   │ │
│                  │                         │                                    │ │
│                  │                         │ Notification Preferences           │ │
│                  │                         │ Budget Alerts      [● toggle ON ]  │ │
│                  │                         │ Monthly Summary    [● toggle ON ]  │ │
│                  │                         │ Recurring Reminders[○ toggle OFF]  │ │
│                  │                         │ Push Notifications [● toggle ON ]  │ │
│                  │                         └────────────────────────────────────┘ │
└──────────────────┴───────────────────────────────────────────────────────────────┘
```

**Member role rules:**
- `OWNER` — cannot be removed; no ✕ shown
- `ADMIN` — can remove `MEMBER`s; can self-leave
- `MEMBER` — can only self-leave (✕ on own row only)

**API:**
- `PUT /workspaces/:id` — rename workspace
- `POST /workspaces/:id/invite-link` — generate invite (SendGrid email)
- `DELETE /workspaces/:id/members/:userId` — remove member
- `PUT /workspaces/:id/members/:userId/role` — change role (OWNER/ADMIN only)

---

## Shared Component Reference

### Budget Bar (Mobile + Web)   

```
[ICON]  Category Name                $spent / $total
        ████████████░░░░░░░░░░░░░░░    78%
        ←── filled ──→←── empty ─────→ ← pct label
```

Colour thresholds (apply consistently across M2, M5, W2, W4, W5):
- `< 80%`  → `#10B981` (green)
- `80–99%` → `#F59E0B` (amber)
- `≥ 100%` → `#EF4444` (red)

---

### Transaction Row (Mobile)

```
┌──────────────────────────────────────────────────┐
│  [CAT ICON]  Title                    AMOUNT      │
│              Category · Added by · Date           │
└──────────────────────────────────────────────────┘
  Swipe ←  delete  (confirm dialog)
  Swipe →  edit    (opens M4 bottom sheet pre-filled)
  Tap      detail sheet
```

### Transaction Row (Web Table)

```
│ ☐ │ Jun 17  │ Starbucks           │ 🍕 Food │ AH │ -$6.50   │ Edit │
│ ☐ │ Jun 1   │ Monthly Salary      │ 💼 Inc  │ AH │ +$4,200  │ Edit │
```

Negative amounts: `#EF4444`. Positive: `#10B981`. Both bold (`font-weight: 700`).

---

### Notification Row

```
┌────────────────────────────────────────────────────────┐
│ [●] [TYPE ICON]  Title                       Timestamp  │  ← [●] = unread dot
│                  Body text (1–2 lines)                  │    indigo left border if unread
│                  [Action btn]  (INVITE type only)       │
└────────────────────────────────────────────────────────┘
```

---

### Amount Display Convention

```
Expense:   -$87.40    font-weight: 700   color: #EF4444
Income:   +$4,200.00  font-weight: 700   color: #10B981
```

Always 2 decimal places. API integer (cents) ÷ 100 → display string. Never pass floats to the API.
