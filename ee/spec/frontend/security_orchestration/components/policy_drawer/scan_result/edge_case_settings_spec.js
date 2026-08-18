import { shallowMount } from '@vue/test-utils';
import {
  UNBLOCK_RULES_KEY,
  UNBLOCK_RULES_TEXT,
  TIME_WINDOW_KEY,
  TIME_WINDOW_TEXT,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import EdgeCaseSettings from 'ee/security_orchestration/components/policy_drawer/scan_result/edge_case_settings.vue';

describe('EdgeCaseSettings', () => {
  let wrapper;

  const createComponent = (settings = {}) => {
    wrapper = shallowMount(EdgeCaseSettings, {
      propsData: { settings },
    });
  };

  it('renders when settings has at least one true value', () => {
    createComponent({ [UNBLOCK_RULES_KEY]: true });
    expect(wrapper.find('div').exists()).toBe(true);
    expect(wrapper.find('h5').text()).toBe('Edge case settings');
  });

  it('renders correct number of paragraphs based on settings keys', () => {
    createComponent({ [UNBLOCK_RULES_KEY]: true, customKey: true });

    const paragraphs = wrapper.findAll('p');
    expect(paragraphs).toHaveLength(2);
    expect(paragraphs.at(0).text()).toBe(UNBLOCK_RULES_TEXT);
    expect(paragraphs.at(1).text()).toBe('customKey');
  });

  describe('time window formatting', () => {
    it('formats time window in minutes', () => {
      createComponent({ [TIME_WINDOW_KEY]: 60 });
      const paragraphs = wrapper.findAll('p');
      expect(paragraphs.at(0).text()).toContain(`${TIME_WINDOW_TEXT}: 60 minutes`);
    });

    it('ignores non-integer time window values', () => {
      createComponent({ [TIME_WINDOW_KEY]: 'invalid', [UNBLOCK_RULES_KEY]: true });
      const paragraphs = wrapper.findAll('p');
      expect(paragraphs).toHaveLength(1);
      expect(paragraphs.at(0).text()).toBe(UNBLOCK_RULES_TEXT);
    });

    it('ignores null time window values', () => {
      createComponent({ [TIME_WINDOW_KEY]: null, [UNBLOCK_RULES_KEY]: true });
      const paragraphs = wrapper.findAll('p');
      expect(paragraphs).toHaveLength(1);
      expect(paragraphs.at(0).text()).toBe(UNBLOCK_RULES_TEXT);
    });

    it('ignores undefined time window values', () => {
      createComponent({ [TIME_WINDOW_KEY]: undefined, [UNBLOCK_RULES_KEY]: true });
      const paragraphs = wrapper.findAll('p');
      expect(paragraphs).toHaveLength(1);
      expect(paragraphs.at(0).text()).toBe(UNBLOCK_RULES_TEXT);
    });

    it('ignores float time window values', () => {
      createComponent({ [TIME_WINDOW_KEY]: 60.5, [UNBLOCK_RULES_KEY]: true });
      const paragraphs = wrapper.findAll('p');
      expect(paragraphs).toHaveLength(1);
      expect(paragraphs.at(0).text()).toBe(UNBLOCK_RULES_TEXT);
    });
  });
});
