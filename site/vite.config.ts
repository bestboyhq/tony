import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [
		sveltekit({
			adapter: adapter({ pages: 'build/tony', assets: 'build/tony', strict: true }),
			paths: { base: '/tony', relative: false },
			prerender: { handleHttpError: 'fail', handleMissingId: 'fail' },
			// Each page's CSS, a few KB, in its HTML, and the whole site's JS in one file: the first paint waits on
			// no stylesheet, and a page needs one script, cached for every other page.
			inlineStyleThreshold: 100_000,
			output: { bundleStrategy: 'single' },
		}),
	],
	// The README's images in .github/assets, outside this folder.
	server: { fs: { allow: ['..'] } },
});
