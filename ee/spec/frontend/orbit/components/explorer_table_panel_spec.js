import { shallowMount } from '@vue/test-utils';
import ExplorerTablePanel from 'ee/orbit/components/explorer_table_panel.vue';
import QueryResultsTable from 'ee/orbit/components/query_results_table.vue';

jest.mock('ee/orbit/utils/csv_export', () => ({
  downloadCsv: jest.fn(),
}));

describe('ExplorerTablePanel', () => {
  let wrapper;

  const mockRows = [{ type: 'User', id: 1, username: 'admin' }];

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(ExplorerTablePanel, {
      propsData: {
        rows: [],
        ...props,
      },
    });
  };

  describe('with no rows', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows empty state message', () => {
      expect(wrapper.find('[data-testid="table-empty-state"]').exists()).toBe(true);
    });
  });

  describe('with rows', () => {
    beforeEach(() => {
      createWrapper({ rows: mockRows });
    });

    it('shows results header', () => {
      expect(wrapper.find('[data-testid="table-results-header"]').exists()).toBe(true);
    });

    it('shows the result count in the header', () => {
      expect(wrapper.find('[data-testid="table-results-header"]').text()).toContain('1');
    });

    it('renders query results table', () => {
      expect(wrapper.findComponent(QueryResultsTable).exists()).toBe(true);
    });

    it('shows download CSV button', () => {
      expect(wrapper.find('[data-testid="download-csv-btn"]').exists()).toBe(true);
    });
  });

  describe('row click', () => {
    beforeEach(() => {
      createWrapper({ rows: mockRows });
    });

    it('emits row-click from results table', () => {
      const row = { type: 'User', id: 1 };
      wrapper.findComponent(QueryResultsTable).vm.$emit('row-click', row);

      expect(wrapper.emitted('row-click')[0]).toEqual([row]);
    });
  });
});
