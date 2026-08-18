import { GlCollapsibleListbox } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProductsDropdownFilter from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index/components/products_dropdown_filter.vue';

describe('ProductsDropdownFilter', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mockProducts = [
    {
      text: 'GitLab Duo Agent Platform',
      options: [
        { value: 'agentic_chat', text: 'Agentic Chat' },
        { value: 'code_suggestions', text: 'Code Suggestions' },
      ],
    },
    {
      text: 'Other Product',
      options: [{ value: 'storage', text: 'Storage' }],
    },
  ];

  const allValues = ['agentic_chat', 'code_suggestions', 'storage'];

  const createComponent = ({
    propsData: { products = mockProducts, loading = false, ...props } = {},
  } = {}) => {
    wrapper = shallowMountExtended(ProductsDropdownFilter, {
      propsData: { products, loading, ...props },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  beforeEach(() => {
    createComponent();
  });

  describe('rendering', () => {
    it('passes products to the listbox as items', () => {
      expect(findListbox().props('items')).toEqual(mockProducts);
    });

    it('renders the listbox as multi-select with fluid width', () => {
      expect(findListbox().props('multiple')).toBe(true);
      expect(findListbox().props('fluidWidth')).toBe(true);
    });

    it('renders the listbox with the expected labels', () => {
      expect(findListbox().props()).toMatchObject({
        headerText: 'Filter by product',
        resetButtonLabel: 'Clear',
        showSelectAllButtonLabel: 'Select all',
      });
    });
  });

  describe('loading state', () => {
    it('sets loading prop on GlCollapsibleListbox', () => {
      createComponent({ propsData: { loading: true } });
      expect(findListbox().props('loading')).toBe(true);
    });
  });

  describe('toggle text', () => {
    it('renders "Select products" when nothing is selected', () => {
      expect(findListbox().props('toggleText')).toBe('Select products');
    });

    it('renders the count of selected products when items are selected', async () => {
      findListbox().vm.$emit('select', ['agentic_chat', 'storage']);
      await nextTick();

      expect(findListbox().props('toggleText')).toBe('2 selected');
    });
  });

  describe('events', () => {
    it('emits select when the selection changes', async () => {
      findListbox().vm.$emit('select', ['agentic_chat']);
      findListbox().vm.$emit('blur');
      await nextTick();

      expect(wrapper.emitted('select')).toEqual([[['agentic_chat']]]);
    });

    it('selects all flow types across groups and emits on select-all', async () => {
      findListbox().vm.$emit('select-all');
      findListbox().vm.$emit('blur');
      await nextTick();

      expect(wrapper.emitted('select')).toEqual([[allValues]]);
      expect(findListbox().props('toggleText')).toBe('3 selected');
    });

    it('clears the selection and emits on reset', async () => {
      // make sure we have selections before resetting
      findListbox().vm.$emit('select', ['agentic_chat']);
      findListbox().vm.$emit('blur');
      await nextTick();

      expect(wrapper.emitted('select')).toEqual([[['agentic_chat']]]);

      // reset the selections
      findListbox().vm.$emit('reset');
      findListbox().vm.$emit('blur');
      await nextTick();

      expect(wrapper.emitted('select')).toEqual([[['agentic_chat']], [[]]]);
      expect(findListbox().props('toggleText')).toBe('Select products');
    });
  });
});
