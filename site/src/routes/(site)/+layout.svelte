<script lang="ts">
	import { page } from '$app/state';
	import Bar from '#lib/Bar.svelte';
	import Footer from '#lib/Footer.svelte';
	import { docHref } from '#lib/links.ts';
	import type { Snippet } from 'svelte';

	let { children }: { children: Snippet } = $props();

	const inDocs = $derived(page.url.pathname.startsWith(docHref('/docs')));
	const product = $derived(page.route.id !== '/(site)/404');
</script>

<div class="site">
	<a class="skip" href="#main">Skip to content</a>
	<Bar {inDocs} />
	<main id="main">
		{@render children()}
	</main>
	<Footer sitemap={product} />
</div>
