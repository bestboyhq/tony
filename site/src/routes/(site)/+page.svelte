<!-- Tony's landing page, after Grip's: the hero plays Tony's own pill as a voice prompts a coding agent, then beat by
     beat how a dictation goes (long prompts, your words, languages), how fast and accurate it is, the menu bar panel,
     where it works, the bugs it designs out, why it is safe to rely on, the family, the questions, and the close. Every
     clip and still is Tony's own (`scripts/readme/make.ts`), and every claim and number comes from the README. -->
<script lang="ts">
	import type { Snippet } from 'svelte';
	import Arrow from '#lib/Arrow.svelte';
	import BeatLabel, { type Beat } from '#lib/BeatLabel.svelte';
	import FeatureRow from '#lib/FeatureRow.svelte';
	import Glow, { within, type Box, type Layer } from '#lib/Glow.svelte';
	import Head from '#lib/Head.svelte';
	import Hero from '#lib/Hero.svelte';
	import Icon from '#lib/Icon.svelte';
	import Media from '#lib/Media.svelte';
	import SectionHeading from '#lib/SectionHeading.svelte';
	import StageLight from '#lib/StageLight.svelte';
	import { asset } from '$app/paths';
	import {
		BESTBOY_URL,
		docHref,
		DOWNLOAD_URL,
		GITHUB_URL,
		GRIP_URL,
		ICONS,
		MALINI_URL,
		SITE_DESCRIPTION,
		SITE_ORIGIN,
		SITE_URL,
	} from '#lib/links.ts';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	// The close's: three colors in the glow's box. The canvas reaches a fifth of that box past it on every side
	// (`.close .gl`), so the light fades out before the canvas ends.
	const GLOW: Box = [1 / 7, 1 / 7, 5 / 7, 5 / 7];
	const CLOSING: readonly Layer[] = [
		{ box: within([0, 0.06, 0.55, 0.8], GLOW), color: '#1957fa', peak: [1, 1] },
		{ box: within([0.25, 0.18, 0.5, 0.7], GLOW), color: '#d94f46', peak: [1, 1] },
		{ box: within([0.55, 0.12, 0.45, 0.7], GLOW), color: '#fb8600', peak: [1, 1] },
	];

	const doc = (slug: string) => docHref(`/docs/${slug}`);

	const BEATS = [
		'numbers',
		'how',
		'prompting',
		'words',
		'languages',
		'fast',
		'accurate',
		'stats',
		'everywhere',
		'bugs',
		'private',
		'family',
		'faq',
		'start',
	] as const;

	const beat = (id: (typeof BEATS)[number], kicker?: string): Beat => ({
		n: BEATS.indexOf(id) + 1,
		total: BEATS.length,
		...(kicker ? { kicker } : {}),
	});

	const pad = (value: number): string => String(value).padStart(2, '0');

	// Below the hero, each beat draws its line and blurs in once as it scrolls into view (Bestboy's design, "Motion").
	$effect(() => {
		const io = new IntersectionObserver(
			(entries) => {
				let wave = 0;
				for (const { isIntersecting, target } of entries) {
					if (!isIntersecting || !(target instanceof HTMLElement)) continue;
					target.style.setProperty('--i', String(Math.min(wave++, 3)));
					target.dataset.reveal = 'go';
					io.unobserve(target);
				}
			},
			{ rootMargin: `${document.documentElement.scrollHeight}px 0px -10% 0px` },
		);
		const waiting = [...document.querySelectorAll<HTMLElement>('.beat, .rise, .sitemap')].filter(
			(element) => element.getBoundingClientRect().top > innerHeight,
		);
		for (const element of waiting) {
			element.dataset.reveal = 'wait';
			io.observe(element);
		}
		return () => {
			io.disconnect();
			for (const element of waiting) delete element.dataset.reveal;
		};
	});

	// What search engines and assistants read: the app, free, and the questions below word for word.
	const schema = $derived([
		{
			'@context': 'https://schema.org',
			'@type': 'SoftwareApplication',
			name: 'Tony',
			description: SITE_DESCRIPTION,
			url: SITE_URL,
			applicationCategory: 'UtilitiesApplication',
			applicationSubCategory: 'Dictation',
			operatingSystem: 'macOS 15 or later',
			processorRequirements: 'Apple silicon',
			downloadUrl: DOWNLOAD_URL,
			license: 'https://www.gnu.org/licenses/agpl-3.0.html',
			isAccessibleForFree: true,
			offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
			image: `${SITE_ORIGIN}${ICONS.tony}`,
			screenshot: `${SITE_ORIGIN}${asset('media/panel.webp')}`,
			featureList: [
				'Dictate prompts to AI agents like Claude Code and Codex, in a terminal, an editor, or any chat box',
				'Hold a key to dictate into any app',
				'On-device, offline speech to text on the Neural Engine',
				'25 languages, detected as you speak',
				'Your words: names, brands, and jargon spelled your way',
				'Filler words removed',
				'Your words shown as you speak',
			],
			softwareHelp: { '@type': 'CreativeWork', url: `${SITE_URL}/docs` },
			sameAs: [GITHUB_URL],
			author: { '@type': 'Organization', name: 'Bestboy', url: BESTBOY_URL },
		},
		{
			'@context': 'https://schema.org',
			'@type': 'FAQPage',
			mainEntity: data.faqs.map(({ question, answer }) => ({
				'@type': 'Question',
				name: question,
				acceptedAnswer: { '@type': 'Answer', text: answer },
			})),
		},
	]);

	const numbers = [
		{ value: '~50 ms', label: 'per sentence' },
		{ value: '5.8%', label: 'word error rate' },
		{ value: '25', label: 'languages' },
		{ value: '0 bytes', label: 'of audio leave your Mac' },
	];

	type Cell = Readonly<{ title: string; body: string }>;

	const steps: readonly Cell[] = [
		{
			title: 'Hold a key',
			body: 'Listening starts the instant your key goes down, so your first word counts. Double-tap it for a long brief, hands free.',
		},
		{
			title: 'Speak your prompt',
			body: 'Ramble if you like. Your words show above the pill as you talk, and Tony transcribes on your Mac’s Neural Engine as you go, so even five minutes lands at once.',
		},
		{
			title: 'Let go',
			body: 'Your prompt lands where the cursor is: your agent in the terminal, your editor, or any chat box. You press Return.',
		},
	];

	// Tony on the Neural Engine of a MacBook Pro with M5 Pro, median of 5 runs, drawn to scale.
	const speed = [
		{ name: '5 seconds', note: 'A sentence', ms: 49 },
		{ name: '13 seconds', note: 'A short paragraph', ms: 70 },
		{ name: '26 seconds', note: 'A long prompt', ms: 147 },
	];
	const slowest = Math.max(...speed.map((row) => row.ms));

	// English word error rate over the Open ASR Leaderboard sets, drawn to scale from zero.
	const models = [
		{ name: 'Whisper large-v3', note: '1.55 B parameters', wer: 7.44 },
		{ name: 'Parakeet TDT v3', note: '0.6 B parameters', wer: 6.26 },
		{ name: 'Parakeet Ultra', note: 'In Tony, 0.6 B parameters', wer: 5.8, tony: true },
	];
	const worst = Math.max(...models.map((row) => row.wer));

	let panel = $state<HTMLElement>();
	let panelLit = $state(false);

	const everywhere: readonly Cell[] = [
		{
			title: 'Every layout',
			body: 'QWERTY, Dvorak, and Cyrillic layouts all paste correctly, and a dictation lands as one paste, so undo is one ⌘Z.',
		},
		{
			title: 'Shortcuts still work',
			body: 'Press another key with yours, and Tony steps aside for the shortcut.',
		},
		{
			title: 'Problems in plain words',
			body: 'A muted mic or an app holding secure input gets one sentence and, where it helps, the button that fixes it.',
		},
		{
			title: 'Updates itself',
			body: 'It checks quietly, never with a window over your work, and installs the newest release once you finish talking.',
		},
	];

	const bugs: readonly Cell[] = [
		{
			title: 'The first word is lost while the app wakes up',
			body: 'The mic opens on key down, before you speak.',
		},
		{
			title: 'The first dictation of the day is slow',
			body: 'The model loads at launch and pays its Neural Engine setup up front.',
		},
		{
			title: 'A long ramble means a long wait',
			body: 'Tony transcribes at each pause while you talk.',
		},
		{
			title: 'A quiet room types “Thank you.”',
			body: 'Voice activity detection trims the silence, and silence types nothing.',
		},
		{
			title: 'A failed paste loses your words',
			body: 'Every dictation stays on the clipboard, and the last one in the panel.',
		},
		{
			title: 'The text lands in the wrong window',
			body: 'The pill and the panel never take focus.',
		},
		{
			title: 'Dvorak or Cyrillic fires a shortcut instead of pasting',
			body: 'Tony presses the key that types V in your layout.',
		},
		{
			title: 'A Bluetooth headset drops to phone-call quality',
			body: 'Tony prefers the built-in mic, and opens a mic only while you talk.',
		},
		{
			title: 'The orange mic dot stays on all day',
			body: 'Between dictations Tony holds no audio device.',
		},
		{
			title: 'Your music plays into the mic',
			body: 'Other audio fades out and pauses while you talk.',
		},
		{
			title: 'Unplugging the mic loses the sentence',
			body: 'Tony types what it heard.',
		},
		{
			title: 'Quitting mid‑dictation loses it',
			body: 'Quitting types it first.',
		},
	];

	const trust: readonly Cell[] = [
		{
			title: 'On your Mac',
			body: 'Audio stays in memory and is never written to disk. Once the model is downloaded, Tony dictates offline.',
		},
		{
			title: 'No account',
			body: 'Tony goes online only to download its models once, to check for updates, and to share usage stats, never what you say or type. Turn it off in Settings.',
		},
		{
			title: 'Open source',
			body: 'The code is public under AGPL-3.0, and CI builds every release from a tagged commit, so you can check what you run.',
		},
	];

	const family = [
		{
			name: 'Grip',
			verb: 'Show it',
			body: 'The free screen recorder, for the bug that is quicker to show than to describe.',
			href: GRIP_URL,
			icon: ICONS.grip,
		},
		{
			name: 'Tony',
			verb: 'Say it',
			body: 'Dictation that types where your cursor is, transcribed on your Mac in about 50 ms.',
			href: doc('ai-agents'),
			icon: ICONS.tony,
		},
		{
			name: 'Malini',
			verb: 'Ship it',
			body: 'Many Claude Code agents side by side, each in its own git worktree, and a merged pull request each.',
			href: MALINI_URL,
			icon: ICONS.malini,
		},
	];
