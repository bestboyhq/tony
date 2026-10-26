<script lang="ts">
	import { MediaQuery } from 'svelte/reactivity';
	import frame from '#lib/assets/pill-still.webp';
	import moving from '../../../.github/assets/pill.webp';

	// The README's loop is 1.7 MB, so its first frame paints with the page, and the loop lays over it once the
	// page has loaded and the loop is decoded. Reduce Motion, Save-Data, and `still` keep the first frame.
	let { still = false }: { still?: boolean } = $props();

	const motion = new MediaQuery('prefers-reduced-motion: no-preference', false);
	let loaded = $state(false);

	$effect(() => {
		const connection = (navigator as Navigator & { connection?: { saveData?: boolean } }).connection;
		if (still || !motion.current || loaded || connection?.saveData) return;
		let gone = false;
		function load() {
			const image = new Image();
			image.src = moving;
			image.decode().then(
				() => {
					if (!gone) loaded = true;
				},
				() => {},
			);
		}
		if (document.readyState === 'complete') load();
		else addEventListener('load', load, { once: true });
		return () => {
			gone = true;
			removeEventListener('load', load);
		};
	});
</script>

<div class="pill">
	<img
		src={frame}
		width="1200"
		height="362"
		alt="Tony's pill listening: its blue-to-orange dot glows and nine bars follow a voice."
		fetchpriority="high"
	/>
	{#if motion.current && loaded}
		<img class="moving" src={moving} width="1200" height="362" alt="" />
	{/if}
</div>

<style>
	.pill {
		position: relative;
		max-width: 720px;
		margin: 0 auto;
		container-type: inline-size;
	}

	/* A real window on its wallpaper, cornered 40px at its natural 1200px, as Bestboy's design frames a shot. */
	img {
		display: block;
		width: 100%;
		height: auto;
		border-radius: calc(100cqi * 40 / 1200);
	}

	img:first-child {
		box-shadow:
			0 0 0 1px var(--ring-faint),
			0 2px 4px rgb(0 0 0 / 0.08),
			0 32px 64px -24px rgb(0 0 0 / 0.45);
	}

	.moving {
		position: absolute;
		inset: 0;
	}
</style>
