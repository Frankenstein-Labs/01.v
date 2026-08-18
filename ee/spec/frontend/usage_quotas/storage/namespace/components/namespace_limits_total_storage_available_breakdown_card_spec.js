import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NamespaceLimitsTotalStorageAvailableBreakdownCard from 'ee/usage_quotas/storage/namespace/components/namespace_limits_total_storage_available_breakdown_card.vue';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import { namespace } from 'jest/usage_quotas/storage/mock_data';
import { defaultNamespaceProvideValues } from '../../mock_data';

describe('NamespaceLimitsTotalStorageAvailableBreakdownCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(NamespaceLimitsTotalStorageAvailableBreakdownCard, {
      propsData: {
        purchasedStorage: namespace.additionalPurchasedStorageSize,
        loading: false,
        ...props,
      },
      provide: {
        ...defaultNamespaceProvideValues,
        ...provide,
      },
      stubs: {
        NumberToHumanSize,
      },
    });
  };

  const findStorageIncludedInPlan = () => wrapper.findByTestId('storage-included-in-plan');
  const findStoragePurchased = () => wrapper.findByTestId('storage-purchased');
  const findTotalStorage = () => wrapper.findByTestId('total-storage');
  const findSkeletonLoaders = () => wrapper.findAll('.gl-animate-skeleton-loader');

  beforeEach(() => {
    createComponent();
  });

  it('renders storage included in the plan', () => {
    expect(findStorageIncludedInPlan().text()).toContain('5.0 GiB');
  });

  it('renders plan storage description', () => {
    expect(wrapper.text()).toContain('Included in Free subscription');
  });

  it('renders purchased storage', () => {
    expect(findStoragePurchased().text()).toContain('10.0 GiB');
  });

  it('renders total storage', () => {
    expect(findTotalStorage().text()).toContain('5.0 GiB');
  });

  describe('skeleton loader', () => {
    it('renders skeleton loader when loading prop is true', () => {
      createComponent({ props: { loading: true } });
      expect(findSkeletonLoaders().exists()).toBe(true);
    });

    it('does not render skeleton loader when loading prop is false', () => {
      createComponent({ props: { loading: false } });
      expect(findSkeletonLoaders().exists()).toBe(false);
    });
  });
});
