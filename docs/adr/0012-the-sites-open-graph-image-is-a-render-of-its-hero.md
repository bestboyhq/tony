# 0012 - The site's Open Graph image is a render of its hero

Status: accepted

## Context

ADR 0009 gave every page of the site the 1200x630 `site/static/og.png`, which was composed by hand at launch, and nothing rendered it again when the hero changed.
Malini's Open Graph image went stale exactly that way: its headline changed, and its image kept the old one.
Facebook, X, LinkedIn, and Slack cache an image by its URL, so even a new image at the old URL keeps showing the old one.
Every Bestboy site now follows one rule for the image (bestboy.dev, Tony, Grip, Malini): the page's hero cropped to 1200x630, rendered from the hero's own components, guarded by a test, at a URL that changes with its content.
The site ships one script and one stylesheet for all its pages (`output.bundleStrategy: 'single'` in `site/vite.config.ts`), so a hash of what the image's page loads would change with every page, not only with the hero.
The repository has no browser, and the rule prefers a browser already at hand over a new dependency.

## Decision

Still from ADR 0009:

- `site/` is a SvelteKit 3 site, prerendered with `@sveltejs/adapter-static` under the base path `/tony`, ported from Malini's `apps/site`.
  It has its own `package.json` and `pnpm-lock.yaml`, and pnpm resolves only versions at least 48 hours old (`site/pnpm-workspace.yaml`).
- The docs are markdown in `site/content/`, one page per topic people search for.
  Every page is also served as markdown at its URL plus `.md`, and listed in `llms.txt`, `llms-full.txt`, and `sitemap.xml`.
- The home page carries `SoftwareApplication` structured data, and every page a canonical URL, a description, and Open Graph and Twitter tags.
- The Cloudflare Worker `tony-site` (`site/worker/index.ts`, `site/wrangler.jsonc`) serves the build on the route `bestboy.dev/tony*`: it drops trailing slashes with a 301, marks every host but bestboy.dev `noindex`, never sets cookies, and caches hashed assets for a year.
  It deploys with `npx wrangler@4 deploy` from `site/`.
- The site loads nothing from another origin and sets no cookies: no analytics, and its fonts, Inter and JetBrains Mono (both OFL-1.1), are served from `/tony/_app/` like the rest of the build.
  The theme switch keeps the reader's choice in `localStorage`, on their own device.
- The site follows Bestboy's design: its tokens, frame, bar, footer, theme switch, and components are copied from Malini's site, which implements it, and its beats use the shapes `docs/design.md` names.
- Every fact on the site comes from the README or the code, and the site names no competing product.

New:

- The hero is one component, `site/src/lib/Hero.svelte`.
  The home page renders it with its lede, buttons, and fine print; the view `site/src/routes/og/` renders it as the image shows it (`card`): 1200x630 in the dark theme, settled, with no entrance animation and the pill's first frame, which the page paints first, its headline at 80 px for a feed's small preview, and the stage cut off by the bottom edge.
  The view is `noindex` and stays out of the sitemap.
- The pages with the bar and footer sit in the route group `site/src/routes/(site)/`, whose layout adds them, so the view gets only what the root layout gives every page: the fonts and the global styles.
- `pnpm og` in `site/` runs `site/scripts/og.ts`: it builds the site, serves the build, and opens `/og` at 1x in a headless Chrome of its own (the machine's; `CHROME` names another) over the DevTools protocol, with Node's own `WebSocket`.
  It waits for the fonts, the images, and the glow, takes two screenshots, and writes `site/src/lib/assets/og.png` only when they match.
- Beside the image, `og.sha256` holds the SHA-256 of the image and of every file the view is drawn from: the view, the root layout, `app.html`, and the script, followed through their imports and their stylesheets' `url()`s down to the fonts and images.
  SvelteKit's and Node's modules are not followed, and neither is `links.ts`, whose URLs and menus never show in the image.
- `site/src/lib/Head.svelte` imports the image, so Vite names it by its content (`/tony/_app/immutable/assets/og.<hash>.png`), and every page's `og:image` and `twitter:image` point at that URL.
  They keep `og:image:width`, `og:image:height`, an `og:image:alt` that quotes the headline, and `twitter:card` `summary_large_image`.

## Consequences

- Still from ADR 0009: the repository has two toolchains, Swift for the app and Node 24 with pnpm for the site; a pull request that changes only the site is titled `docs:`, so it ships no app release (ADR 0005); a user-visible feature change updates `site/content` in the same pull request (`AGENTS.md`); the root sitemap index and the root `llms.txt` at bestboy.dev live in the platform repository; and a change to Bestboy's design lands in `docs/design.md` first, then in each site by hand.
- A change to what the image shows (the hero's copy or styles, the glow, the pill, the fonts, the global styles) fails the tests until `pnpm og` renders the image again, and the failure names the changed files and the command.
  A change anywhere else on the site leaves the image alone.
- Rendering needs Chrome and checking does not, so CI checks the image on every pull request without a browser.
- The same hero renders the same bytes in the same Chrome on the same machine; another Chrome may antialias an icon differently, and its render rewrites both files.
- The hashes follow imports and `url()`s, so a file the view loads another way, such as a path into `site/static/` or a string passed to `asset()`, is not covered; such a file belongs in an import.
- The old URL, bestboy.dev/tony/og.png, is gone; posts shared before keep the copy each platform cached.
- Enforced by `site/tests/site.test.ts` (canonical URLs, unique titles and descriptions, JSON-LD, image sizes and alt text, fonts and images from no other origin, the sitemap, `llms.txt`, the Worker's redirects and headers, `og.sha256` against the files, and every page's image URL, size, and alt) and the `site` job in `.github/workflows/ci.yml`, which builds, type-checks, and tests the site on every pull request.
- Nothing enforces that the site's facts match the app.
