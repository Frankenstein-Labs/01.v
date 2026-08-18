import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import DaysHeaderSubItem from 'ee/oncall_schedules/components/schedule/components/preset_days/days_header_sub_item.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { HOURS_IN_DAY } from 'ee/oncall_schedules/constants';

Vue.use(VueApollo);

describe('ee/oncall_schedules/components/schedule/components/preset_days/days_header_sub_item.vue', () => {
  let wrapper;
  const mockTimeframeItem = new Date(2021, 0, 13);

  function mountComponent({ timeframeItem }) {
    wrapper = extendedWrapper(
      shallowMount(DaysHeaderSubItem, {
        propsData: {
          timeframeItem,
        },
        apolloProvider: createMockApollo(),
      }),
    );
  }

  beforeEach(() => {
    mountComponent({ timeframeItem: mockTimeframeItem });
  });

  const findDaysHeaderCurrentIndicator = () =>
    wrapper.findByTestId('day-item-sublabel-current-indicator');

  const findSublabels = () => wrapper.findAllByTestId('sublabel-value');

  describe('template', () => {
    it('renders component container element with class `item-sublabel`', () => {
      expect(wrapper.classes('item-sublabel')).toBe(true);
    });

    it('renders sub item elements for all items in HOURS_IN_DAY', () => {
      expect(findSublabels()).toHaveLength(HOURS_IN_DAY);
    });

    it('renders time indicator and bolded dark label when the hour matches current time', () => {
      const currentDate = new Date();
      mountComponent({ timeframeItem: currentDate });

      const hourSublabel = findSublabels().at(currentDate.getHours());

      expect(hourSublabel.classes('!gl-text-default')).toBe(true);
      expect(hourSublabel.classes('gl-font-bold')).toBe(true);

      expect(findDaysHeaderCurrentIndicator().exists()).toBe(true);
    });
  });
});
