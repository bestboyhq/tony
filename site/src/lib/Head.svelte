<script lang="ts">
	import og from '#lib/assets/og.png';
	import { SITE_ORIGIN, SITE_URL } from '#lib/links.ts';

	type Props = {
		title: string;
		description: string;
		path: string;
		noindex?: boolean;
		/** Structured data, as JSON-LD: one script per object. */
		schema?: Record<string, unknown> | readonly Record<string, unknown>[];
	};

	let { title, description, path, noindex = false, schema }: Props = $props();

	const canonical = $derived(`${SITE_URL}${path}`);
	// The hero, rendered by `pnpm og`. Social sites cache an image by its URL, and this one's changes with its content.
	const image = `${SITE_ORIGIN}${og}`;
	const imageAlt =
		'Talk to your AI agents. Free, private dictation for Mac. Under the headline, a coding agent’s terminal, and Tony’s pill listening at the foot of the screen, with the words it hears in a glass caption above it.';
	// `<` escaped, so no string in the data can close the script element.
	const jsonLd = $derived(
		[schema ?? []]
			.flat()
			.map((item) => `<script type="application/ld+json">${JSON.stringify(item).replaceAll('<', '\\u003c')}</` + 'script>')
			.join(''),
	);
</script>

<svelte:head>
	<title>{title}</title>
	<meta name="description" content={description} />
	{#if noindex}
		<meta name="robots" content="noindex" />
	{:else}
		<link rel="canonical" href={canonical} />
	{/if}
	<meta property="og:type" content="website" />
	<meta property="og:site_name" content="Tony" />
	<meta property="og:title" content={title} />
	<meta property="og:description" content={description} />
	<meta property="og:url" content={canonical} />
	<meta property="og:image" content={image} />
	<meta property="og:image:width" content="1200" />
	<meta property="og:image:height" content="630" />
	<meta property="og:image:alt" content={imageAlt} />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:title" content={title} />
	<meta name="twitter:description" content={description} />
	<meta name="twitter:image" content={image} />
	<meta name="twitter:image:alt" content={imageAlt} />
	<link rel="alternate" type="text/plain" title="llms.txt" href="{SITE_URL}/llms.txt" />
	{#if jsonLd}{@html jsonLd}{/if}
</svelte:head>
