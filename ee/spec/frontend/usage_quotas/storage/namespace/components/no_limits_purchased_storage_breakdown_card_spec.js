import { GlSkeletonLoader } from '@gitlab/ui';
import NoLimitsPurchasedStorageBreakdownCard from 'ee/usage_quotas/storage/namespace/components/no_limits_purchased_storage_breakdown_card.vue';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('NoLimitsPurchasedStorageBreakdownCard', () => {
  /** @type { import('helpers/vue_test_utils_helper').ExtendedWrapper } */
  let wrapper;

  const defaultProps = {
    purchasedStorage: 256,
    loading: false,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(NoLimitsPurchasedStorageBreakdownCard, {
      propsData: { ...defaultProps, ...props },
      stubs: {
        NumberToHumanSize,
      },
    });
  };

  const findPurchacedStorage = () => wrapper.findByTestId('storage-purchased');
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);

  it('renders the purchaced storage value', () => {
    createComponent();
    expect(findPurchacedStorage().text()).toContain(
      numberToHumanSize(defaultProps.purchasedStorage, 1),
    );
  });

  describe('skeleton loader', () => {
    it('renders skeleton loader when loading prop is true', () => {
      createComponent({ props: { loading: true } });
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('does not render skeleton loader when loading prop is false', () => {
      createComponent({ props: { loading: false } });
      expect(findSkeletonLoader().exists()).toBe(false);
    });
  });
});
