// Renders Tony's Open Graph image from the hero (`pnpm og`): builds the site, screenshots its `/og` view at 1200x630
// in the Chrome on this machine, and writes src/lib/assets/og.png. Beside it, og.sha256 holds the hashes of the image
// and of every file the view is drawn from, which the site's tests compare against those files as they are now.

import { execFileSync, spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { once } from 'node:events';
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import { tmpdir } from 'node:os';
import { dirname, extname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const site = join(import.meta.dirname, '..');
export const IMAGE = join(site, 'src/lib/assets/og.png');
export const SUMS = join(site, 'src/lib/assets/og.sha256');

// The view, the root layout and page shell it renders in, and this script, followed through their imports and their
// stylesheets' url()s down to the fonts and images.
const ROOTS = [
	'src/routes/og/+page.svelte',
	'src/routes/+layout.svelte',
	'src/app.html',
	'scripts/og.ts',
];

// SvelteKit's and Node's own modules, links.ts (its URLs and menus never show in the image), and what is not a file.
const SKIP =
	/^(?:node:|svelte(?:\/|$)|\$app\/|\$env\/|#lib\/links\.ts$|#(?!lib\/)|data:|https?:)|\$types$/u;

function locate(specifier: string, from: string): string | undefined {
	const path = specifier.replace(/\?.*$/u, '');
	if (SKIP.test(path)) return undefined;
	if (/^[#$]lib\//u.test(path)) return join(site, 'src/lib', path.slice(5));
	if (path.startsWith('.')) return resolve(dirname(from), path);
	return fileURLToPath(import.meta.resolve(path));
}

function sources(): string[] {
	const files = new Set<string>();
	const visit = (file: string): void => {
		if (files.has(file)) return;
		if (!existsSync(file))
			throw new Error(`The Open Graph image's view imports ${file}, which does not exist`);
		files.add(file);
		if (!/\.(?:svelte|ts|css)$/u.test(file)) return;
		const text = readFileSync(file, 'utf8');
		for (const [, imported, linked] of text.matchAll(
			/\bimport\s*(?:[^'"]*?\bfrom\s*)?['"]([^'"]+)['"]|\burl\(\s*['"]?([^'")]+)/gu,
		)) {
			const found = locate(imported ?? linked ?? '', file);
			if (found) visit(found);
		}
	};
	for (const root of ROOTS) visit(join(site, root));
	return [...files];
}

// A path from site/, a package's file by its name rather than by pnpm's store.
const name = (file: string): string =>
	relative(site, file).replace(/^node_modules\/\.pnpm\/[^/]+\/node_modules\//u, 'node_modules/');

const sha256 = (file: string): string =>
	createHash('sha256').update(readFileSync(file)).digest('hex');

/** og.sha256 as it should read now: the image's hash and those of the files it is drawn from. */
export function sums(): string {
	const lines = [IMAGE, ...sources()]
		.map((file) => `${sha256(file)}  ${name(file)}`)
		.sort((a, b) => a.slice(66).localeCompare(b.slice(66)));
	const header =
		'# og.png and the files it is drawn from. `pnpm og` in site/ writes this; the tests fail when it is stale.';
	return `${header}\n${lines.join('\n')}\n`;
}

const TYPES: Record<string, string> = {
	'.html': 'text/html',
	'.js': 'text/javascript',
	'.css': 'text/css',
	'.json': 'application/json',
	'.png': 'image/png',
	'.webp': 'image/webp',
	'.svg': 'image/svg+xml',
	'.woff2': 'font/woff2',
};

// The build, served at /tony like the Worker serves it: a page at its URL without .html.
async function serve(): Promise<{ url: string; close: () => void }> {
	const build = join(site, 'build');
	const server = createServer((request, response) => {
		const path = join(
			build,
			decodeURIComponent(new URL(request.url ?? '/', 'http://localhost').pathname),
		);
		const file = [path, `${path}.html`].find(
			(candidate) =>
				candidate.startsWith(build + sep) && existsSync(candidate) && statSync(candidate).isFile(),
		);
		if (!file) {
			response.writeHead(404).end();
			return;
		}
		response.writeHead(200, { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream' });
		response.end(readFileSync(file));
	});
	server.listen(0, '127.0.0.1');
	await once(server, 'listening');
	return {
		url: `http://127.0.0.1:${(server.address() as AddressInfo).port}`,
		close: () => {
			server.close();
			server.closeAllConnections();
		},
	};
}

const CHROME =
	process.env.CHROME ??
	[
		'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
		'/usr/bin/google-chrome',
		'/usr/bin/chromium',
	].find((path) => existsSync(path));

// Fails a step after 30 s, so a Chrome that hangs fails the render instead of stalling it.
async function within<T>(step: Promise<T>, what: string): Promise<T> {
	let timer: NodeJS.Timeout | undefined;
	const late = new Promise<never>((_, fail) => {
		timer = setTimeout(() => fail(new Error(`${what} took over 30 s`)), 30_000);
	});
	try {
		return await Promise.race([step, late]);
	} finally {
		clearTimeout(timer);
	}
}

type Chrome = {
	/** Sends a DevTools protocol command to the page. */
	send: (method: string, params?: object) => Promise<any>;
	/** Resolves on the page's next `event`. */
	next: (event: string) => Promise<void>;
	quit: () => Promise<void>;
};

// A headless Chrome of its own, with a fresh profile, driven over the DevTools protocol.
async function launch(): Promise<Chrome> {
	if (!CHROME)
		throw new Error('No Chrome found: set CHROME to the path of a Chrome or Chromium binary');
	const profile = mkdtempSync(join(tmpdir(), 'tony-og-'));
	const chrome = spawn(
		CHROME,
		[
			'--headless',
			'--remote-debugging-port=0',
			`--user-data-dir=${profile}`,
			'--no-first-run',
			'--no-default-browser-check',
			'--hide-scrollbars',
			'--force-color-profile=srgb',
			'--force-device-scale-factor=1',
			// Taller than the card the page emulates: in a shorter window (headless Brave keeps 81 px of it for a
			// toolbar), the bottom of the screenshot now and then shows the top of the page.
			'--window-size=1200,1000',
			'about:blank',
		],
		{ stdio: ['ignore', 'ignore', 'pipe'] },
	);
	let log = '';
	chrome.stderr.on('data', (chunk: Buffer) => (log += chunk));
	const quit = async (): Promise<void> => {
		if (chrome.exitCode === null && chrome.signalCode === null) {
			chrome.kill();
			await once(chrome, 'exit');
		}
		rmSync(profile, { recursive: true, force: true });
	};
	try {
		const port = await within(
			new Promise<string>((done, fail) => {
				chrome.stderr.on('data', () => {
					const listening = /DevTools listening on ws:\/\/[^/]+:(\d+)\//u.exec(log)?.[1];
					if (listening) done(listening);
				});
				chrome.on('exit', (code, signal) =>
					fail(new Error(`Chrome quit (${code ?? signal}):\n${log.slice(-2000)}`)),
				);
			}),
			'Starting Chrome',
		);
		const targets = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()) as {
			type: string;
			webSocketDebuggerUrl: string;
		}[];
		const socket = new WebSocket(
			targets.find((target) => target.type === 'page')?.webSocketDebuggerUrl ?? '',
		);
		await within(
			new Promise((done, fail) => {
				socket.addEventListener('open', done);
				socket.addEventListener('error', () =>
					fail(new Error('Chrome refused the DevTools connection')),
				);
			}),
			'Connecting to Chrome',
		);

		let id = 0;
		const calls = new Map<number, { done: (result: any) => void; fail: (error: Error) => void }>();
		const waiting = new Map<string, () => void>();
		socket.addEventListener('message', ({ data }) => {
			const message = JSON.parse(String(data));
			if (message.method) waiting.get(message.method)?.();
			const call = calls.get(message.id);
			if (!call) return;
			calls.delete(message.id);
			if (message.error) call.fail(new Error(`${message.error.message} (${message.error.code})`));
			else call.done(message.result);
		});
		socket.addEventListener('close', () => {
			for (const call of calls.values())
				call.fail(new Error(`Chrome went away:\n${log.slice(-2000)}`));
			calls.clear();
		});
		return {
			send: (method, params = {}) =>
				new Promise((done, fail) => {
					calls.set(++id, { done, fail });
					socket.send(JSON.stringify({ id, method, params }));
				}),
			next: (event) => new Promise((done) => waiting.set(event, done)),
			quit: async () => {
				socket.close();
				await quit();
			},
		};
	} catch (error) {
		await quit();
		throw error;
	}
}

// In the page: wait until every font, image, and canvas on the card has drawn, then report what would make the
// screenshot wrong.
async function settle(): Promise<string[]> {
	const problems: string[] = [];
	const [navigation] = performance.getEntriesByType('navigation') as PerformanceNavigationTiming[];
	if (navigation?.responseStatus !== 200)
		problems.push(`/og answered ${navigation?.responseStatus}`);
	const faces = await document.fonts.load('550 80px "Inter Variable"', 'Talk');
	if (!faces.length) problems.push('the headline is not in Inter');
	await Promise.all([...document.images].map((image) => image.decode()));
	// The glow sizes its canvas to its box when it draws.
	const drawn = (): boolean =>
		[...document.querySelectorAll('canvas')].every((canvas) => canvas.width === canvas.clientWidth);
	for (let tries = 0; !drawn() && tries < 100; tries++)
		await new Promise((done) => setTimeout(done, 50));
	if (!drawn()) problems.push('the glow never drew (no WebGL?)');
	await new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done)));
	if (document.getAnimations().length) problems.push('something on the card still animates');
	const { scrollWidth, scrollHeight } = document.documentElement;
	if (scrollWidth !== 1200 || scrollHeight !== 630)
		problems.push(`the card is ${scrollWidth}x${scrollHeight}`);
	return problems;
}

async function render(): Promise<Buffer> {
	const server = await serve();
	try {
		const chrome = await launch();
		try {
			await chrome.send('Page.enable');
			await chrome.send('Emulation.setDeviceMetricsOverride', {
				width: 1200,
				height: 630,
				deviceScaleFactor: 1,
				mobile: false,
			});
			await chrome.send('Emulation.setEmulatedMedia', {
				features: [{ name: 'prefers-color-scheme', value: 'dark' }],
			});
			const loaded = chrome.next('Page.loadEventFired');
			await chrome.send('Page.navigate', { url: `${server.url}/tony/og` });
			await within(loaded, 'Loading the card');
			const { result, exceptionDetails } = await within(
				chrome.send('Runtime.evaluate', {
					expression: `(${settle})()`,
					awaitPromise: true,
					returnByValue: true,
				}),
				'Settling the card',
			);
			if (exceptionDetails)
				throw new Error(`The card failed to settle: ${exceptionDetails.exception?.description}`);
			if (result.value.length) throw new Error(`The card is not ready: ${result.value.join('; ')}`);
			const [first, second] = [
				(await chrome.send('Page.captureScreenshot', { format: 'png' })).data,
				(await chrome.send('Page.captureScreenshot', { format: 'png' })).data,
			];
			if (first !== second)
				throw new Error('Two screenshots of the card differ: something on it moves or tears');
			return Buffer.from(first, 'base64');
		} finally {
			await chrome.quit();
		}
	} finally {
		server.close();
	}
}

if (import.meta.main) {
	// A fresh build, so the image shows the hero as the files have it now.
	execFileSync('pnpm', ['run', '--silent', 'build'], { cwd: site, stdio: 'inherit' });
	const png = await render();
	const [width, height] = [png.readUInt32BE(16), png.readUInt32BE(20)];
	if (width !== 1200 || height !== 630)
		throw new Error(`Chrome took a ${width}x${height} screenshot, not 1200x630`);
	writeFileSync(IMAGE, png);
	writeFileSync(SUMS, sums());
	console.log(`Rendered ${name(IMAGE)} (${Math.round(png.length / 1024)} KB) and ${name(SUMS)}`);
}
