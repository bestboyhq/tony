<script lang="ts">
	import panelHome from '../../../.github/assets/home.webp';
	import panelSettings from '../../../.github/assets/settings.webp';
	import notice from '../../../.github/assets/notice.webp';
	import Arrow from '#lib/Arrow.svelte';
	import BeatLabel, { type Beat } from '#lib/BeatLabel.svelte';
	import FeatureRow from '#lib/FeatureRow.svelte';
	import Glow, { within, type Box, type Layer } from '#lib/Glow.svelte';
	import Head from '#lib/Head.svelte';
	import Icon from '#lib/Icon.svelte';
	import Pill from '#lib/Pill.svelte';
	import SectionHeading from '#lib/SectionHeading.svelte';
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

	const HORIZON: readonly Layer[] = [{ box: [0, -0.46, 1, 0.9], peak: [0.42, 0.86], start: 0.18 }];
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
		'fast',
		'accurate',
		'stats',
		'everywhere',
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

	const schema = {
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
		screenshot: `${SITE_ORIGIN}${panelHome}`,
		featureList: [
			'Dictate prompts to AI agents like Claude Code and Codex, in a terminal, an editor, or any chat box',
			'Hold a key to dictate into any app',
			'On-device, offline speech to text on the Neural Engine',
			'25 languages, detected as you speak',
			'Your words: names, brands, and jargon spelled your way',
			'Filler words removed',
		],
		softwareHelp: { '@type': 'CreativeWork', url: `${SITE_URL}/docs` },
		sameAs: [GITHUB_URL],
		author: { '@type': 'Organization', name: 'Bestboy', url: BESTBOY_URL },
	};

	const numbers = [
		{ value: '~50 ms', label: 'per sentence' },
		{ value: '5.8%', label: 'word error rate' },
		{ value: '25', label: 'languages' },
		{ value: '0 bytes', label: 'of audio leave your Mac' },
	];

	const steps = [
		{
			title: 'Hold a key',
			body: 'Listening starts the instant your key goes down, so your first word counts. Double-tap it for a long brief, hands free.',
		},
		{
			title: 'Speak your prompt',
			body: 'Ramble if you like. Tony transcribes on your Mac’s Neural Engine as you talk, so even five minutes lands at once.',
		},
		{
			title: 'Let go',
			body: 'Your prompt lands where the cursor is: your agent in the terminal, your editor, or any chat box. You press Return.',
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

	const speed = [
		{ spoken: '5 seconds', time: '49 ms' },
		{ spoken: '13 seconds', time: '70 ms' },
		{ spoken: '26 seconds', time: '147 ms' },
	];

	const models = [
		{ name: 'Whisper large-v3', wer: '7.44%', params: '1.55 B' },
		{ name: 'Parakeet TDT v3', wer: '6.26%', params: '0.6 B' },
		{ name: 'Parakeet Ultra,', suffix: 'in Tony', wer: '5.80%', params: '0.6 B', tony: true },
	];

	const trust = [
		{
			title: 'On your Mac',
			body: 'Audio stays in memory and is never written to disk. Once the model is downloaded, Tony dictates offline.',
		},
		{
			title: 'No account, no telemetry',
			body: 'Tony goes online only to download its models once and to check for updates. Your stats are counts, never what you said.',
		},
		{
			title: 'Open source',
			body: 'The code is public under AGPL-3.0, and CI builds every release from a tagged commit, so you can check what you run.',
		},
	];
</script>

<Head
	title="Tony - talk to your AI agents. Free, private dictation for Mac"
	description={SITE_DESCRIPTION}
	path=""
	{schema}
/>

<div class="progress" aria-hidden="true"></div>

<section class="hero" aria-labelledby="hero-title">
	<div class="wrap intro">
		<a class="eyebrow" href={GITHUB_URL}>
			<Icon name="github" size={14} />
			<span>Free and open source macOS app</span>
			<Arrow class="ahead" />
		</a>
		<h1 id="hero-title">
			<span>Talk to your AI agents.</span>
			<span class="quiet">Free, private dictation for Mac.</span>
		</h1>
		<p class="lede">
			<strong>Hold a key, speak your prompt, let go.</strong>
			It lands in Claude Code, Codex, your editor, or any chat box, with your project’s names spelled right
			and the “um” gone. Transcribed on your Mac in about 50 ms.
		</p>
		<div class="actions">
			<a class="button primary" href={DOWNLOAD_URL}>
				{@render apple()}
				Download for macOS
			</a>
			<a class="button secondary" href={docHref('/docs')}>Read the docs</a>
		</div>
		<p class="fine">macOS 15 or later on Apple silicon · No&nbsp;account · No&nbsp;subscription</p>
	</div>
	<div class="plate beat">
		<div class="horizon" aria-hidden="true"></div>
		<div class="gl" aria-hidden="true">
			<Glow layers={HORIZON} opacity={0.85} />
		</div>
		<div class="wrap window">
			<Pill />
		</div>
	</div>
</section>

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
		<ol class="cells">
			{#each steps as step, index (step.title)}
				<li class="rise">
					<span class="idx" aria-hidden="true">{pad(index + 1)}</span>
					<h3>{step.title}</h3>
					<p>{step.body}</p>
				</li>
			{/each}
		</ol>
	{/snippet}
</SectionHeading>

<FeatureRow
	id="prompting"
	beat={beat('prompting', 'Prompting')}
	mirrored
	title="Made for talking to agents"
	body="Agents need the exact names: the library, the service, the table. Add yours under Your words and Tony spells them your way, while the filler words come out."
	href={doc('ai-agents')}
	linkLabel="Prompting AI agents"
	checks={[
		'Works in Terminal, VS Code, Malini, and any chat box',
		'Esc cancels and keeps your words, one click from Paste',
		'Mid-prompt, no stray capital and no extra space',
	]}
>
	<div class="card said">
		<p class="label">You say</p>
		<blockquote>
			<span class="filler">Um,</span> so the <span class="heard">super base</span> migration fails. Can you,
			<span class="filler">uh,</span> check the policies?
		</blockquote>
		<p class="label">Tony types</p>
		<p class="typed">
			So the <span class="word">Supabase</span> migration fails. Can you check the policies?
		</p>
		<p class="note">With Supabase in your words.</p>
	</div>
</FeatureRow>

<FeatureRow
	id="fast"
	beat={beat('fast', 'Speed')}
	title="Fast, from the first word"
	body="A sentence takes about 50 ms on the Neural Engine. Tony transcribes in the background at each pause while you keep talking, so letting go is as instant after a five-minute brief as after one line."
	href={doc('speed-and-accuracy')}
	linkLabel="Speed and accuracy"
	checks={[
		'Capture starts on key down, not a beat later',
		'Warm at launch, so the first dictation is as quick as the hundredth',
		'Between dictations the mic is closed and the CPU rests',
	]}
>
	<figure class="card">
		<table>
			<caption>How long Tony takes to transcribe</caption>
			<thead>
				<tr><th scope="col">You speak for</th><th scope="col">Tony transcribes it in</th></tr>
			</thead>
			<tbody>
				{#each speed as row (row.spoken)}
					<tr><td>{row.spoken}</td><td class="figure">{row.time}</td></tr>
				{/each}
			</tbody>
		</table>
		<figcaption>
			Parakeet Ultra on the Neural Engine of a MacBook Pro with M5 Pro, median of 5 runs. The clips were read
			by a macOS voice, and every one came out word for word.
		</figcaption>
	</figure>
</FeatureRow>

<FeatureRow
	id="accurate"
	beat={beat('accurate', 'Accuracy')}
	mirrored
	title="Accurate, in 25 languages"
	body="Tony runs Parakeet Ultra: NVIDIA’s Parakeet TDT v3, post-trained by Moondream to make fewer errors on every benchmark they report. It detects your language as you speak, and you can switch mid-dictation."
	href={doc('languages')}
	linkLabel="All 25 languages"
	checks={[
		'Punctuation and capitals, written by the model',
		'Switch languages mid-dictation, with no setting to touch',
		'Silence types nothing: no phantom “Thank you.”',
	]}
>
	<figure class="card">
		<table>
			<caption>English word error rate, lower is better</caption>
			<thead>
				<tr>
					<th scope="col">Model</th>
					<th scope="col">Error rate</th>
					<th scope="col">Parameters</th>
				</tr>
			</thead>
			<tbody>
				{#each models as model (model.name)}
					<tr class:tony={model.tony}>
						<td>
							{model.name}
							{#if model.suffix}<span class="nowrap">{model.suffix}</span>{/if}
						</td>
						<td class="figure">{model.wer}</td>
						<td class="figure">{model.params}</td>
					</tr>
				{/each}
			</tbody>
		</table>
		<figcaption>
			Averages over the
			<a href="https://huggingface.co/spaces/hf-audio/open_asr_leaderboard">Open ASR Leaderboard</a>
			English sets: Parakeet from
			<a href="https://huggingface.co/moondream/parakeet-ultra">Moondream’s model card</a>, Whisper from the
			<a href="https://arxiv.org/abs/2510.06961">leaderboard paper</a>.
		</figcaption>
	</figure>
</FeatureRow>

<SectionHeading
	id="stats"
	beat={beat('stats', 'Menu bar')}
	title="Everything Tony did for you."
	quiet="One click away, in the menu bar."
	description="Click Tony in the menu bar for a glass panel with your last dictation, your stats, and Settings. Like the pill, it never takes focus from your app, so Paste lands where you were typing."
>
	{#snippet after()}
		<div class="panels">
			<figure class="rise">
				<img
					class="shot"
					src={panelHome}
					width="1038"
					height="1500"
					loading="lazy"
					decoding="async"
					alt="The menu bar panel: the last dictation with Copy and Paste, 65,292 words dictated, 20 hours saved over typing, 152 words a minute, 100 ms from key up to text, a 25-day streak, six months of activity, and the apps you dictate into"
				/>
				<figcaption>
					<strong>Your stats.</strong> Words dictated and the time they saved, your pace, how fast your text
					lands, your streak, and six months of activity.
					<a href={doc('menu-bar')}>The menu bar panel</a>
				</figcaption>
			</figure>
			<figure class="rise">
				<img
					class="shot"
					src={panelSettings}
					width="1038"
					height="1500"
					loading="lazy"
					decoding="async"
					alt="Settings in the panel: the key, the microphone, the language, your words as tags, and Open at login"
				/>
				<figcaption>
					<strong>Four settings.</strong> The key, the mic, the languages, and your words: where people really
					differ. Everything else is a tuned default.
					<a href={doc('settings')}>Settings</a>
				</figcaption>
			</figure>
		</div>
	{/snippet}
</SectionHeading>

<FeatureRow
	id="everywhere"
	beat={beat('everywhere', 'Every app')}
	title="Works in every app"
	body="Native apps, Safari and Chrome, Slack and VS Code, Terminal: if it takes paste, it takes Tony. Every dictation stays on your clipboard, so when a paste can’t land, ⌘V brings it back."
	href={docHref('/docs')}
	linkLabel="How Tony works"
	checks={[
		'QWERTY, Dvorak, and Cyrillic layouts all paste correctly',
		'Undo is one ⌘Z: a dictation lands as a single paste',
		'Your music fades out while you talk, and back in after',
	]}
>
	<img
		class="shot notice"
		src={notice}
		width="1200"
		height="360"
		loading="lazy"
		decoding="async"
		alt="The pill says 1Password has secure input on: press ⌘V to paste"
	/>
</FeatureRow>

<SectionHeading
	id="private"
	beat={beat('private', 'Privacy')}
	title="Your voice never leaves the Mac."
	quiet="Neither do your prompts."
	description="Prompts carry your codebase’s names and your half-formed ideas. Tony hears them on your Mac, and the only place they go is the app you paste into."
>
	<a class="arrow-link more" href={doc('privacy')}>
		Privacy and offline use
		<Arrow class="ahead" />
	</a>
	{#snippet after()}
		<ul class="cells">
			{#each trust as item, index (item.title)}
				<li class="rise">
					<span class="idx" aria-hidden="true">{pad(index + 1)}</span>
					<h3>{item.title}</h3>
					<p>{item.body}</p>
				</li>
			{/each}
		</ul>
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
					<p class="fine">Free and open source · AGPL-3.0</p>
				</div>
			</div>
		</div>
	</div>
</section>

{#snippet apple()}
	<svg class="apple" viewBox="4 3.1 14.8 18.2" width="13" height="16" aria-hidden="true" fill="currentColor">
		<path
			d="M16.37 12.73c-.02-2.3 1.88-3.4 1.96-3.46-1.07-1.56-2.73-1.78-3.32-1.8-1.41-.14-2.76.83-3.48.83-.72 0-1.82-.81-3-.79-1.54.02-2.97.9-3.76 2.28-1.6 2.78-.41 6.9 1.15 9.16.76 1.1 1.67 2.34 2.86 2.3 1.15-.05 1.58-.74 2.97-.74s1.78.74 3 .72c1.24-.02 2.02-1.12 2.78-2.23.88-1.28 1.24-2.52 1.26-2.58-.03-.01-2.4-.92-2.42-3.69ZM14.1 5.98c.63-.77 1.06-1.83.94-2.89-.91.04-2.02.61-2.67 1.37-.58.67-1.1 1.76-.96 2.8 1.02.08 2.06-.52 2.69-1.28Z"
		/>
	</svg>
{/snippet}

<style>
	.progress {
		display: none;
	}

	@supports (animation-timeline: scroll()) {
		.progress {
			position: fixed;
			z-index: 50;
			inset: 0 0 auto;
			display: block;
			height: 3px;
			background: var(--painting);
			transform-origin: 0 50%;
			animation: fill linear both;
			animation-timeline: scroll(root);
		}
	}

	@keyframes fill {
		from {
			scale: 0 1;
		}
	}

	/* The hero: an app's hero has no panel, and the painting glows behind its window, never behind text. */

	.intro {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		padding-top: 72px;
		padding-bottom: 64px;
	}

	.intro > *,
	.window {
		animation: blur-in calc(var(--duration) * var(--pace)) var(--enter-ease)
			calc(var(--delay) * var(--pace)) backwards;
	}

	.eyebrow {
		--rise: 3px;
		--blur: 8px;
		--duration: 1200ms;
		--delay: 250ms;
		display: inline-flex;
		align-items: center;
		gap: 6px;
		height: 30px;
		padding: 0 11px 0 10px;
		white-space: nowrap;
		border-radius: 999px;
		box-shadow: inset 0 0 0 1px var(--border-subtle);
		color: var(--fg-secondary);
		font-size: 13px;
		font-weight: 500;
		text-decoration: none;
	}

	.eyebrow :global(.ahead) {
		width: 11px;
		height: 11px;
		color: var(--fg-faint);
	}

	.apple {
		translate: 0 -1.5px;
	}

	h1 {
		--rise: 4px;
		--blur: 12px;
		--duration: 1400ms;
		--delay: 0ms;
		margin-top: 24px;
		font-size: clamp(38px, 5.2vw, 68px);
		font-weight: 550;
		line-height: 1.02;
		letter-spacing: -0.04em;
		text-wrap: balance;
	}

	h1 span {
		display: block;
	}

	.quiet {
		color: var(--fg-faint);
	}

	.lede {
		--rise: 3px;
		--blur: 10px;
		--duration: 1300ms;
		--delay: 150ms;
		max-width: 640px;
		margin-top: 24px;
		color: var(--fg-muted);
		font-size: 19px;
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
		margin-top: 32px;
	}

	.fine {
		--rise: 3px;
		--blur: 8px;
		--duration: 1300ms;
		--delay: 300ms;
		margin-top: 16px;
		color: var(--fg-muted);
		font-size: 13px;
		line-height: 1.55;
	}

	.plate {
		--seam: linear-gradient(
			90deg,
			transparent 4%,
			#1957fa 18%,
			#6365cd 32%,
			#9e6594 44%,
			#d35351 58%,
			#ed3e11 70%,
			#fb8400 82%,
			transparent 96%
		);
		--delay: 350ms;
		isolation: isolate;
		padding: 64px 0;
		background: linear-gradient(var(--panel) 0 0) 50% 0 / var(--col) 100% no-repeat;
	}

	@property --grow {
		syntax: '<number>';
		inherits: true;
		initial-value: 1;
	}

	.horizon,
	.gl {
		position: absolute;
		z-index: -1;
		pointer-events: none;
	}

	.horizon {
		inset: -46% calc(50% - var(--col) / 2) auto;
		height: 90%;
		background: var(--painting);
		mask-image: radial-gradient(
			closest-side,
			light-dark(rgb(0 0 0 / 0.42), rgb(0 0 0 / 0.86)) 18%,
			transparent
		);
		filter: blur(48px);
		opacity: 0.85;
		clip-path: inset(calc(100% * 46 / 90) 0 0 0);
		animation: swell calc(1600ms * var(--pace)) var(--enter-ease) calc(450ms * var(--pace)) backwards;
	}

	.plate .gl {
		inset: 0 calc(50% - var(--col) / 2);
		color: var(--panel);
		animation: grow calc(1600ms * var(--pace)) var(--enter-ease) calc(450ms * var(--pace)) backwards;
	}

	.window {
		--rise: 6px;
		--blur: 8px;
		--duration: 1400ms;
		--delay: 350ms;
		position: relative;
	}

	@keyframes grow {
		from {
			--grow: 0;
		}
	}

	@keyframes swell {
		from {
			opacity: 0;
			scale: 0.6;
		}
	}

	/* The README's images are real windows on their wallpaper, cornered 40px at their natural size. */
	.shot {
		display: block;
		width: 100%;
		height: auto;
		border-radius: calc(100cqi * 40 / 1200);
		box-shadow:
			0 0 0 1px var(--ring-faint),
			0 2px 4px rgb(0 0 0 / 0.08),
			0 32px 64px -24px rgb(0 0 0 / 0.45);
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

	/* Cells: three across, split by hairlines from rail to rail. */

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

	.more {
		margin-top: 20px;
	}

	.cells .arrow-link {
		margin-top: auto;
		padding-top: 8px;
	}

	/* The menu bar panel: two windows on a plate from rail to rail. */

	.panels {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		margin: 72px calc(-1 * max(var(--pad), env(safe-area-inset-left))) 0;
		border-top: 1px solid var(--frame);
		background: var(--panel);
	}

	.panels figure {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 24px;
		margin: 0;
		padding: 56px var(--pad);
		container-type: inline-size;
	}

	.panels figure + figure {
		border-left: 1px solid var(--frame);
	}

	.panels .shot {
		max-width: 400px;
		border-radius: calc(min(100cqi, 400px) * 40 / 1038);
	}

	.panels figcaption {
		max-width: 400px;
		color: var(--fg-muted);
		font-size: 15px;
		line-height: 1.6;
		text-wrap: pretty;
	}

	.panels figcaption strong {
		color: var(--fg-default);
		font-weight: 550;
	}

	.notice {
		max-width: 600px;
		border-radius: calc(min(100cqi, 600px) * 40 / 1200);
	}

	/* A feature's window: a card that reads as one of Tony's own panels. */

	.card {
		width: 100%;
		max-width: 560px;
		margin: 0;
		padding: 8px 24px 20px;
		border-radius: 14px;
		background: var(--surface-elevated);
		box-shadow:
			0 0 0 1px var(--ring-faint),
			0 2px 4px rgb(0 0 0 / 0.08),
			0 32px 64px -24px rgb(0 0 0 / 0.45);
	}

	.card table {
		width: 100%;
		border-collapse: collapse;
		font-size: 15px;
	}

	.card caption,
	.said .label {
		padding: 14px 0 10px;
		color: var(--fg-secondary);
		font-family: var(--mono);
		font-size: 12px;
		line-height: 16px;
		text-align: left;
	}

	.card th,
	.card td {
		padding: 12px 12px 12px 0;
		border-bottom: 1px solid var(--border-default);
		text-align: left;
		vertical-align: bottom;
	}

	.card th:last-child,
	.card td:last-child {
		padding-right: 0;
	}

	.card th {
		color: var(--fg-muted);
		font-size: 13px;
		font-weight: 500;
	}

	.card th:not(:first-child) {
		text-align: right;
	}

	.card td {
		color: var(--fg-secondary);
	}

	.card tbody tr:last-child td {
		border-bottom: 0;
	}

	.card .figure {
		color: var(--fg-default);
		font-family: var(--mono);
		font-size: 14px;
		font-variant-numeric: tabular-nums;
		text-align: right;
		white-space: nowrap;
	}

	.card tr.tony td {
		color: var(--fg-default);
		font-weight: 550;
	}

	.card tr.tony td:first-child::before {
		content: '';
		display: inline-block;
		width: 8px;
		height: 8px;
		margin-right: 8px;
		border-radius: 50%;
		background: var(--brand);
		vertical-align: 1px;
	}

	.card figcaption {
		margin-top: 14px;
		color: var(--fg-muted);
		font-size: 12px;
		line-height: 1.55;
		text-wrap: pretty;
	}

	.said {
		padding: 14px 28px 24px;
	}

	.said blockquote {
		margin: 0 0 16px;
		color: var(--fg-secondary);
		font-size: 17px;
		line-height: 1.6;
		text-wrap: pretty;
	}

	.filler {
		color: var(--fg-faint);
		text-decoration: line-through;
	}

	.heard {
		text-decoration: underline wavy var(--fg-faint);
		text-decoration-thickness: 1px;
		text-underline-offset: 4px;
	}

	.typed {
		padding: 16px 18px;
		border-radius: 10px;
		background: var(--surface-well);
		box-shadow: inset 0 0 0 1px var(--border-subtle);
		color: var(--fg-default);
		font-size: 17px;
		line-height: 1.6;
		text-wrap: pretty;
	}

	.word {
		font-weight: 550;
		text-decoration: underline 2px var(--brand);
		text-underline-offset: 4px;
	}

	.said .note {
		margin-top: 12px;
		color: var(--fg-muted);
		font-size: 12px;
	}

	.answer :global(a),
	.faq-intro a,
	figcaption a {
		color: var(--fg-default);
		font-weight: 500;
		text-decoration: underline;
		text-decoration-color: var(--border-strong);
		text-decoration-thickness: 1.5px;
		text-underline-offset: 3px;
	}

	.card figcaption a {
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

	h2 {
		font-size: clamp(30px, 3.4vw, 40px);
		font-weight: 550;
		line-height: 1.1;
		letter-spacing: -0.03em;
		text-wrap: balance;
	}

	.faq-intro p,
	.sub {
		max-width: 560px;
		color: var(--fg-muted);
		font-size: 18px;
		line-height: 1.55;
		text-wrap: pretty;
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
		inset: -8% 6% -18% -4%;
		color: var(--surface-root);
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

	.close-actions .actions {
		margin-top: 0;
	}

	@media (hover: hover) and (pointer: fine) {
		.eyebrow:hover {
			box-shadow: inset 0 0 0 1px var(--border-default);
			color: var(--fg-default);
		}

		.eyebrow:hover :global(.ahead) {
			translate: 2px 0;
		}

		summary:hover .plus::before,
		summary:hover .plus::after {
			background: var(--fg-default);
		}

		.answer :global(a:hover),
		.faq-intro a:hover,
		figcaption a:hover {
			text-decoration-color: var(--fg-default);
		}
	}

	@media (max-width: 1023px) {
		.intro {
			padding-top: 56px;
		}

		.cells,
		.panels {
			grid-template-columns: minmax(0, 1fr);
			margin-top: 48px;
		}

		.cells li {
			padding-block: 32px;
		}

		.cells li + li,
		.panels figure + figure {
			border-left: 0;
		}

		.panels figure + figure {
			border-top: 1px solid var(--frame);
		}
	}

	@media (max-width: 859px) {
		.lede,
		.faq-intro p,
		.sub {
			font-size: 17px;
		}

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

	@media (max-width: 639px) {
		.plate {
			padding: 40px 0;
		}

		.window {
			padding-inline: 12px;
		}

		.card {
			padding: 4px 16px 16px;
		}

		.card table {
			font-size: 14px;
		}

		.said {
			padding: 12px 18px 18px;
		}
	}

	@media (max-width: 559px) {
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

	@media (prefers-reduced-motion: reduce) {
		.intro > *,
		.window {
			animation: fade-in 400ms ease backwards;
		}

		.horizon,
		.gl,
		.plate {
			animation: none;
		}
	}
</style>