</script>

<Head
	title="Tony - talk to your AI agents. Free, private dictation for Mac"
	description={SITE_DESCRIPTION}
	path=""
	{schema}
/>

<!-- The hero clip's still in the system's theme, which shows until the clip plays. -->
<svelte:head>
	<link
		rel="preload"
		as="image"
		href={asset('media/hero.webp')}
		media="(prefers-color-scheme: dark)"
		fetchpriority="high"
	/>
	<link
		rel="preload"
		as="image"
		href={asset('media/hero-light.webp')}
		media="(prefers-color-scheme: light)"
		fetchpriority="high"
	/>
</svelte:head>

<Hero>
	<p class="lede">
		<strong>Hold a key, speak, let go.</strong>
		Your prompt lands in Claude Code, Codex, or any chat box, with your project’s names spelled right and the “um” gone.
	</p>
	<div class="actions" data-place="hero">
		<a class="button primary" href={DOWNLOAD_URL}>
			{@render apple()}
			Download for macOS
		</a>
		<a class="button secondary" href={GITHUB_URL}>
			<Icon name="github" size={16} />
			Star on GitHub
		</a>
	</div>
	<p class="fine">
		<span>macOS 15 or later on Apple silicon</span>
		<span>No account</span>
		<span>No subscription</span>
	</p>
