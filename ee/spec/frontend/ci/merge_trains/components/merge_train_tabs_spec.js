import { GlBadge, GlTab, GlTabs } from '@gitlab/ui';
import { formatNumber } from '~/locale';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MergeTrainTabs from 'ee/ci/merge_trains/components/merge_train_tabs.vue';

describe('MergeTrainTabs', () => {
  let wrapper;

  const defaultProps = {
    activeTrain: {
      cars: {
        count: 59494,
      },
    },
    mergedTrain: {
      cars: {
        count: 94849,
      },
    },
  };

  const createComponent = (mountFn = mountExtended, props = defaultProps) => {
    wrapper = mountFn(MergeTrainTabs, {
      propsData: {
        ...props,
      },
      stubs: {
        GlTab,
        GlBadge,
      },
    });
  };

  const findTabs = () => wrapper.findComponent(GlTabs);
  const findActiveCarsTab = () => wrapper.findComponentByTestId('active-cars-tab');
  const findMergedCarsTab = () => wrapper.findByTestId('merged-cars-tab');

  it('displays tabs', () => {
    createComponent();

    expect(findTabs().exists()).toBe(true);
  });

  it('displays active tab text and formatted count', () => {
    createComponent(shallowMountExtended);

    expect(findActiveCarsTab().text()).toContain('Active');
    expect(findActiveCarsTab().text()).toContain(
      `${formatNumber(defaultProps.activeTrain.cars.count)}`,
    );
  });

  it('displays merged tab text and formatted count', () => {
    createComponent(shallowMountExtended);

    expect(findMergedCarsTab().text()).toContain('Merged');
    expect(findMergedCarsTab().text()).toContain(
      `${formatNumber(defaultProps.mergedTrain.cars.count)}`,
    );
  });

  it('emits the active-tab event', () => {
    createComponent();

    findActiveCarsTab().vm.$emit('click');

    expect(wrapper.emitted('active-tab')).toEqual([[0]]);
  });

  it('passes the `sync-active-tab-with-query-params` prop', () => {
    createComponent();

    expect(findTabs().props('syncActiveTabWithQueryParams')).toBe(true);
  });
});
