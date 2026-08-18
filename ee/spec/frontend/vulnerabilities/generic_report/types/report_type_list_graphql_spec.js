import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import List from 'ee/vulnerabilities/components/generic_report/types/report_type_list_graphql.vue';

const TEST_DATA = {
  items: [
    { type: 'VulnerabilityDetailsUrl', href: 'https://foo.bar' },
    { type: 'VulnerabilityDetailsUrl', href: 'https://bar.baz' },
  ],
  listItem: { type: 'VulnerabilityDetailList', items: [] },
};

describe('ee/vulnerabilities/components/generic_report/types/report_type_list_graphql.vue', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createWrapper = (options = {}) => {
    wrapper = shallowMountExtended(List, {
      propsData: {
        items: TEST_DATA.items,
      },
      // manual stubbing is needed because the component is dynamically imported
      stubs: {
        ReportItem: true,
      },
      ...options,
    });
  };

  const findList = () => wrapper.findByTestId('generic-report-type-list');
  const findListItems = () => wrapper.findAllByTestId('generic-report-type-list-item');
  const findReportItems = () => wrapper.findAllByTestId('report-item');

  describe('list rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders a list', () => {
      expect(findList().exists()).toBe(true);
    });

    it('renders a report-item for each item', () => {
      expect(findReportItems()).toHaveLength(TEST_DATA.items.length);
    });
  });

  describe('list nesting', () => {
    describe('without a nested list', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('applies the correct classes to the list', () => {
        expect(findList().classes().includes('generic-report-list-nested')).toBe(false);
      });
    });

    describe('with a nested list', () => {
      const items = [...TEST_DATA.items, TEST_DATA.listItem];
      const itemWithNestedListIndex = items.length - 1;

      beforeEach(() => {
        createWrapper({
          propsData: {
            items,
          },
        });
      });

      it('applies the correct classes to the list', () => {
        expect(findList().classes().includes('generic-report-list-nested')).toBe(true);
      });

      it('applies the correct classes to the list items', () => {
        const itemWithNestedList = findListItems().at(itemWithNestedListIndex);
        expect(itemWithNestedList.classes().includes('!gl-list-none')).toBe(true);
      });
    });
  });
});
