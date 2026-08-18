import { GlAccordion, GlAccordionItem } from '@gitlab/ui';
import TokensException from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/tokens_exception.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('TokensException', () => {
  let wrapper;

  const defaultProvide = {
    availableAccessTokens: [],
  };

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(TokensException, {
      propsData,
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findTokenList = () => wrapper.findByTestId('token-list');
  const findTokenItems = () => wrapper.findAllByTestId('token-item');
  const findTokenListFallback = () => wrapper.findByTestId('token-list-fallback');
  const findTokenItemsFallback = () => wrapper.findAllByTestId('token-item-fallback');

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders accordion with correct header level', () => {
      expect(findAccordion().exists()).toBe(true);
      expect(findAccordion().props('headerLevel')).toBe(3);
    });

    it('renders accordion item with default title', () => {
      expect(findAccordionItem().exists()).toBe(true);
      expect(findAccordionItem().props('title')).toBe('Access tokens (0)');
    });

    it('renders empty token list', () => {
      expect(findTokenList().exists()).toBe(false);
      expect(findTokenListFallback().exists()).toBe(true);
      expect(findTokenItemsFallback()).toHaveLength(0);
    });
  });

  describe('with tokens but no available tokens', () => {
    const tokens = [{ id: '1' }, { id: '2' }, { id: '3' }];

    beforeEach(() => {
      createComponent({
        propsData: { tokens },
      });
    });

    it('renders correct title with token count', () => {
      expect(findAccordionItem().props('title')).toBe('Access tokens (3)');
    });

    it('renders token IDs when no available tokens', () => {
      expect(findTokenItemsFallback()).toHaveLength(3);
      expect(findTokenItemsFallback().at(0).text()).toBe('id: 1');
      expect(findTokenItemsFallback().at(1).text()).toBe('id: 2');
      expect(findTokenItemsFallback().at(2).text()).toBe('id: 3');
    });

    it('applies correct CSS classes to token list', () => {
      expect(findTokenListFallback().classes()).toContain('gl-list-none');
      expect(findTokenListFallback().classes()).toContain('gl-pl-4');
    });
  });

  describe('with tokens and available tokens', () => {
    const tokens = [{ id: '1' }, { id: '3' }];

    const availableAccessTokens = [
      { id: '1', name: 'Token One' },
      { id: '2', name: 'Token Two' },
      { id: '3', name: 'Token Three' },
    ];

    beforeEach(() => {
      createComponent({
        propsData: { tokens },
        provide: { availableAccessTokens },
      });
    });

    it('renders token names when available tokens exist', () => {
      expect(findTokenItems()).toHaveLength(2);
      expect(findTokenItems().at(0).text()).toBe('Token One');
      expect(findTokenItems().at(1).text()).toBe('Token Three');
    });

    it('only shows tokens that are selected', () => {
      const tokenTexts = findTokenItems().wrappers.map((item) => item.text());
      expect(tokenTexts).toEqual(['Token One', 'Token Three']);
      expect(tokenTexts).not.toContain('Token Two');
    });
  });

  describe('with single token', () => {
    const tokens = [{ id: '42' }];

    beforeEach(() => {
      createComponent({
        propsData: { tokens },
      });
    });

    it('renders correct singular title', () => {
      expect(findAccordionItem().props('title')).toBe('Access tokens (1)');
    });

    it('renders single token ID', () => {
      expect(findTokenItemsFallback()).toHaveLength(1);
      expect(findTokenItemsFallback().at(0).text()).toBe('id: 42');
    });
  });

  describe('edge cases', () => {
    it('handles undefined tokens prop', () => {
      createComponent({
        propsData: { tokens: undefined },
      });

      expect(findAccordionItem().props('title')).toBe('Access tokens (0)');
      expect(findTokenItems()).toHaveLength(0);
    });

    it('handles null availableAccessTokens', () => {
      const tokens = [{ id: '1' }];

      createComponent({
        propsData: { tokens },
        provide: { availableAccessTokens: null },
      });

      expect(findTokenItemsFallback()).toHaveLength(1);
      expect(findTokenItemsFallback().at(0).text()).toBe('id: 1');
    });

    it('handles tokens without matching available tokens', () => {
      const tokens = [{ id: '999' }];
      const availableAccessTokens = [{ id: '1', name: 'Token One' }];

      createComponent({
        propsData: { tokens },
        provide: { availableAccessTokens },
      });

      expect(findTokenItems()).toHaveLength(0);
    });
  });
});
