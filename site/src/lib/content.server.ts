import { Marked } from 'marked';
import { SITE_DESCRIPTION, SITE_URL } from '#lib/links.ts';

export type DocPage = Readonly<{
	slug: string;
	path: string;
	/** The page's H1, and with " - Tony" its title. */
	title: string;
	/** Its short name in the sidebar and the pager. */
	nav: string;
	description: string;
	section: string;
	markdown: string;
	source: string;
}>;

export type Heading = Readonly<{ id: string; text: string; depth: number }>;

const NAV: readonly (readonly [string, readonly string[]])[] = [
	['Get started', ['', 'install']],
	['Using Tony', ['ai-agents', 'settings', 'your-words', 'languages', 'menu-bar']],
	['About Tony', ['privacy', 'speed-and-accuracy', 'faq']],
];

const NAV_ORDER = NAV.flatMap(([, slugs]) => slugs);

const files = import.meta.glob<string>('/content/**/*.md', {
	query: '?raw',
	import: 'default',
	eager: true,
});

function slugOf(file: string): string {
	return file
		.replace(/^\/content\//u, '')
		.replace(/\.md$/u, '')
		.replace(/(^|\/)index$/u, '');
}

function unquote(value: string): string {
	return value.trim().replace(/^(['"])(.*)\1$/u, '$2');
}

function sectionOf(slug: string): string {
	return NAV.find(([, slugs]) => slugs.includes(slug))?.[0] ?? 'More';
}

function parse(slug: string, source: string): DocPage {
	const frontmatter = /^---\r?\n([\s\S]*?)\r?\n---\r?\n/u.exec(source);
	const fields = new Map(
		(frontmatter?.[1] ?? '').split('\n').flatMap((line) => {
			const colon = line.indexOf(':');
			return colon > 0
				? [[line.slice(0, colon).trim(), unquote(line.slice(colon + 1))] as const]
				: [];
		}),
	);
	const title = smartQuotes(fields.get('title') ?? slug);
	return {
		slug,
		path: slug ? `/docs/${slug}` : '/docs',
		title,
		nav: smartQuotes(fields.get('nav') ?? title),
		description: smartQuotes(fields.get('description') ?? ''),
		section: sectionOf(slug),
		markdown: source.slice(frontmatter?.[0].length ?? 0).trim(),
		source,
	};
}

function rank(slug: string): number {
	const index = NAV_ORDER.indexOf(slug);
	return index === -1 ? NAV_ORDER.length : index;
}

export const pages: readonly DocPage[] = Object.entries(files)
	.map(([file, source]) => parse(slugOf(file), source))
	.sort((left, right) => rank(left.slug) - rank(right.slug) || left.slug.localeCompare(right.slug));

export function findPage(slug: string): DocPage | undefined {
	return pages.find((page) => page.slug === slug);
}

export function navSections(): { title: string; items: { path: string; title: string }[] }[] {
	const sections = new Map<string, { path: string; title: string }[]>();
	for (const page of pages) {
		sections.set(page.section, [
			...(sections.get(page.section) ?? []),
			{ path: page.path, title: page.nav },
		]);
	}
	return [...sections].map(([title, items]) => ({ title, items }));
}

function plain(html: string): string {
	return html
		.replace(/<[^>]+>/gu, '')
		.replace(/&amp;/gu, '&')
		.replace(/&lt;/gu, '<')
		.replace(/&gt;/gu, '>')
		.replace(/&quot;/gu, '"')
		.replace(/&#39;/gu, "'");
}

function slugify(text: string): string {
	return (
		text
			.toLowerCase()
			.replace(/[^\p{L}\p{N}\s-]/gu, '')
			.trim()
			.replace(/\s+/gu, '-') || 'section'
	);
}

/** Content links to a docs page's markdown, so the .md copies link to markdown; pages link to the page. */
const DOCS_LINK = /^\/tony(\/docs[^#?]*?)(\.md)?(?=$|[#?])/u;

let headings: Heading[] = [];
let ids = new Map<string, number>();

const markdown = new Marked({
	gfm: true,
	walkTokens(token) {
		if (token.type === 'link') token.href = token.href.replace(DOCS_LINK, '/tony$1');
	},
	renderer: {
		link({ href }) {
			const docsPath = DOCS_LINK.exec(href)?.[1];
			if (docsPath === undefined || pages.some((page) => page.path === docsPath)) return false;
			throw new Error(`A link to ${href} points at no docs page`);
		},
		heading({ tokens, depth }) {
			const html = this.parser.parseInline(tokens);
			const text = smartQuotes(plain(html));
			const base = slugify(text);
			const taken = ids.get(base) ?? 0;
			ids.set(base, taken + 1);
			const id = taken === 0 ? base : `${base}-${taken}`;
			headings.push({ id, text, depth });
			return `<h${depth} id="${id}"><a class="anchor" href="#${id}">${html}</a></h${depth}>\n`;
		},
	},
});

/** Typographic quotes and apostrophes in plain text: “super base”, can’t. */
export function smartQuotes(text: string): string {
	return text
		.replace(/(^|[\s([{“‘—-])"/gu, '$1“')
		.replaceAll('"', '”')
		.replace(/(^|[\s([{“—-])'/gu, '$1‘')
		.replaceAll("'", '’');
}

/** `smartQuotes` on the text of rendered HTML, outside tags and code, where marked writes &quot; and &#39;. */
function smartHtml(html: string): string {
	let code = 0;
	return html
		.split(/(<[^>]+>)/u)
		.map((part) => {
			if (part.startsWith('<')) {
				if (/^<(code|pre)\b/u.test(part)) code++;
				if (/^<\/(code|pre)>/u.test(part)) code--;
				return part;
			}
			if (code > 0) return part;
			return smartQuotes(part.replaceAll('&quot;', '"').replaceAll('&#39;', "'")).replaceAll(
				'AGPL-3.0',
				'<span class="nowrap">AGPL-3.0</span>',
			);
		})
		.join('');
}

/** Markdown to HTML, with each table in a box that scrolls on its own on a phone, not the page. */
function render(source: string): string {
	return smartHtml(markdown.parse(source, { async: false }))
		.replaceAll('<table>', '<div class="table"><table>')
		.replaceAll('</table>', '</table></div>');
}

export function renderMarkdown(source: string): { html: string; headings: Heading[] } {
	headings = [];
	ids = new Map();
	const html = render(source);
	return { html, headings };
}

/** The FAQ page as questions and answers, for the home page. */
export function faqs(): { question: string; answer: string }[] {
	const faq = findPage('faq');
	if (!faq) throw new Error('content/faq.md is missing');
	return faq.markdown
		.split(/^## /mu)
		.slice(1)
		.map((section) => {
			const [question = '', ...answer] = section.split('\n');
			return { question: smartQuotes(question.trim()), answer: render(answer.join('\n')) };
		});
}

export function asMarkdownDocument(page: DocPage): string {
	return `# ${page.title}\n\n${page.description ? `> ${page.description}\n\n` : ''}${page.markdown}\n`;
}

export function llmsText(): string {
	const links = pages.map(
		(page) =>
			`- [${page.title}](${SITE_URL}${page.path}.md)${page.description ? `: ${page.description}` : ''}`,
	);
	return `# Tony\n\n> ${SITE_DESCRIPTION}\n\nEvery page below is plain markdown. [llms-full.txt](${SITE_URL}/llms-full.txt) holds all of them in one file.\n\n## Docs\n\n${links.join('\n')}\n`;
}
