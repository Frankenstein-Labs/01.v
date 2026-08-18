import { GlAccordion, GlAccordionItem, GlAlert } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import ExplorerQueryPanel from 'ee/orbit/components/explorer_query_panel.vue';

describe('ExplorerQueryPanel', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(ExplorerQueryPanel, {
      propsData: {
        queryText: '{}',
        templateItems: [],
        ...props,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findErrorDetails = () => wrapper.find('[data-testid="query-error-details"]');

  describe('error alert', () => {
    it('is hidden when errorMessage is null', () => {
      createWrapper();

      expect(findAlert().exists()).toBe(false);
    });

    it('renders the message when errorMessage is set', () => {
      createWrapper({ errorMessage: 'Invalid query.' });

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toContain('Invalid query.');
    });

    it('emits dismiss-error when the alert is dismissed', () => {
      createWrapper({ errorMessage: 'Invalid query.' });

      findAlert().vm.$emit('dismiss');

      expect(wrapper.emitted('dismiss-error')).toEqual([[]]);
    });
  });

  describe('error details accordion', () => {
    it('is absent when errorDetails is null', () => {
      createWrapper({ errorMessage: 'Invalid query.' });

      expect(findAccordion().exists()).toBe(false);
    });

    it('renders the accordion and the raw details when errorDetails is set', () => {
      createWrapper({
        errorMessage: 'Invalid query.',
        errorDetails: 'schema violation: "blah" is not one of "traversal", "aggregation"',
      });

      expect(findAccordion().exists()).toBe(true);
      expect(findAccordionItem().props('title')).toBe('Show error details');
      expect(findAccordionItem().props('titleVisible')).toBe('Hide error details');
      expect(findErrorDetails().text()).toContain('schema violation');
    });

    it('remounts the accordion when errorMessage changes so it starts collapsed', async () => {
      createWrapper({
        errorMessage: 'First error',
        errorDetails: 'first details',
      });
      const firstAccordion = findAccordion().element;

      await wrapper.setProps({ errorMessage: 'Second error', errorDetails: 'second details' });

      expect(findAccordion().element).not.toBe(firstAccordion);
    });
  });
});
