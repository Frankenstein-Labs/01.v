import TANUKI_AI_SVG_URL from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TanukiAiIcon from 'ee/ai/shared/widgets/tanuki_ai_icon.vue';

describe('TanukiAiIcon', () => {
  it('renders the Tanuki AI icon with the svg url and alt text', () => {
    const wrapper = shallowMountExtended(TanukiAiIcon);

    expect(wrapper.element.tagName).toBe('IMG');
    expect(wrapper.element.src).toBe(TANUKI_AI_SVG_URL);
    expect(wrapper.attributes('alt')).toBe('GitLab Duo AI assistant');
    expect(wrapper.classes()).toEqual(expect.arrayContaining(['gl-h-10', 'gl-w-10']));
  });
});
