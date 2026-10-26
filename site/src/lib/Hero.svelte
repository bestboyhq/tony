<script lang="ts">
	import Arrow from '#lib/Arrow.svelte';
	import Glow, { type Layer } from '#lib/Glow.svelte';
	import Icon from '#lib/Icon.svelte';
	import Pill from '#lib/Pill.svelte';
	import { GITHUB_URL } from '#lib/links.ts';
	import type { Snippet } from 'svelte';

	type Props = {
		/** What follows the headline on the home page: the lede, the buttons, and the fine print. */
		children?: Snippet;
		/** The hero as Tony's Open Graph image shows it: `pnpm og` screenshots it from `/og`. */
		card?: boolean;
	};

	let { children, card = false }: Props = $props();

	const HORIZON: readonly Layer[] = [{ box: [0, -0.46, 1, 0.9], peak: [0.42, 0.86], start: 0.18 }];
</script>

<section class="hero" class:card aria-labelledby="hero-title">
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
		{@render children?.()}
	</div>
	<div class="plate beat">
		<div class="horizon" aria-hidden="true"></div>
		<div class="gl" aria-hidden="true">
			<Glow layers={HORIZON} opacity={0.85} />
		</div>
		<div class="wrap window">
			<Pill still={card} />
		</div>
	</div>
</section>

<style>
	/* An app's hero has no panel, and the painting glows behind its window, never behind text. */

	.intro {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		padding-top: 72px;
		padding-bottom: 64px;
	}

	.intro > :global(*),
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

	.gl {
		inset: 0 calc(50% - var(--col) / 2);
		color: var(--panel);
		animation: grow calc(1600ms * var(--pace)) var(--enter-ease) calc(450ms * var(--pace)) backwards;
	}

	/* The seam draws out from the middle as the light grows. */
	.plate {
		animation: seam calc(1600ms * var(--pace)) var(--enter-ease) calc(450ms * var(--pace)) backwards;
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

	/* The Open Graph card: 1200x630 in the dark theme, settled, its headline larger for a feed's small preview,
	   and the stage cut off by the bottom edge. */
	.card {
		height: 630px;
		overflow: hidden;
		color-scheme: dark;
		background: var(--surface-root);
		color: var(--fg-default);
	}

	.card .intro {
		padding-block: 40px 44px;
	}

	.card h1 {
		font-size: 80px;
	}

	.card .plate {
		padding-top: 48px;
	}

	.card .intro > :global(*),
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

	@media (max-width: 1023px) {
		.intro {
			padding-top: 56px;
		}
	}

	@media (max-width: 639px) {
		.plate {
			padding: 40px 0;
		}

		.window {
			padding-inline: 12px;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.intro > :global(*),
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
