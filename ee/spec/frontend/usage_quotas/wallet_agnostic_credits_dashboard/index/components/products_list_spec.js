import { GlTable } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProductsList from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index/components/products_list.vue';
import { mockSubscriptionCreditsUsageData } from '../../mock_data';

describe('ProductsList', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mockProducts = mockSubscriptionCreditsUsageData.data.subscriptionUsage.products;
  const mockTotalUsedCredits = mockSubscriptionCreditsUsageData.data.subscriptionUsage.creditsUsed;

  const createComponent = ({
    propsData: { products = mockProducts, totalUsedCredits = mockTotalUsedCredits } = {},
    mountFn = shallowMountExtended,
  } = {}) => {
    wrapper = mountFn(ProductsList, {
      propsData: { products, totalUsedCredits },
    });
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findRows = () => findTable().find('tbody').findAll('tr');
  const findCell = (rowIndex, cellIndex) => findRows().at(rowIndex).findAll('td').at(cellIndex);

  describe('table rendering', () => {
    beforeEach(() => {
      createComponent({ mountFn: mountExtended });
    });

    it('renders the table', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('renders a row for each product', () => {
      expect(findRows()).toHaveLength(mockProducts.length);
    });

    it('renders the product title in the first column', () => {
      expect(findCell(0, 0).text()).toBe('Hosted Runners');
    });

    it('renders the share percentage in the second column', () => {
      // 3200 / 13800 * 100 = ~23%
      expect(findCell(0, 1).text()).toBe('23%');
    });

    it('renders 0% share when totalUsedCredits is 0', () => {
      createComponent({
        propsData: {
          totalUsedCredits: 0,
        },
        mountFn: mountExtended,
      });
      expect(findCell(0, 1).text()).toBe('0%');
    });

    it('renders the credits used in the third column', () => {
      expect(findCell(0, 2).text()).toBe('3.2k');
    });
  });

  describe('empty state', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          products: [],
        },
        mountFn: mountExtended,
      });
    });

    it('renders the empty state message', () => {
      expect(findTable().text()).toContain('No product data available');
    });
  });
});
