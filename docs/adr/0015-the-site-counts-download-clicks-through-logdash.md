# 0015 - The site counts download clicks through Logdash

Status: accepted

## Context

The Bestboy dashboard on Logdash shows, for each app, how many visitors reach a page and how many go on to download it.
Grip's and Malini's sites already report to it (Malini's ADR 0059), and the bestboy.dev home page sends `tony_web_download_started` from its own download menu.
Tony's site sent nothing, so its pages were missing from Tony's page-to-download funnel.
ADR 0013 says a new outbound call or event is a new decision.
That ADR covers the app; this one covers only the site at bestboy.dev/tony, and changes nothing the app sends.

## Decision

- Every page of the site loads Logdash's script, deferred, from `/tony/_ld/script.js`, with `data-site` set to `LOGDASH_SITE` (`site/src/lib/logdash.ts`), the bestboy.dev site that Grip and Malini use, and `data-endpoint` `/tony/_ld/events`.
  A development server (`pnpm dev`) loads no script.
- The Worker (`site/worker/index.ts`) serves both paths first-party, as Grip's does: the script from `https://logdash.io/sdk/web.js`, cached for an hour, and the events to `https://api.logdash.io/web_events` with the visitor's `Origin`, `User-Agent`, and IP address in `X-Logdash-Client-IP`.
  It passes a batch only when it holds 1 to 20 events, all on a `/tony` path, for `LOGDASH_SITE`, in at most 32 KB of JSON.
- Logdash itself counts page views and exits.
- `press` (`site/src/lib/track.ts`) sends one event, on every click and middle click of a link to `DOWNLOAD_URL`: `tony_web_download_started` with `{ app: 'tony', menu: 'tony-<place>' }`.
  The place is the nearest `data-place` or section id: `bar`, `hero`, `start`, or `footer`.
- Site events start with `tony_web_`, and their props never hold personal data.
- Grip's other site events (section views, scroll depth, other clicks) stay out until someone needs them.

## Consequences

- The dashboard shows how many visitors of each Tony page start a download, and from which place.
- The site makes one more request per page, to its own origin, and the visitor's IP address and User-Agent reach Logdash, which counts people per day and follows nobody.
- A download link outside the four places reports `tony-page`, so a new one needs a `data-place`.
- `site/tests/site.test.ts` fails when a page loses the script, when a download link on the home page leaves its place, or when the Worker passes a batch that is not from a Tony page.
- The privacy page on the site says what the site counts.
