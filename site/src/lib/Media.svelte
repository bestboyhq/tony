<!-- A real clip or still of Tony, ported from Grip's site: its own corner radius, a hairline ring, and a shadow.
     Each comes in a dark and a light take (`scripts/readme/make.ts`), and shows the one that matches the page, so the
     other never downloads: the still is a background each theme picks, and the clip's file is set once the page knows
     its theme. A clip plays muted in a loop only while it is the clip most on screen; a press on its button pauses or
     plays it, and under reduced motion it holds its still until someone presses play. -->
<script module lang="ts">
	import { asset } from '$app/paths';

	export type Clip = 'hero' | 'long' | 'words' | 'languages';
	export type Still = Clip | 'panel';

	const still = (name: Still, light: boolean): string => asset(`media/${name}${light ? '-light' : ''}.webp`);
	const movie = (name: Clip, light: boolean): string => asset(`media/${name}${light ? '-light' : ''}.mp4`);

	// Only the clip most in view plays: Chrome takes two playing at once for a video call and holds the whole page to
	// 60 Hz while they play, so a scroll on a 120 Hz display drops every other frame. Another clip takes over once it
	// shows a fifth more of itself than the playing one, so two clips in view at a like share do not trade back and
	// forth.
	const SWITCH = 0.2;
	const clips = new Map<HTMLVideoElement, { share: number; held: () => boolean }>();
	let playing: HTMLVideoElement | null = null;
	let seen: IntersectionObserver | null = null;

	function start(media: HTMLVideoElement | null): void {
		playing = media;
		for (const other of clips.keys()) if (other !== media) other.pause();
		if (media?.paused) media.play().catch(() => {});
	}

	function choose(): void {
		let most: HTMLVideoElement | null = null;
		let top = 0;
		for (const [media, { share, held }] of clips)
			if (!held() && share > top) [most, top] = [media, share];
		const current = playing ? clips.get(playing) : undefined;
		const keep = current && !current.held() && current.share > 0 && current.share + SWITCH >= top;
		start(keep ? playing : most);
	}

	function follow(media: HTMLVideoElement, held: () => boolean): () => void {
		seen ??= new IntersectionObserver(
			(entries) => {
				for (const { target, isIntersecting, intersectionRatio } of entries) {
					const clip = clips.get(target as HTMLVideoElement);
					if (clip) clip.share = isIntersecting ? intersectionRatio : 0;
				}
				choose();
			},
			{ threshold: Array.from({ length: 21 }, (_, step) => step / 20) },
		);
		clips.set(media, { share: 0, held });
		seen.observe(media);
		return () => {
			seen?.unobserve(media);
			clips.delete(media);
			if (playing === media) playing = null;
		};
	}

	// Calls `set` with whether the page is light, now and on each change: the theme the visitor picked, or the system's.
	function theme(set: (light: boolean) => void): () => void {
		const root = document.documentElement;
		const system = matchMedia('(prefers-color-scheme: light)');
		let last: boolean | undefined;
		const read = (): void => {
			const light = root.dataset.theme ? root.dataset.theme === 'light' : system.matches;
			if (light !== last) set((last = light));
		};
		read();
		const picks = new MutationObserver(read);
		picks.observe(root, { attributeFilter: ['data-theme'] });
		system.addEventListener('change', read);
		return () => {
			picks.disconnect();
			system.removeEventListener('change', read);
		};
	}
</script>

<script lang="ts">
	type Props = (
		| { clip: Clip; still?: undefined }
		// A still alone.
		| { still: Still; clip?: undefined }
	) & {
		width: number;
		height: number;
		alt: string;
		// The corner radius in the media's own pixels, so the frame follows the corner at any size.
		r: number;
		// The part to show (x, y, width, height), in the media's pixels.
		crop?: readonly [number, number, number, number];
		// One take whatever the page's theme, as the Open Graph card draws the dark one.
		take?: 'dark' | 'light';
		eager?: boolean;
	};

	let { clip, still: only, width, height, alt, r, crop, take, eager = false }: Props = $props();

	// A clip shows its own still until it draws its first frame.
	const name: Still = $derived(clip ?? only!);

	const box = $derived(crop ?? [0, 0, width, height]);
	// The media's size and offset as shares of the box: CSS percentages of a background's spare room, and of the
	// frame's width for the clip.
	const scale = $derived([(width / box[2]) * 100, (height / box[3]) * 100]);
	const at = (offset: number, spare: number): number => (spare ? (offset / spare) * 100 : 0);

	let paused = $state(true);
	let held = $state(false);
	let video = $state<HTMLVideoElement>();

	function watch(media: HTMLVideoElement, name: Clip): () => void {
		held = matchMedia('(prefers-reduced-motion: reduce)').matches;
		const set = (light: boolean): void => {
			const resume = playing === media;
			media.src = movie(name, light);
			if (resume) media.play().catch(() => {});
		};
		const unwatch = take ? (set(take === 'light'), () => {}) : theme(set);
		const unfollow = follow(media, () => held);
		return () => {
			unwatch();
			unfollow();
		};
	}

	function toggle(): void {
		held = !paused;
		if (held) video?.pause();
		else if (video) start(video);
	}
