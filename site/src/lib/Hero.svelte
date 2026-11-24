<!-- The hero, after Grip's: the eyebrow and the headline with its quiet second sentence beside the pitch, then Tony
     itself on the lit plate: its pill and caption, recorded from the app, as a voice prompts a coding agent and the
     text lands in its prompt (`scripts/readme/make.ts`). The landing page adds the lede, buttons, and fine print. As a card it is the Open Graph image's source (`/og`): settled, the clip's dark still cut to the prompt, the
     caption, and the pill. -->
<script lang="ts">
	import type { Snippet } from 'svelte';
	import Arrow from '#lib/Arrow.svelte';
	import Glow, { type Layer } from '#lib/Glow.svelte';
	import Icon from '#lib/Icon.svelte';
	import Media from '#lib/Media.svelte';
	import { GITHUB_URL } from '#lib/links.ts';

	type Props = {
		/** Beside the headline: the lede, the buttons, and the fine print. */
		children?: Snippet;
		/** The hero as Tony's Open Graph image shows it: `pnpm og` screenshots it from `/og`. */
		card?: boolean;
	};

	let { children, card = false }: Props = $props();

	const HORIZON: readonly Layer[] = [{ box: [0, -0.46, 1, 0.9], peak: [0.42, 0.86], start: 0.18 }];
	const ALT =
		'Tony recorded as it runs: a terminal where a coding agent just fixed expired coupon codes, and Tony’s pill at the foot of the screen. A voice says “Nice, now do the same for gift cards, and make the error say the date the code expired, so people know it is not a typo.” The pill’s bars follow it, and a glass caption buds out of the pill, each word fading in as it is said. When the voice stops, the caption flows back into the pill and the sentence lands in the agent’s prompt, 63 ms later.';
</script>

<section class="hero" class:card aria-labelledby="hero-title">
	<div class="wrap intro">
		<div class="title">
			<a class="eyebrow" href={GITHUB_URL}>
				<Icon name="github" size={14} />
				<span>Free and open source macOS app</span>
				<Arrow class="ahead" />
			</a>
			<h1 id="hero-title">
				<span>Talk to your AI agents.</span>
				<span class="quiet">Free, private dictation for Mac.</span>
			</h1>
		</div>
		{#if children}
			<div class="pitch">{@render children()}</div>
		{/if}
	</div>
	<div class="plate beat">
		<div class="horizon" aria-hidden="true"></div>
		<div class="gl" aria-hidden="true">
			<Glow layers={HORIZON} opacity={0.85} />
		</div>
		<div class="wrap window">
			{#if card}
				<Media still="hero" take="dark" width={1440} height={936} crop={[0, 444, 1440, 492]} r={24} eager alt={ALT} />
			{:else}
				<Media clip="hero" width={1440} height={936} crop={[0, 216, 1440, 720]} r={24} eager alt={ALT} />
			{/if}
		</div>
	</div>
</section>

<style>
	/* The headline and lede beside the pitch, both settled on the line under them, so the clip starts on the first
	   screen. The pitch is as wide as its buttons, and its fine print wraps to them. */
	.intro {
		display: grid;
		grid-template-columns: minmax(0, 1fr) auto;
		column-gap: 56px;
		align-items: end;
		padding-block: 40px;
	}

	.pitch > :global(p) {
		contain: inline-size;
	}

	.title {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
	}

	.title > :global(*),
	.pitch > :global(*),
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

	h1 {
		--rise: 4px;
		--blur: 12px;
		--duration: 1400ms;
		--delay: 0ms;
		margin-top: 20px;
		font-size: clamp(34px, 3.2vw, 46px); /* two lines in its column from 1024 px up */
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
		isolation: isolate;
		padding: 40px 0;
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

	.gl {
		inset: 0 calc(50% - var(--col) / 2);
		color: var(--panel);
		animation: grow calc(1600ms * var(--pace)) var(--enter-ease) calc(450ms * var(--pace)) backwards;
	}

	/* The seam draws out from the middle as the light grows. */
	.plate {
		animation: seam calc(1600ms * var(--pace)) var(--enter-ease) calc(450ms * var(--pace)) backwards;
	}

	/* The bottom of a screen, where Tony lives: the agent's last lines, its prompt, the caption, and the pill. As wide
	   as the first screen leaves room for, so the pill shows without a scroll. */
	.window {
		--rise: 6px;
		--blur: 8px;
		--duration: 1400ms;
		--delay: 350ms;
		position: relative;
		display: flex;
		justify-content: center;
	}

	.window > :global(*) {
		max-width: max(720px, (100svh - 400px) * 2);
	}

	@keyframes grow {
		from {
			--grow: 0;
		}
	}

	@keyframes seam {
		from {
			--seam-w: 0;
		}
	}

	@keyframes swell {
		from {
			opacity: 0;
			scale: 0.6;
		}
	}

	/* The Open Graph card: 1200x630 in the dark theme, settled, its headline larger for a feed's small preview, and the
	   still cut to what Tony draws. */
	.card {
		height: 630px;
		overflow: hidden;
		color-scheme: dark;
		background: var(--surface-root);
		color: var(--fg-default);
	}

	.card .intro {
		grid-template-columns: minmax(0, 1fr);
		padding-block: 32px 36px;
	}

	.card h1 {
		font-size: 64px;
	}

	.card .window > :global(*) {
		max-width: 900px;
	}

	.card .title > :global(*),
	.card .window,
	.card .horizon,
	.card .gl,
	.card .plate,
	.card .plate::before {
		animation: none;
	}

	@media (hover: hover) and (pointer: fine) {
		.eyebrow:hover {
			box-shadow: inset 0 0 0 1px var(--border-default);
			color: var(--fg-default);
		}

		.eyebrow:hover :global(.ahead) {
			translate: 2px 0;
		}
	}

	/* The split needs the column at its full width; narrower, the pitch goes under the headline. */
	@media (max-width: 1279px) {
		.intro {
			grid-template-columns: minmax(0, 1fr);
		}

		h1 {
			font-size: clamp(34px, 6vw, 46px);
		}

		.pitch {
			margin-top: 32px;
		}
	}

	@media (max-width: 639px) {
		.plate {
			padding: 32px 0;
		}

		.window {
			padding-inline: 12px;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.title > :global(*),
		.pitch > :global(*),
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
