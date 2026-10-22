import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import { test } from 'node:test';
import worker, { type Env } from '../worker/index.ts';

const SITE = 'https://bestboy.dev/tony';
const root = join(import.meta.dirname, '..');
const build = join(root, 'build', 'tony');
const content = join(root, 'content');

const docPaths = readdirSync(content, { recursive: true, encoding: 'utf8' })
	.filter((file) => file.endsWith('.md'))
	.map((file) => `/docs/${relative(content, join(content, file)).replace(/\.md$/u, '')}`.replace(/\/index$/u, ''));
const htmlPaths = ['', ...docPaths];

function read(path: string): string {
	return readFileSync(join(build, path), 'utf8');
}

function htmlFile(path: string): string {
	return path === '' ? 'index.html' : `${path.slice(1)}.html`;
}

function all(html: string, pattern: RegExp): string[] {
	return [...html.matchAll(pattern)].map((match) => match[1] ?? '');
}

test('llms.txt links the markdown of every content page', () => {
	const llms = read('llms.txt');
	for (const path of docPaths) assert.ok(llms.includes(`(${SITE}${path}.md)`), path);
});

test('every content page is served as markdown next to its page', () => {
	for (const path of docPaths) assert.ok(read(`${path.slice(1)}.md`).length > 0, path);
});

test('llms-full.txt holds every content page', () => {
	const full = read('llms-full.txt');
	for (const path of docPaths) assert.ok(full.includes(`Source: ${SITE}${path}\n`), path);
});

test('every page has one canonical URL under bestboy.dev/tony, and its own title, description, and H1', () => {
	const titles = new Set<string>();
	const descriptions = new Set<string>();
	for (const path of htmlPaths) {
		const html = read(htmlFile(path));
		assert.deepEqual(all(html, /<link rel="canonical" href="([^"]+)"/gu), [`${SITE}${path}`], path);
		const [title] = all(html, /<title>([^<]+)<\/title>/gu);
		const [description] = all(html, /<meta name="description" content="([^"]+)"/gu);
		assert.ok(title && description, path);
		titles.add(title);
		descriptions.add(description);
		assert.equal(all(html, /<h1\b[^>]*>/gu).length, 1, path);
	}
	assert.equal(titles.size, htmlPaths.length, 'titles are unique');
	assert.equal(descriptions.size, htmlPaths.length, 'descriptions are unique');
});

test('the home page leads with talking to your AI agents, and free, private dictation for Mac', () => {
	const html = read('index.html');
	assert.match(html, /<title>Tony - talk to your AI agents\. Free, private dictation for Mac<\/title>/u);
	const h1 = /<h1[^>]*>([\s\S]*?)<\/h1>/u.exec(html)?.[1]?.replace(/<[^>]+>/gu, '').replace(/\s+/gu, ' ').trim();
	assert.equal(h1, 'Talk to your AI agents. Free, private dictation for Mac.');
});

test('the home page describes Tony as a free SoftwareApplication in JSON-LD', () => {
	const [json] = all(read('index.html'), /<script type="application\/ld\+json">([^<]+)<\/script>/gu);
	assert.ok(json);
	const app = JSON.parse(json) as Record<string, unknown>;
	assert.equal(app['@type'], 'SoftwareApplication');
	assert.equal(app.name, 'Tony');
	assert.deepEqual(app.offers, { '@type': 'Offer', price: '0', priceCurrency: 'USD' });
	assert.equal(app.operatingSystem, 'macOS 15 or later');
	assert.equal(app.processorRequirements, 'Apple silicon');
	assert.equal(app.downloadUrl, 'https://github.com/bestboyhq/tony/releases/latest');
	assert.equal(app.license, 'https://www.gnu.org/licenses/agpl-3.0.html');
	for (const key of ['image', 'screenshot'] as const) {
		const url = String(app[key]);
		assert.ok(url.startsWith('https://bestboy.dev/tony/'), url);
		assert.ok(existsSync(join(build, url.slice(SITE.length + 1))), url);
	}
});

