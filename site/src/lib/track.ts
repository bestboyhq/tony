// What the page reports to Logdash: each press of a download link, by the part of the page it sits in (ADR 0015).
// Logdash itself counts page views, exits, and errors.
import { DOWNLOAD_URL } from '#lib/links.ts';

// Logdash's script is deferred, so the page can start before it runs; a browser it does not count (an automated one)
// never gets it, and the event is dropped.
function track(name: string, props: Record<string, string>): void {
	if (window.logdash) return window.logdash.track(name, props);
	document
		.querySelector('script[data-site]')
		?.addEventListener('load', () => window.logdash?.track(name, props), { once: true });
}

// Listens in the capture phase, so a press counts before anything else handles it. A middle click opens the link in a
// new tab, so it counts too. The place is the nearest `data-place` or section id: bar, hero, start, or footer.
export function press(event: MouseEvent): void {
	if (!(event.target instanceof Element) || (event.type === 'auxclick' && event.button !== 1)) return;
	const link = event.target.closest('a[href]');
	if (link?.getAttribute('href') !== DOWNLOAD_URL) return;
	const part = link.closest<HTMLElement>('[data-place], section[id]');
	track('tony_web_download_started', { app: 'tony', menu: `tony-${part?.dataset.place || part?.id || 'page'}` });
}
