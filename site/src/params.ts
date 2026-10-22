import { defineParams } from '@sveltejs/kit/params';

export const params = defineParams({
	// A docs page, not its markdown copy at the same path plus .md.
	page: (param) => (param.endsWith('.md') ? undefined : param),
});
