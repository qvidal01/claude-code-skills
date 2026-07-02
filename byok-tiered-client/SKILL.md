---
name: byok-tiered-client
user-invocable: false
description: "Reusable architecture pattern + decision framework for building a client (mobile / web / desktop) against a hosted backend that offers a FREE intro tier, BYOK (bring-your-own-key), and cross-device sync. Covers the tiered key-resolution precedence (BYOK -> free-tier hosted -> server keys), the privacy-vs-sync tradeoff, and a client integration checklist. TRIGGER WHEN: designing or building an app with a 'free trial then bring your own API key' model, an account-synced backend, or a BYOK + hosted free-tier mix; deciding local-first vs cloud-synced. DO NOT USE WHEN: the app has no hosted backend, or no BYOK / free-tier concept. Concrete reference implementation: Subjectly (subjectly-backend _resolve_llm + /subjectly-mobile-dev)."
---

# /byok-tiered-client — BYOK + free-tier + account-sync pattern

A reusable design for products where users **try free**, then **bring their own API key**, across **multiple synced clients** (web + mobile + desktop). Backend- and client-agnostic; the names below are placeholders for whatever your stack calls them.

## 1. Tiered key resolution (server-side, per request)
The **backend** — not the client — decides which key signs each inference request, in precedence:
1. **BYOK** — user saved their own key → use it (their key pays). Applies to free AND paid users.
2. **Free-tier hosted** — no BYOK + eligible tier → the company's hosted key/proxy (e.g. an OpenRouter key), **metered** against per-user limits.
3. **Server keys** — fallback (paid users without BYOK, or free users when hosting is off).
4. else → require a key / prompt upgrade.

Keep this in **one** backend resolver so every endpoint shares it; clients never branch on it — they call the backend and get an answer (plus usage info on the free tier). Make it **additive**: with no BYOK key, behavior is unchanged.

## 2. The privacy ↔ sync tradeoff (the core decision)
You can have at most **two of three**: { local-only privacy, BYOK, cross-device sync }.
- **(A) Account-synced — recommended default.** Data lives server-side keyed to the account → syncs across devices for free; BYOK only changes *whose key pays*. Simple; best fit for a trial→paid funnel. **Backend = system of record** (accounts, documents, chats, settings incl. BYOK keys *encrypted*).
- **(B) Local-only privacy mode.** Data + processing on-device → **no** cross-device sync (until you add end-to-end-encrypted sync, a bigger build). Offer as an explicit toggle for privacy users.

Ship **(A)** as the default; add **(B)** as an option later. Don't let an app that started local-first silently stay that way once you add a free tier — that combination can't cross-device-sync.

## 3. Client integration checklist
- [ ] Point at the **hosted backend** (prod base URL); env-switch for dev.
- [ ] **Token auth** (JWT/bearer): login / refresh / me; store the token in secure storage.
- [ ] **Support not-BYOK users** (free tier): the app must work with NO user key — the backend serves hosted AI.
- [ ] **BYOK entry → save to the backend** (encrypted, account-synced) so the key is used server-side and follows the user across devices — rather than only on-device direct-to-provider calls (which break sync and don't meter).
- [ ] **Read entitlements** (`/entitlements` or equivalent) → tier + feature flags; gate UI accordingly.
- [ ] **Handle metering / limits:** expect HTTP **429** with limit detail on the free tier; surface "add your own key / upgrade" UX.
- [ ] **Graceful "hosted AI unavailable":** the free tier is often config-gated (provider key / enable flag unset) before launch.
- [ ] If keeping a **local-only privacy mode**, make it an explicit toggle and state clearly it disables cross-device sync.

## 4. Operator config (turning the free tier on)
The hosted free tier is typically gated by backend config: a hosted-provider key + an enable flag + per-user daily limits. In Subjectly: `OPENROUTER_API_KEY`, `HOSTED_AI_ENABLED`, `FREE_DAILY_QUERY_LIMIT` / `FREE_DAILY_TOKEN_LIMIT`. Until set, hosted requests don't serve — clients must degrade gracefully.

## 5. Reference implementation (Subjectly)
- **Backend resolver:** `subjectly-backend` `app/routers/query.py:_resolve_llm` (precedence above), wired into `/query` + `/studio/*`; metering via `token_metering`.
- **Clients:** **/subjectly-mobile-dev** (Flutter) and subjectly-web. Topology + backend deploy in [[reference_subjectly_deploy]].
