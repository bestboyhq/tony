import { asset, resolve } from '$app/paths';

export const SITE_ORIGIN = 'https://bestboy.dev';
export const SITE_URL = `${SITE_ORIGIN}/tony`;
export const SITE_DESCRIPTION =
	'Talk to your AI agents: hold a key, speak your prompt, let go. Tony is free, open source dictation for Mac, private and offline, in 25 languages.';

export const DOWNLOAD_URL = 'https://bestboy.dev/download/tony';
export const GITHUB_URL = 'https://github.com/bestboyhq/tony';
export const BESTBOY_URL = 'https://bestboy.dev';
export const MALINI_URL = 'https://bestboy.dev/malini';
export const GRIP_URL = 'https://bestboy.dev/grip';

export const HOME = resolve('/(site)').replace(/\/$/u, '');

export function docHref(path: string): string {
	return `${HOME}${path}`;
}

export type Link = Readonly<{
	title: string;
	href: string;
	line?: string;
	icon?: string;
	tag?: string;
	reload?: boolean;
	current?: boolean;
}>;

export type Menu = Readonly<{
	id: string;
	title: string;
	columns: readonly Readonly<{ label?: string; plain?: boolean; links: readonly Link[] }>[];
	strip?: Readonly<{ lead: string; text: string; link: Link }>;
}>;

export const isExternal = (link: Link): boolean => link.href.startsWith('http');

const doc = (slug: string): string => docHref(`/docs/${slug}`);

const LLMS: Link = { title: 'llms.txt', href: resolve('/llms.txt'), reload: true };
const LLMS_FULL: Link = { title: 'llms-full.txt', href: resolve('/llms-full.txt'), reload: true };
const MARKDOWN: Link = { title: 'Docs as markdown', href: `${docHref('/docs')}.md`, reload: true };
const RELEASES: Link = { title: 'Releases', href: `${GITHUB_URL}/releases` };
const DECISIONS: Link = { title: 'Decisions', href: `${GITHUB_URL}/tree/main/docs/adr` };
const ISSUES: Link = { title: 'Issues', href: `${GITHUB_URL}/issues` };

export const ICONS = {
	bestboy: asset('icons/bestboy.webp'),
	tony: asset('icons/tony.webp'),
	malini: asset('icons/malini.webp'),
	grip: asset('icons/grip.webp'),
} as const;

// The brand's switcher: one line each, read top to bottom as one story.
export const APPS: Menu = {
	id: 'apps',
	title: 'Tony',
	columns: [
		{
			links: [
				{
					title: 'Tony',
					tag: 'Say it',
					href: HOME,
					icon: ICONS.tony,
					line: 'Speak to your agents.',
					current: true,
				},
				{
					title: 'Malini',
					tag: 'Build it',
					href: MALINI_URL,
					icon: ICONS.malini,
					line: 'Ship and automate them.',
				},
				{
					title: 'Grip',
					tag: 'Share it',
					href: GRIP_URL,
					icon: ICONS.grip,
					line: 'Showcase the results.',
				},
			],
		},
	],
	strip: {
		lead: 'The suite',
		text: 'Use one, or all three together',
		link: { title: 'How they fit', href: `${BESTBOY_URL}/#turn` },
	},
};

// The bar's menus, as Bestboy's design lays out an app's site (`docs/design.md` in bestboyhq/platform, "The bar"):
// Product links to the landing page's sections.
export const MENUS: readonly Menu[] = [
	{
		id: 'product',
		title: 'Product',
		columns: [
			{
				label: 'Dictate',
				links: [
					{ title: 'Prompting', href: `${HOME}#prompting`, line: 'Speak your prompt to any agent' },
					{ title: 'Speed', href: `${HOME}#fast`, line: 'About 50 ms a sentence' },
					{ title: 'Accuracy', href: `${HOME}#accurate`, line: '25 languages, detected as you speak' },
				],
			},
			{
				label: 'On your Mac',
				links: [
					{ title: 'Menu bar', href: `${HOME}#stats`, line: 'Your last dictation and your stats' },
					{ title: 'Every app', href: `${HOME}#everywhere`, line: 'If it takes paste, it takes Tony' },
					{ title: 'Offline', href: `${HOME}#private`, line: 'Your voice never leaves the Mac' },
				],
			},
		],
	},
	{
		id: 'resources',
		title: 'Resources',
		columns: [
			{
				label: 'Docs',
				links: [
					{ title: 'Install', href: doc('install'), line: 'Allow the microphone and Accessibility' },
					{ title: 'Settings', href: doc('settings'), line: 'Your key, mic, languages, and words' },
					{ title: 'Privacy', href: doc('privacy'), line: 'Offline, with audio kept in memory' },
				],
			},
			{
				label: 'For agents',
				links: [
					{ ...LLMS, line: 'Every docs page, as markdown for agents' },
					{ ...LLMS_FULL, line: 'All the docs in one file, for agents' },
				],
			},
			{ label: 'Project', plain: true, links: [RELEASES, DECISIONS, ISSUES] },
		],
	},
];

// The footer's columns (`docs/design.md`, "The footer").
export const SITEMAP: readonly Readonly<{ label: string; links: readonly Link[] }>[] = [
	{
		label: 'Product',
		links: [
			{ title: 'Prompting AI agents', href: doc('ai-agents') },
			{ title: 'Your words', href: doc('your-words') },
			{ title: 'Languages', href: doc('languages') },
			{ title: 'Menu bar and stats', href: doc('menu-bar') },
			{ title: 'Download', href: DOWNLOAD_URL },
		],
	},
	{
		label: 'Docs',
		links: [
			{ title: 'How Tony works', href: docHref('/docs') },
			{ title: 'Install', href: doc('install') },
			{ title: 'Settings', href: doc('settings') },
			{ title: 'Speed and accuracy', href: doc('speed-and-accuracy') },
			{ title: 'Privacy', href: doc('privacy') },
			{ title: 'FAQ', href: doc('faq') },
		],
	},
	{
		label: 'For agents',
		links: [LLMS, LLMS_FULL, MARKDOWN, { title: 'Sitemap', href: resolve('/sitemap.xml'), reload: true }],
	},
	{
		label: 'Project',
		links: [
			{ title: 'Source code', href: GITHUB_URL },
			RELEASES,
			DECISIONS,
			ISSUES,
			{ title: 'bestboy.dev', href: BESTBOY_URL },
		],
	},
];