</script>

<div
	class="frame"
	class:held
	style:aspect-ratio="{box[2]} / {box[3]}"
	style:border-radius="{(r / box[2]) * 100}% / {(r / box[3]) * 100}%"
	style:--size="{scale[0]}% {scale[1]}%"
	style:--at="{at(box[0], width - box[2])}% {at(box[1], height - box[3])}%"
	style:--dark="url({still(name, take === 'light')})"
	style:--light="url({still(name, take !== 'dark')})"
>
	<div class="still" role="img" aria-label={alt}></div>
	{#if clip}
		<video
			bind:this={video}
			bind:paused
			{@attach (media) => watch(media, clip)}
			{width}
			{height}
			style:width="{scale[0]}%"
			style:margin="{(-box[1] / box[2]) * 100}% 0 0 {(-box[0] / box[2]) * 100}%"
			muted
			loop
			playsinline
			disablepictureinpicture
			preload={eager ? 'auto' : 'none'}
			aria-hidden="true"
		></video>
		<button
			class="toggle"
			type="button"
			aria-label={paused ? 'Play the clip' : 'Pause the clip'}
			onclick={toggle}
		>
			<svg viewBox="0 0 16 16" aria-hidden="true">
				{#if paused}
					<path d="M5 3.4v9.2a.6.6 0 0 0 .92.5l7.1-4.6a.6.6 0 0 0 0-1L5.92 2.9A.6.6 0 0 0 5 3.4Z" />
				{:else}
					<rect x="4" y="3" width="2.6" height="10" rx=".8" />
					<rect x="9.4" y="3" width="2.6" height="10" rx=".8" />
				{/if}
			</svg>
		</button>
	{/if}
</div>

<style>
	/* Its own stacking context, so the rounded clip sits on the frame's own layer: clipped from outside one, a playing
	   video can lose its corners in Safari. */
	.frame {
		position: relative;
		isolation: isolate;
		width: 100%;
		overflow: hidden;
		background: var(--surface-elevated);
		box-shadow:
			0 0 0 1px var(--ring-faint),
			0 2px 4px rgb(0 0 0 / 0.08),
			0 32px 64px -24px rgb(0 0 0 / 0.45);
	}

	/* The still of the page's theme: only the background a rule applies downloads. */
	.still {
		position: absolute;
		inset: 0;
		background: var(--dark) var(--at) / var(--size) no-repeat;
	}

	:global(:root[data-theme='light']) .still {
		background-image: var(--light);
	}

	@media (prefers-color-scheme: light) {
		:global(:root:not([data-theme='dark'])) .still {
			background-image: var(--light);
		}
	}

	/* Over its still, which shows through until the clip draws its first frame. */
	video {
		position: relative;
		display: block;
		max-width: none;
		height: auto;
	}

	.toggle {
		position: absolute;
		right: 12px;
		bottom: 12px;
		display: grid;
		place-items: center;
		width: 32px;
		height: 32px;
		padding: 0;
		border: 0;
		border-radius: 999px;
		background: rgb(0 0 0 / 0.56);
		color: #fff;
		backdrop-filter: blur(8px);
		cursor: pointer;
		opacity: 0;
		transition: opacity 180ms var(--ease);
	}

	.toggle svg {
		width: 14px;
		height: 14px;
		fill: currentColor;
	}

	.held .toggle,
	.toggle:focus-visible {
		opacity: 1;
	}

	@media (hover: hover) and (pointer: fine) {
		.frame:hover .toggle {
			opacity: 1;
		}

		.toggle:hover {
			background: rgb(0 0 0 / 0.72);
		}
	}

	@media (pointer: coarse) {
		.toggle {
			opacity: 1;
		}

		.toggle::after {
			content: '';
			position: absolute;
			inset: -6px;
		}
	}
</style>