test('every image has a size and alt text, and only the hero loads eagerly', () => {
	for (const path of htmlPaths) {
		for (const image of all(read(htmlFile(path)), /(<img\b[^>]*>)/gu)) {
			assert.match(image, /\bwidth="\d+"/u, image);
			assert.match(image, /\bheight="\d+"/u, image);
			assert.match(image, /\balt="[^"]*"/u, image);
		}
	}
	const images = all(read('index.html'), /(<img\b[^>]*>)/gu);
	const lazy = images.filter((image) => image.includes('loading="lazy"'));
	assert.ok(lazy.length >= 3, 'the README images below the fold load lazily');
	for (const image of images.filter((image) => /\.webp"/u.test(image) && /alt="[^"]+"/u.test(image))) {
		assert.ok(/fetchpriority="high"/u.test(image) || image.includes('loading="lazy"'), image);
	}
});

test('every page loads its fonts, styles, scripts, and images from bestboy.dev/tony, no other origin', () => {
	for (const path of htmlPaths) {
		const html = read(htmlFile(path));
		const loads = [
			...all(html, /<(?:script|img|source)\b[^>]*\bsrc="([^"]+)"/gu),
			...all(html, /<link\b[^>]*\brel="(?:stylesheet|preload|modulepreload|icon|apple-touch-icon)"[^>]*\bhref="([^"]+)"/gu),
			...all(html, /url\(["']?([^"')]+)/gu),
		];
		assert.ok(loads.some((url) => url.endsWith('.woff2')), `${path} preloads its font`);
		for (const url of loads) assert.match(url, /^(\/tony\/|data:)/u, `${path}: ${url}`);
	}
});

test('the languages page names all 25 languages', () => {
	const page = read('docs/languages.html');
	const languages = ['Bulgarian', 'Croatian', 'Czech', 'Danish', 'Dutch', 'English', 'Estonian', 'Finnish', 'French', 'German', 'Greek', 'Hungarian', 'Italian', 'Latvian', 'Lithuanian', 'Maltese', 'Polish', 'Portuguese', 'Romanian', 'Russian', 'Slovak', 'Slovenian', 'Spanish', 'Swedish', 'Ukrainian'];
	for (const language of languages) assert.ok(page.includes(`<td>${language}</td>`), language);
});

test('the sitemap lists every page by its canonical URL', () => {
	const locs = all(read('sitemap.xml'), /<loc>([^<]+)<\/loc>/gu);
	assert.deepEqual(locs.toSorted(), htmlPaths.map((path) => `${SITE}${path}`).toSorted());
});

test('the 404 page is not indexed', () => {
	assert.match(read('404.html'), /<meta name="robots" content="noindex"/u);
});

const assets: Env = {
	ASSETS: {
		fetch: (request) =>
			Promise.resolve(
				new Response(new URL(request.url).pathname, {
					headers: { 'Set-Cookie': 'a=b', 'Content-Type': 'text/html' },
				}),
			),
	},
};

function get(url: string): Promise<Response> {
	return worker.fetch(new Request(url), assets);
}

test('the worker marks every host but bestboy.dev noindex and never sets cookies', async () => {
	const canonical = await get('https://bestboy.dev/tony/docs');
	assert.equal(canonical.headers.get('X-Robots-Tag'), null);
	assert.equal(canonical.headers.get('Set-Cookie'), null);
	const preview = await get('https://tony-site.bestboy.workers.dev/tony/docs');
	assert.equal(preview.headers.get('X-Robots-Tag'), 'noindex');
});

test('the worker drops trailing slashes with a permanent redirect', async () => {
	const response = await get('https://bestboy.dev/tony/docs/install/?x=1');
	assert.equal(response.status, 301);
	assert.equal(response.headers.get('Location'), 'https://bestboy.dev/tony/docs/install?x=1');
	assert.equal((await get('https://bestboy.dev/tony/')).headers.get('Location'), SITE);
});

test('the worker caches immutable assets for a year and lets pages revalidate in the background', async () => {
	const asset = await get('https://bestboy.dev/tony/_app/immutable/assets/0.abc.css');
	assert.equal(asset.headers.get('Cache-Control'), 'public, max-age=31536000, immutable');
	const swr = 'public, max-age=0, stale-while-revalidate=86400';
	for (const path of ['', '/docs/install', '/docs/install/__data.json', '/__data.json']) {
		assert.equal((await get(`${SITE}${path}`)).headers.get('Cache-Control'), swr, path);
	}
	assert.equal((await get(`${SITE}/docs/install.md`)).headers.get('Cache-Control'), null);
	assert.equal((await get(`${SITE}/llms.txt`)).headers.get('Cache-Control'), null);
});

test('every content page is prerendered as a page and as client navigation data', () => {
	for (const path of docPaths) {
		assert.ok(existsSync(join(build, htmlFile(path))), path);
		assert.ok(existsSync(join(build, path.slice(1), '__data.json')), path);
	}
});

test('every page shares the 1200x630 Open Graph image', () => {
	const og = readFileSync(join(build, 'og.png'));
	assert.deepEqual([og.readUInt32BE(16), og.readUInt32BE(20)], [1200, 630]);
	for (const path of htmlPaths) {
		const html = read(htmlFile(path));
		assert.match(html, /<meta property="og:image" content="https:\/\/bestboy\.dev\/tony\/og\.png"/u, path);
		assert.match(html, /<meta name="twitter:card" content="summary_large_image"/u, path);
	}
});
