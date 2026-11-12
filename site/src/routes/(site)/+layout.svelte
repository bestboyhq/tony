<script lang="ts">
	import { page } from '$app/state';
	import Bar from '#lib/Bar.svelte';
	import Footer from '#lib/Footer.svelte';
	import { docHref, HOME } from '#lib/links.ts';
	import { LOGDASH_SITE } from '#lib/logdash.ts';
	import { press } from '#lib/track.ts';
	import { dev } from '$app/env';
	import type { Snippet } from 'svelte';

	let { children }: { children: Snippet } = $props();

	const inDocs = $derived(page.url.pathname.startsWith(docHref('/docs')));
	const product = $derived(page.route.id !== '/(site)/404');
</script>

<svelte:document onclickcapture={press} onauxclickcapture={press} />

<svelte:head>
	{#if !dev}
		<script defer src="{HOME}/_ld/script.js" data-site={LOGDASH_SITE} data-endpoint="{HOME}/_ld/events"></script>
	{/if}
</svelte:head>

<div class="site">
	<a class="skip" href="#main">Skip to content</a>
	<Bar {inDocs} />
	<main id="main">
		{@render children()}
	</main>
	<Footer sitemap={product} />
</div>
