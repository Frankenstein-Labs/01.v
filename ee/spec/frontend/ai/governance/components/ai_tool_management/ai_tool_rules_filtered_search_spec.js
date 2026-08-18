import { GlFilteredSearch } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiToolRulesFilteredSearch from 'ee/ai/governance/components/ai_tool_management/ai_tool_rules_filtered_search.vue';
import { TOKEN_TYPE_ACTION } from 'ee/ai/governance/constants';

describe('AiToolRulesFilteredSearch', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(AiToolRulesFilteredSearch);
  };

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findActionToken = () =>
    findFilteredSearch()
      .props('availableTokens')
      .find((token) => token.type === TOKEN_TYPE_ACTION);
  const submit = (terms) => findFilteredSearch().vm.$emit('submit', terms);
  const clear = () => findFilteredSearch().vm.$emit('clear');

  beforeEach(() => {
    createComponent();
  });

  it('renders GlFilteredSearch with a testid wrapper', () => {
    expect(wrapper.findByTestId('ai-tool-rules-filtered-search').exists()).toBe(true);
    expect(findFilteredSearch().exists()).toBe(true);
  });

  describe('action token', () => {
    it('exposes a single-use action token with READ/WRITE/DESTROY options', () => {
      const token = findActionToken();

      expect(token).toBeDefined();
      expect(token.unique).toBe(true);
      expect(token.options.map((o) => o.value)).toEqual(['READ', 'WRITE', 'DESTROY']);
    });
  });

  describe('on submit', () => {
    it('emits free-text search only', () => {
      submit(['issues']);

      expect(wrapper.emitted('filter')).toEqual([[{ search: 'issues', actionType: null }]]);
    });

    it.each(['READ', 'WRITE', 'DESTROY'])('emits actionType %s from the action token', (action) => {
      submit([{ type: TOKEN_TYPE_ACTION, value: { operator: '=', data: action } }]);

      expect(wrapper.emitted('filter')).toEqual([[{ search: null, actionType: action }]]);
    });

    it('emits both search and actionType together', () => {
      submit(['pipeline', { type: TOKEN_TYPE_ACTION, value: { operator: '=', data: 'WRITE' } }]);

      expect(wrapper.emitted('filter')).toEqual([[{ search: 'pipeline', actionType: 'WRITE' }]]);
    });

    it('trims whitespace-only free text to null search', () => {
      submit(['   ']);

      expect(wrapper.emitted('filter')).toEqual([[{ search: null, actionType: null }]]);
    });

    it('merges multiple free-text string entries defensively', () => {
      submit(['pipeline', 'rules']);

      expect(wrapper.emitted('filter')).toEqual([[{ search: 'pipeline rules', actionType: null }]]);
    });

    it('emits null search when cleared', () => {
      submit([]);

      expect(wrapper.emitted('filter')).toEqual([[{ search: null, actionType: null }]]);
    });
  });

  describe('on clear', () => {
    it('resets the filter when the clear button is used', () => {
      clear();

      expect(wrapper.emitted('filter')).toEqual([[{ search: null, actionType: null }]]);
    });
  });
});