</Hero>

<section id="numbers" class="beat" aria-labelledby="numbers-title">
	<div class="wrap">
		<BeatLabel {...beat('numbers', 'Tony in numbers')} />
		<h2 id="numbers-title" class="sr-only">Tony in numbers</h2>
		<dl class="readout rise">
			{#each numbers as number (number.label)}
				<div>
					<dt>{number.label}</dt>
					<dd>{number.value}</dd>
				</div>
			{/each}
		</dl>
	</div>
</section>

<SectionHeading
	id="how"
	beat={beat('how', 'How it works')}
	split
	title="Your prompt is in your head."
	quiet="Typing it is the slow part."
	description="A good prompt carries context: what you tried, what broke, what you want next. Most dictation clips your first word, pastes a “Thank you.” you never said, or loses your words when the paste fails. Tony starts listening the instant your key goes down, and your voice never leaves the Mac."
>
	{#snippet after()}
		{@render cells(steps, { ordered: true })}
	{/snippet}
</SectionHeading>

<FeatureRow
	id="prompting"
	beat={beat('prompting', 'Long prompts')}
	title="Talk for minutes. Wait for none."
	body="A caption buds out of the pill and shows your words about half a second after you say them, five lines at a time. Tony transcribes at each pause while you talk, so letting go is as instant after a long ramble as after one sentence."
	href={doc('ai-agents')}
	linkLabel="Prompting AI agents"
	checks={[
		'Works in Terminal, VS Code, Malini, and any chat box',
		'Double-tap your key to talk hands-free',
		'Esc cancels, and nothing is typed',
	]}
>
	<Media
		clip="long"
		width={1440}
		height={936}
		r={24}
		alt="A new chat with an assistant. A voice plans three days in Lisbon for 21 seconds: the caption above Tony’s pill grows to five lines, then scrolls up as each new word fades in. When the voice stops, the caption flows back into the pill, and the whole prompt lands in the chat box 86 ms later."
	/>
</FeatureRow>

<FeatureRow
	id="words"
	beat={beat('words', 'Your words')}
	mirrored
	title="Your words, spelled your way."
	body="Add the names, brands, and jargon you use, and “tail scale” lands as Tailscale. A second, small model checks each one against your voice, so a word swaps in only where you said it."
	href={doc('your-words')}
	linkLabel="Your words"
	checks={[
		'The first guess blurs into your word in place',
		'Filler words out, commas and capitals kept',
		'Mid-sentence, no stray capital and no extra space',
	]}
>
	<Media
		clip="words"
		width={1440}
		height={936}
		r={24}
		alt="A team chat channel. A voice says “Can you add Tailscale to the staging boxes and ping me on Vercel when the preview is up?” The caption first shows “tail scale”, which blurs into “Tailscale” in place, and the message lands in the composer with Tailscale and Vercel spelled right."
	/>
</FeatureRow>

<FeatureRow
	id="languages"
	beat={beat('languages', 'Languages')}
	title="25 languages, detected as you speak."
	body="English, German, French, Spanish, Polish, Ukrainian, and the rest of Europe. Switch between them without a setting, even mid-dictation: where the model loses track of the switch, Tony transcribes each language on its own."
	href={doc('languages')}
	linkLabel="All 25 languages"
	checks={[
		'Punctuation, capitals, and accents included',
		'Filler words out in every language',
		'Or pin the ones you use in Settings',
	]}
>
	<Media
		clip="languages"
		width={1440}
		height={936}
		r={24}
		alt="A new email to Ania Kowalska about a Thursday meeting. A voice speaks Polish, and the caption fills with Polish words, accents and all: “Cześć, spotkanie z klientem przenosimy na czwartek. Przygotuję prezentację, a ty wyślij proszę notatki z ostatniego tygodnia. Dzięki.” The text lands in the body of the email."
	/>
</FeatureRow>

<section id="fast" class="beat flush" aria-labelledby="fast-title">
	<div class="wrap">
		<BeatLabel {...beat('fast', 'Speed')} />
		<div class="speed">
			<p class="reading rise">
				<span class="ms"><span class="paint">50</span><span class="unit">ms</span></span>
				<span class="from">About this long for a sentence, on the Neural Engine</span>
			</p>
			<div class="rise">
				<h2 id="fast-title">
					<span>Let go.</span>
					<span class="quiet">It is already there.</span>
				</h2>
				<p class="sub">
					Tony loads the model at launch and transcribes at each pause while you talk, so the first dictation of
					the day is as quick as the hundredth, and a five-minute brief lands as fast as one line.
				</p>
				<a class="arrow-link more" href={doc('speed-and-accuracy')}>
					Speed and accuracy
					<Arrow class="ahead" />
				</a>
			</div>
		</div>
		{@render chart(
			'Milliseconds to transcribe, by how long you speak',
			speed.map((row) => ({ ...row, share: row.ms / slowest, value: `${row.ms} ms`, tony: true })),
			'A MacBook Pro with M5 Pro, median of 5 runs, on clips read by a macOS voice that all came out word for word.',
		)}
	</div>
</section>

<SectionHeading
	id="accurate"
	beat={beat('accurate', 'Accuracy')}
	split
	title="One of the most accurate open models."
	quiet="Running on your Mac."
	description="Tony runs Parakeet Ultra: NVIDIA’s Parakeet TDT v3, post-trained by Moondream to make fewer errors on every benchmark they report. Across 25 languages it cuts the error rate from 11.6% to 9.6%, and in background noise from 6.7% to 5.8%."
>
	{#snippet after()}
		{@render chart(
			'English word error rate, lower is better',
			models.map((row) => ({ ...row, share: row.wer / worst, value: `${row.wer.toFixed(2)}%` })),
			sources,
		)}
	{/snippet}
</SectionHeading>

{#snippet sources()}
	Averaged over the
	<a href="https://huggingface.co/spaces/hf-audio/open_asr_leaderboard">Open ASR Leaderboard</a>
	English sets: Parakeet from
	<a href="https://huggingface.co/moondream/parakeet-ultra">Moondream’s model card</a>, Whisper from the
	<a href="https://arxiv.org/abs/2510.06961">leaderboard paper</a>.
{/snippet}

<SectionHeading
	id="stats"
	beat={beat('stats', 'Menu bar')}
	title="Everything Tony did for you."
	quiet="One click away, in the menu bar."
	description="Click Tony in the menu bar for a glass panel: your last dictation, the words you dictated and the time they saved, your pace, your streak, and six months at a glance. Settings sits one page over, with the four choices people really differ on."
>
	{#snippet after()}
		<div class="stage">
			<StageLight side="right" caster={panel?.firstElementChild ?? undefined} bind:lit={panelLit} />
			<figure class={['panel', 'rise', { lit: panelLit }]}>
				<div class="shot" bind:this={panel}>
					<Media
						still="panel"
						width={1920}
						height={1522}
						r={32}
						alt="Tony’s menu bar panel and its Settings, side by side in Liquid Glass. Home: Hold fn to dictate, the last dictation with Copy and Paste, 54,934 words dictated, 16h 50m saved over typing, 151 wpm speaking pace, 75 ms from key up to text, a 31-day streak, 130 days in the last 6 months, and the apps you dictate into. Settings: the fn key, the microphone on Automatic, English and Polish, your words as tags, Share usage stats, Open at login, and the version."
					/>
				</div>
				<figcaption>
					Made-up stats, drawn by Tony itself. Stats are counts by day and by app, kept on your Mac, never what
					you said.
					<a href={doc('menu-bar')}>The menu bar panel</a>
					·
					<a href={doc('settings')}>Settings</a>
				</figcaption>
			</figure>
		</div>
	{/snippet}
</SectionHeading>

<SectionHeading
	id="everywhere"
	beat={beat('everywhere', 'Every app')}
	split
	title="Works in every app."
	quiet="And stays out of the way."
	description="Native apps, Safari and Chrome, Slack and VS Code, Terminal: if it takes paste, it takes Tony. Like the pill, the panel never takes focus from your app, so the text lands where you were typing."
>
	{#snippet after()}
		{@render cells(everywhere, { four: true })}
	{/snippet}
</SectionHeading>

<SectionHeading
	id="bugs"
	beat={beat('bugs', 'Under the hood')}
	split
	title="The usual dictation bugs."
	quiet="Designed out."
	description="Each one shipped in a real dictation app. Tony is built so none of them can happen, from the first commit."
>
	{#snippet after()}
		{@render cells(bugs, { ordered: true, four: true })}
	{/snippet}
</SectionHeading>

<SectionHeading
	id="private"
	beat={beat('private', 'Privacy')}
	title="Your voice never leaves the Mac."
	quiet="Neither do your prompts."
	description="Prompts carry your codebase’s names and your half-formed ideas. Tony hears them on your Mac, and the only place they go is the app you paste into."
>
	<div class="buttons">
		<a class="button secondary small" href={GITHUB_URL}>
			<Icon name="github" size={14} />
			Star on GitHub
		</a>
		<a class="button secondary small" href={doc('privacy')}>Privacy and offline use</a>
	</div>
	{#snippet after()}
		{@render cells(trust)}
	{/snippet}
</SectionHeading>

<SectionHeading
	id="family"
	beat={beat('family', 'Bestboy')}
	title="Show it with Grip. Say it with Tony."
	quiet="Ship it with Malini."
	description="Three free, open source Mac apps from Bestboy, for the way you build with agents."
>
	{#snippet after()}
		<ul class="cells">
			{#each family as app (app.name)}
				<li class="rise">
					<img class="app-icon" src={app.icon} width="32" height="32" alt="" loading="lazy" />
					<h3>{app.name} <span class="tag">{app.verb}</span></h3>
					<p>{app.body}</p>
					<a class="arrow-link" href={app.href}>
						{app.name}
						<Arrow class="ahead" />
					</a>
				</li>
			{/each}
		</ul>
	{/snippet}
</SectionHeading>

<section id="faq" class="beat" aria-labelledby="faq-title">
	<div class="wrap">
		<BeatLabel {...beat('faq')} />
		<div class="faq">
			<div class="faq-intro rise">
				<h2 id="faq-title">Frequently asked questions</h2>
				<p>
					Have a different question? <a href="{GITHUB_URL}/issues">Ask on GitHub</a>
				</p>
			</div>
			<div class="answers rise">
				{#each data.faqs as faq, index (faq.question)}
					<details>
						<summary>
							<span class="idx" aria-hidden="true">{pad(index + 1)}</span>
							<span class="q">{faq.question}</span>
							<span class="plus" aria-hidden="true"></span>
						</summary>
						<div class="answer">{@html faq.answer}</div>
					</details>
				{/each}
			</div>
		</div>
	</div>
</section>

<section id="start" class="beat closing" aria-labelledby="start-title">
	<div class="wrap">
		<div class="close">
			<div class="glow" aria-hidden="true"></div>
			<div class="gl" aria-hidden="true">
				<Glow layers={CLOSING} opacity={0.14} soft={0.25} weighted />
			</div>
			<BeatLabel {...beat('start')} />
			<div class="end">
				<div class="rise">
					<h2 id="start-title">Say your next prompt.</h2>
					<p class="sub">Download Tony, allow the microphone and Accessibility, and talk to your agents.</p>
				</div>
				<div class="close-actions rise">
					<div class="actions">
						<a class="button primary" href={DOWNLOAD_URL}>
							{@render apple()}
							Download for macOS
						</a>
						<a class="button secondary" href={doc('install')}>Install guide</a>
					</div>
					<p class="fine"><span>Free and open source</span> <span>AGPL-3.0</span></p>
				</div>
			</div>
		</div>
	</div>
</section>

<!-- Numbered cells under a heading, each a title and a line: three to a row, or four, which wrap to two, then one. -->
{#snippet cells(items: readonly Cell[], { ordered = false, four = false } = {})}
	<svelte:element this={ordered ? 'ol' : 'ul'} class={['cells', { four }]}>
		{#each items as item, index (item.title)}
			<li class="rise">
				<span class="idx" aria-hidden="true">{pad(index + 1)}</span>
				<h3>{item.title}</h3>
				<p>{item.body}</p>
			</li>
		{/each}
	</svelte:element>
{/snippet}

<!-- Bars drawn to scale against the longest, each ending with its value; Tony's are painted. -->
{#snippet chart(
	caption: string,
	rows: readonly { name: string; note: string; share: number; value: string; tony?: boolean }[],
	note: string | Snippet,
)}
	<figure class="chart">
		<figcaption class="rise">{caption}</figcaption>
		<ul>
			{#each rows as row (row.name)}
				<li class={['rise', { tony: row.tony }]} style:--share={row.share}>
					<span class="who"><span class="name">{row.name}</span> {row.note}</span>
					<span class="track">
						<span class="bar" aria-hidden="true"></span>
						{row.value}
					</span>
				</li>
			{/each}
		</ul>
		<p class="source rise">
			{#if typeof note === 'string'}{note}{:else}{@render note()}{/if}
		</p>
	</figure>
{/snippet}

{#snippet apple()}
	<svg class="apple" viewBox="4 3.1 14.8 18.2" width="13" height="16" aria-hidden="true" fill="currentColor">
		<path
			d="M16.37 12.73c-.02-2.3 1.88-3.4 1.96-3.46-1.07-1.56-2.73-1.78-3.32-1.8-1.41-.14-2.76.83-3.48.83-.72 0-1.82-.81-3-.79-1.54.02-2.97.9-3.76 2.28-1.6 2.78-.41 6.9 1.15 9.16.76 1.1 1.67 2.34 2.86 2.3 1.15-.05 1.58-.74 2.97-.74s1.78.74 3 .72c1.24-.02 2.02-1.12 2.78-2.23.88-1.28 1.24-2.52 1.26-2.58-.03-.01-2.4-.92-2.42-3.69ZM14.1 5.98c.63-.77 1.06-1.83.94-2.89-.91.04-2.02.61-2.67 1.37-.58.67-1.1 1.76-.96 2.8 1.02.08 2.06-.52 2.69-1.28Z"
		/>
	</svg>
{/snippet}

<style>
	/* The hero's pitch beside its headline (`Hero.svelte`): the lede, the buttons, and the fine print, as wide as the
	   buttons. */

	.lede {
		--rise: 3px;
		--blur: 10px;
		--duration: 1300ms;
		--delay: 150ms;
		max-width: 560px;
		margin-bottom: 24px;
		color: var(--fg-muted);
		font-size: 16px;
		line-height: 1.55;
		text-wrap: pretty;
	}

	.lede strong {
		color: var(--fg-default);
		font-weight: 550;
	}

	.actions {
		--rise: 3px;
		--blur: 8px;
		--duration: 1300ms;
		--delay: 300ms;
		display: flex;
		flex-wrap: wrap;
		gap: 12px;
	}

	.apple {
		translate: 0 -1.5px;
	}

	.fine {
		--rise: 3px;
		--blur: 8px;
		--duration: 1300ms;
		--delay: 300ms;
		margin-top: 16px;
		margin-left: -0.6em;
		clip-path: inset(-1em -1em -1em 0.6em);
		color: var(--fg-muted);
		font-size: 13px;
		line-height: 1.55;
		text-wrap: balance;
	}

	/* Each item leads with its dot, and the line starts one dot early behind the clip, so no line starts or ends on a
	   dot however the items wrap. */
	.fine span {
		white-space: nowrap;
	}

	.fine span::before {
		content: '·';
		display: inline-block;
		width: 0.6em;
	}

	.buttons {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		gap: 12px;
		margin-top: 12px;
	}

	.more {
		margin-top: 24px;
	}

	/* Tony in numbers: a readout, each number poster-sized with a dotted leader to what it counts. */

	.readout div {
		display: grid;
		grid-template-columns: auto minmax(24px, 1fr) auto;
		grid-template-areas: 'value dots label';
		align-items: baseline;
		gap: 0 24px;
		padding: 12px 0;
	}

	.readout div::before {
		content: '';
		grid-area: dots;
		border-bottom: 2px dotted var(--border-strong);
	}

	.readout dd {
		grid-area: value;
		margin: 0;
		font-size: clamp(44px, 7vw, 88px);
		font-weight: 550;
		line-height: 1;
		letter-spacing: -0.04em;
		font-variant-numeric: tabular-nums;
	}

	.readout dt {
		grid-area: label;
		max-width: 320px;
		color: var(--fg-secondary);
		font-family: var(--mono);
		font-size: 14px;
		line-height: 20px;
		text-align: right;
	}

	/* Cells: three across, or four, split by hairlines from rail to rail. */

	.cells {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		margin: 72px calc(-1 * max(var(--pad), env(safe-area-inset-left))) 0;
		list-style: none;
	}

	.cells li {
		display: flex;
		flex-direction: column;
		gap: 8px;
		padding: 40px var(--pad);
		border-top: 1px solid var(--frame);
	}

	.cells li + li {
		border-left: 1px solid var(--frame);
	}

	.four {
		grid-template-columns: repeat(4, minmax(0, 1fr));
	}

	.four li:nth-child(4n + 1) {
		border-left: 0;
	}

	.idx {
		color: var(--fg-faint);
		font-family: var(--mono);
		font-size: 12px;
		line-height: 24px;
		font-variant-numeric: tabular-nums;
	}

	.cells .idx {
		margin-bottom: 4px;
	}

	.cells .app-icon {
		--s: 32px;
		margin-bottom: 4px;
	}

	.cells h3 {
		display: flex;
		align-items: baseline;
		gap: 8px;
		font-size: 17px;
		font-weight: 550;
		line-height: 1.4;
		letter-spacing: -0.01em;
		text-wrap: balance;
	}

	.tag {
		color: var(--fg-faint);
		font-family: var(--mono);
		font-size: 11px;
		font-weight: 400;
		letter-spacing: 0;
	}

	.cells p {
		color: var(--fg-muted);
		font-size: 15px;
		line-height: 1.6;
		text-wrap: pretty;
	}

	.cells .arrow-link {
		margin-top: auto;
		padding-top: 8px;
	}

	/* Speed: the page's one poster numeral, painted, beside its headline. No letter-spacing: it would narrow the
	   numeral's box past its ink, and the paint, clipped to that box, would cut its right side. */

	.flush {
		padding-bottom: 0;
	}

	.speed {
		display: grid;
		grid-template-columns: minmax(0, 6fr) minmax(0, 5fr);
		gap: 32px 80px;
		align-items: center;
	}

	.reading {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.ms {
		display: flex;
		align-items: baseline;
		gap: 0.02em;
		margin: -0.06em 0 -0.1em -0.05em;
		font-size: clamp(160px, 22vw, 300px);
		font-weight: 550;
		line-height: 1;
	}

	.paint {
		background: var(--painting);
		-webkit-background-clip: text;
		background-clip: text;
		color: transparent;
	}

	.unit {
		color: var(--fg-faint);
		font-size: 0.32em;
		letter-spacing: -0.03em;
	}

	.from {
		color: var(--fg-faint);
		font-family: var(--mono);
		font-size: 12px;
		line-height: 16px;
	}

	h2 {
		font-size: clamp(30px, 3.4vw, 40px);
		font-weight: 550;
		line-height: 1.1;
		letter-spacing: -0.03em;
		text-wrap: balance;
	}

	.speed h2 {
		font-size: clamp(34px, 4.6vw, 52px);
		line-height: 1.06;
		letter-spacing: -0.035em;
	}

	.speed h2 span {
		display: block;
	}

	.quiet {
		color: var(--fg-faint);
	}

	/* A chart from rail to rail: bars to scale against the longest, which ends with its value at the edge. */

	.chart {
		margin: 72px calc(-1 * max(var(--pad), env(safe-area-inset-left))) 0;
		padding: 40px max(var(--pad), env(safe-area-inset-left));
		border-top: 1px solid var(--frame);
	}

	.chart figcaption,
	.source {
		color: var(--fg-faint);
		font-family: var(--mono);
		font-size: 12px;
		line-height: 24px;
	}

	.chart ul {
		display: grid;
		gap: 20px;
		margin-top: 28px;
		list-style: none;
	}

	.chart li {
		display: grid;
		grid-template-columns: 200px minmax(0, 1fr);
		gap: 8px 24px;
		align-items: center;
	}

	.who {
		display: flex;
		flex-direction: column;
		gap: 2px;
		color: var(--fg-faint);
		font-size: 13px;
		line-height: 1.4;
	}

	.name {
		color: var(--fg-muted);
		font-size: 17px;
		font-weight: 550;
		letter-spacing: -0.01em;
	}

	.track {
		display: flex;
		align-items: center;
		gap: 14px;
		color: var(--fg-muted);
		font-family: var(--mono);
		font-size: 13px;
		font-variant-numeric: tabular-nums;
	}

	.bar {
		flex: none;
		width: max(3px, calc((100% - 7ch - 14px) * var(--share)));
		height: 10px;
		border-radius: 3px;
		background: var(--border-default);
	}

	.tony .name,
	.tony .track {
		color: var(--fg-default);
	}

	/* One painting across the scale, so a shorter bar shows less of it. */
	.tony .bar {
		height: 14px;
		background: var(--painting) 0 0 / calc(100% / var(--share)) 100%;
	}

	.source {
		max-width: 720px;
		margin-top: 32px;
		line-height: 20px;
		text-wrap: pretty;
	}

	/* The menu bar panel on a lit stage from rail to rail, like a feature's window. */

	.stage {
		position: relative;
		margin: 72px calc(-1 * max(var(--pad), env(safe-area-inset-left))) 0;
		padding: 64px max(var(--pad), env(safe-area-inset-left));
		border-top: 1px solid var(--frame);
	}

	.panel {
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 28px;
		max-width: 880px;
		margin: 0 auto;
	}

	.shot {
		width: 100%;
	}

	/* Lit, the stage draws the panel's long shadow, which a CSS shadow draws in steps. */
	.lit .shot > :global(*) {
		box-shadow:
			0 0 0 1px var(--ring-faint),
			0 2px 4px rgb(0 0 0 / 0.08);
	}

	.panel figcaption {
		max-width: 560px;
		color: var(--fg-muted);
		font-size: 14px;
		line-height: 1.6;
		text-align: center;
		text-wrap: balance;
	}

	.answer :global(a),
	.faq-intro a,
	.source a,
	.panel figcaption a {
		color: var(--fg-default);
		font-weight: 500;
		text-decoration: underline;
		text-decoration-color: var(--border-strong);
		text-decoration-thickness: 1.5px;
		text-underline-offset: 3px;
	}

	.source a {
		color: inherit;
		font-weight: 400;
		text-decoration-thickness: 1px;
	}

	/* Questions. */

	.faq {
		display: grid;
		grid-template-columns: minmax(0, 6fr) minmax(0, 5fr);
		gap: 24px 64px;
		align-items: start;
	}

	.faq-intro {
		position: sticky;
		top: calc(var(--bar-h) + 32px);
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.faq-intro p,
	.sub {
		max-width: 560px;
		color: var(--fg-muted);
		font-size: 18px;
		line-height: 1.55;
		text-wrap: pretty;
	}

	.speed .sub {
		margin-top: 20px;
	}

	.faq-intro a {
		white-space: nowrap;
	}

	details + details {
		border-top: 1px solid var(--border-default);
	}

	summary {
		display: grid;
		grid-template-columns: 24px minmax(0, 1fr) 16px;
		gap: 16px;
		align-items: center;
		min-height: 64px;
		padding: 16px 0;
		list-style: none;
		cursor: pointer;
		-webkit-user-select: none;
		user-select: none;
	}

	summary::-webkit-details-marker {
		display: none;
	}

	.q {
		font-size: 16px;
		font-weight: 500;
		line-height: 24px;
		text-wrap: pretty;
	}

	.plus {
		position: relative;
		justify-self: end;
		width: 12px;
		height: 12px;
	}

	.plus::before,
	.plus::after {
		content: '';
		position: absolute;
		top: 50%;
		left: 0;
		width: 12px;
		height: 1.5px;
		margin-top: -0.75px;
		border-radius: 1px;
		background: var(--fg-muted);
		transition: rotate 200ms var(--ease);
	}

	.plus::after {
		rotate: 90deg;
	}

	details[open] .plus::after {
		rotate: 0deg;
	}

	summary:active .q {
		color: var(--fg-secondary);
	}

	.answer {
		max-width: 600px;
		padding: 0 32px 22px 40px;
		color: var(--fg-muted);
		font-size: 16px;
		line-height: 24px;
		text-wrap: pretty;
	}

	.answer :global(p + p) {
		margin-top: 8px;
	}

	details::details-content {
		height: 0;
		overflow: clip;
	}

	details[open]::details-content {
		height: auto;
	}

	@media (prefers-reduced-motion: no-preference) {
		details::details-content {
			interpolate-size: allow-keywords;
			transition:
				height 200ms var(--ease),
				content-visibility 200ms allow-discrete;
		}
	}

	/* The close. */

	.close {
		position: relative;
		padding: 56px 64px 64px;
	}

	.glow {
		position: absolute;
		z-index: -1;
		inset: 10% 20% 0 10%;
		background:
			radial-gradient(closest-side, #1957fa, transparent) 0 30% / 55% 80% no-repeat,
			radial-gradient(closest-side, #d94f46, transparent) 50% 60% / 50% 70% no-repeat,
			radial-gradient(closest-side, #fb8600, transparent) 100% 40% / 45% 70% no-repeat;
		filter: blur(48px);
		opacity: 0.14;
		pointer-events: none;
	}

	/* The glow drawn by WebGL, smooth where the CSS one steps; it paints its own background, so it covers the CSS
	   glow once it draws. */
	.close .gl {
		position: absolute;
		z-index: -1;
		inset: -8% 6% -18% -4%;
		color: var(--surface-root);
		pointer-events: none;
	}

	.end {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-end;
		justify-content: space-between;
		gap: 32px 48px;
	}

	.end > div:first-child {
		flex: 1 1 520px;
		max-width: 780px;
	}

	.end .sub {
		margin-top: 20px;
	}

	@media (hover: hover) and (pointer: fine) {
		summary:hover .plus::before,
		summary:hover .plus::after {
			background: var(--fg-default);
		}

		.answer :global(a:hover),
		.faq-intro a:hover,
		.source a:hover,
		.panel figcaption a:hover {
			text-decoration-color: var(--fg-default);
		}
	}

	@media (max-width: 1023px) {
		.cells {
			grid-template-columns: minmax(0, 1fr);
			margin-top: 48px;
		}

		.cells li {
			padding-block: 32px;
		}

		.cells li + li {
			border-left: 0;
		}

		.four {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}

		.four li:nth-child(even) {
			border-left: 1px solid var(--frame);
		}

		.chart {
			margin-top: 48px;
			padding-block: 32px;
		}

		.stage {
			margin-top: 48px;
			padding-block: 40px;
		}
	}

	@media (max-width: 859px) {
		.faq-intro p,
		.sub {
			font-size: 17px;
		}

		.speed,
		.faq {
			grid-template-columns: minmax(0, 1fr);
			gap: 32px;
		}

		.faq-intro {
			position: static;
		}

		.close {
			padding: 44px 28px 48px;
		}

		.end > div:first-child {
			flex-basis: auto;
		}

		.readout {
			container-type: inline-size;
		}

		.readout div {
			grid-template-columns: minmax(0, 1fr);
			grid-template-areas: 'value' 'label';
			gap: 8px;
		}

		.readout div::before {
			display: none;
		}

		.readout dd {
			font-size: 17cqi;
		}

		.readout dt {
			max-width: none;
			text-align: left;
		}
	}

	@media (max-width: 559px) {
		.four {
			grid-template-columns: minmax(0, 1fr);
		}

		.four li:nth-child(even) {
			border-left: 0;
		}

		.chart li {
			grid-template-columns: minmax(0, 1fr);
		}

		.stage {
			padding: 32px 12px;
		}

		summary {
			grid-template-columns: minmax(0, 1fr) 16px;
		}

		summary .idx {
			display: none;
		}

		.answer {
			padding: 0 24px 20px 0;
		}

		.close {
			margin-inline: -12px;
			padding: 40px 12px 44px;
		}
	}
</style>
