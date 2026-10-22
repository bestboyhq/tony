# 0009 - A prerendered website at bestboy.dev/tony

Status: accepted

## Context

Nobody searches for "Tony": people search for a free dictation app for Mac, offline speech to text, private voice typing, or open source dictation, and the README on GitHub ranks for none of them.
Malini, Tony's sibling, already runs such a site (`apps/site` in `bestboyhq/malini`): a prerendered SvelteKit site with markdown docs, `llms.txt`, and a Cloudflare Worker on `bestboy.dev/malini*`.
The site is not the app: ADR 0002's Swift-only rule is about what runs on the Mac, and nothing in the app's build reads the site.
Tony promises privacy (ADR 0001), so its website must not track the people reading it.
Bestboy's design (`docs/design.md` in `bestboyhq/platform`) gives every public page of the family one look, so bestboy.dev, bestboy.dev/malini, and bestboy.dev/tony read as one site.

## Decision

- `site/` is a SvelteKit 3 site, prerendered with `@sveltejs/adapter-static` under the base path `/tony`, ported from Malini's `apps/site`.
  It has its own `package.json` and `pnpm-lock.yaml`, and pnpm resolves only versions at least 48 hours old (`site/pnpm-workspace.yaml`).
- The docs are markdown in `site/content/`, one page per topic people search for.
  Every page is also served as markdown at its URL plus `.md`, and listed in `llms.txt`, `llms-full.txt`, and `sitemap.xml`.
- The home page carries `SoftwareApplication` structured data, and every page a canonical URL, a description, Open Graph and Twitter tags, and the 1200x630 `site/static/og.png`.
- The Cloudflare Worker `tony-site` (`site/worker/index.ts`, `site/wrangler.jsonc`) serves the build on the route `bestboy.dev/tony*`: it drops trailing slashes with a 301, marks every host but bestboy.dev `noindex`, never sets cookies, and caches hashed assets for a year.
  It deploys with `npx wrangler@4 deploy` from `site/`.
- The site loads nothing from another origin and sets no cookies: no analytics, unlike Malini's site, and its fonts, Inter and JetBrains Mono (both OFL-1.1), are served from `/tony/_app/` like the rest of the build.
  The theme switch keeps the reader's choice in `localStorage`, on their own device.
- The site follows Bestboy's design: its tokens, frame, bar, footer, theme switch, and components are copied from Malini's site, which implements it, and its beats use the shapes `docs/design.md` names.
- Every fact on the site comes from the README or the code, and the site names no competing product.

## Consequences

- The repository has two toolchains: Swift for the app, and Node 24 with pnpm for the site.
- A pull request that changes only the site is titled `docs:`, so it ships no app release (ADR 0005).
- A user-visible feature change updates `site/content` in the same pull request (`AGENTS.md`).
- The root sitemap index and the root `llms.txt` at bestboy.dev live in the platform repository, not here.
- A change to Bestboy's design lands in `docs/design.md` first, then in each site by hand, this one included.
- Enforced by `site/tests/site.test.ts` (canonical URLs, unique titles and descriptions, JSON-LD, image sizes and alt text, fonts and images from no other origin, the sitemap, `llms.txt`, the Worker's redirects and headers) and the `site` job in `.github/workflows/ci.yml`, which builds, type-checks, and tests the site on every pull request.
- Nothing enforces that the site's facts match the app.
