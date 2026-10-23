# FitGen Admin Panel — Implementation Tracker & Roadmap

This document outlines the architecture, completed milestones, and pending task checklists for the FitGen Admin Dashboard.

---

## ✅ Completed Milestones

### Phase 1: Foundations & Architecture
- [x] **Capability Model (`lib/core/admin_session.dart`)**:
  - Gated via `platformAdmins/{uid}` capabilities (`users_read`, `users_manage`, `studio_activation`, `plans_manage`, `features_manage`, `support`, `campaigns_manage`, `analytics_read`, `admins_manage`, `ai_configuration`).
  - Added `canAny(...)` helper for multi-capability screens.
- [x] **Reusable Component Library (`lib/core/widgets/`)**:
  - `MetricCard`: Real-time operational metric cards with asynchronous Future/Stream builders and color tinting.
  - `StatusBadge`: Unified status badges across users, studios, plans, tickets, and campaigns.
  - `ConfirmDialog`: Standardized destructive/administrative modal requiring mandatory audit justification.
  - `EmptyState`: Responsive placeholder with icon, message, and action triggers.
- [x] **Responsive Shell & Routing (`lib/app.dart`, `lib/features/shell/admin_shell.dart`)**:
  - Modern expanding side navigation with capability-based item filtering.
  - `GoRouter` configuration covering all 8 core operational domains.
  - Enhanced Operations Dashboard (`/`) tracking real-time user, partner, and support queue volumes.

### Phase 2: Partner & Studio Management Module
- [x] **Studio Backend Callables (`lib/core/admin_api.dart`)**:
  - `setStudioLifecycleStatus`: State machine transitions (`pending_verification`, `active`, `paused`, `suspended`, `archived`) with attestations.
  - `recordStudioIdentityVerification`: Records operator identity and compliance verification.
  - `getStudioReadiness`: Retrieves server-side readiness evaluation.
  - `onboardPartner`: Idempotent studio registration.
- [x] **Studio Onboarding Dialog (`create_partner_dialog.dart`)**:
  - Modal form for creating partner studios with IANA timezone selector, country code, contact details, and primary address.
- [x] **Studio Directory (`partners_screen.dart`)**:
  - Live Firestore stream on `partners`, search by studio name/ID, and status filtering.
- [x] **Studio Detail View (`partner_detail_screen.dart`)**:
  - Context-aware action buttons: *Verify Identity*, *Activate Studio*, *Pause Bookings*, *Suspend*, *Resume*, *Reinstate*.
  - 5 inspection tabs: *Overview & Primary Location*, *Server Readiness & Checklist*, *Class Types & Schedule*, *Instructors & Staff*, *Policy & Access Config*.

### Deployment & CI/CD
- [x] **GitHub Pages CI/CD Workflow (`.github/workflows/deploy.yml`)**:
  - Automated workflow triggering on push to `main`.
  - Runs analyzer, tests, compiles web release with base-href `/fitgen-admin/`.
  - Generates `404.html` copy of `index.html` for client-side deep linking on GitHub Pages.
  - Automated deployment via `actions/deploy-pages@v4`.

---

## 📋 Remaining Phases TODO

### Phase 3: Plans & Entitlements Management (`/plans`)
- [ ] **Studio Allowance Plans (Phoenix Pass Model)**:
  - [ ] Connect to `partners/{id}/plans` subcollections to view recurring plans (4, 8, N or unlimited visits).
  - [ ] Create plan dialog: define visit count, period anchor day, rollover cap (`maxCarry`), and eligible class types.
  - [ ] Active member enrollments view (`planEnrollments`): period dates, remaining balance, and rollover history.
  - [ ] Period management: triggers for `issuePlanPeriod` and manual `settlePlanRollover`.
- [ ] **FitGen Platform Subscriptions (Free vs Pro)**:
  - [ ] Platform plan matrix view: monthly/annual pricing, coin allowances, and feature entitlements.
  - [ ] Active subscriber inspector: query users by `subscriptionType == 'pro'` and inspect IAP purchase tokens.
- [ ] **AI & FG Coach Living Plans**:
  - [ ] AI plan generator usage monitor: inspect generation quotas, coin costs, and goal horizons.
  - [ ] Living plan overrides and adjustments for individual users.

### Phase 4: Full User Moderation & Wallet Operations (`/users`)
- [ ] **User Detail Screen Tab Enhancement**:
  - [ ] Tab 1: *Overview & Profile* (name, email, phone, completion status, assigned roles like mentor/trainer).
  - [ ] Tab 2: *Wallet & Coins* (current coin balance, coin ledger stream from `coinTransactions`, and adjustment dialog).
  - [ ] Tab 3: *Bookings & Passes* (active reservations, waitlist status, check-in history).
  - [ ] Tab 4: *Feature Overrides* (per-user toggles from `userFeatureAccess/{uid}`).
  - [ ] Tab 5: *Risk & Audit* (risk flags from `accountFlags`, moderation audit trail).
- [ ] **Administrative Wallet Operations**:
  - [ ] Backend callable: `adminAdjustCoins` using the centralized `coinService.js` ledger with mandatory audit reason.
- [ ] **Account Security Controls**:
  - [ ] Password reset trigger via Firebase Auth link.
  - [ ] Revoke user refresh tokens to force instant logout on suspended accounts.

### Phase 5: Support Tickets, User Reports & Moderation (`/support`)
- [ ] **Support Ticket Inbox**:
  - [ ] Triage queue filterable by status (`open`, `in_progress`, `resolved`, `closed`), priority, and category (bug, account, payment, report).
  - [ ] Ticket thread view: user messages and admin replies.
  - [ ] Cloud Function: `adminReplyTicket` with push notification delivery to user.
- [ ] **User Abuse & Content Moderation**:
  - [ ] Report user triage queue: view reporting user, reported user, reason, and attached evidence.
  - [ ] 1-click moderation action: suspend or block reported user directly from the ticket view.
- [ ] **Customer Feedback Board**:
  - [ ] Rating distribution chart (1–5 stars).
  - [ ] Feedback table with screen name, app version, tags, and "Mark as Actioned".
  - [ ] Export feedback to CSV.

### Phase 6: Feature Flags, Campaigns & System Audit (`/features`, `/campaigns`, `/admins`)
- [ ] **Feature Flags & AI Controls (`/features`)**:
  - [ ] Global feature matrix (`appConfig/featureFlags`): toggles for `fg_coach`, `ai_partner_search`, `future_you_studio`, `fit_squad`, `challenges`.
  - [ ] Rollout percentage slider (0–100%) and killswitches.
  - [ ] AI guardrails: provider status (Gemini/OpenAI), active spend allowances, and emergency AI killswitch.
- [ ] **Campaigns & Marketing (`/campaigns`)**:
  - [ ] Campaign creation wizard: push broadcasts, discount coupons (`coupons`), and fitness challenges.
  - [ ] Audience builder: target by tier, activity threshold, or city.
  - [ ] Campaign state machine: `draft` $\rightarrow$ `pending_approval` $\rightarrow$ `scheduled` $\rightarrow$ `live` $\rightarrow$ `ended`.
- [ ] **Platform Admins & Audit Log (`/admins`)**:
  - [ ] Admin management: list admins, grant/revoke capabilities (`platformAdmins/{uid}`), and set expiration dates.
  - [ ] Immutable Audit Log Viewer: searchable stream on `adminAuditLog` with actor UID, action taken, before/after diffs, and justification reason.
