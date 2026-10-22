import { navSections } from '#lib/content.server.ts';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = () => ({ sections: navSections() });
