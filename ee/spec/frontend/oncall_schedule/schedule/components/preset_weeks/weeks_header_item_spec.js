import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import WeeksHeaderItemComponent from 'ee/oncall_schedules/components/schedule/components/preset_weeks/weeks_header_item.vue';
import { getTimeframeForWeeksView } from 'ee/oncall_schedules/components/schedule/utils';
import { useFakeDate } from 'helpers/fake_date';

describe('WeeksHeaderItemComponent', () => {
  let wrapper;
  // January 3rd, 2018 - current date (faked)
  useFakeDate(2018, 0, 3);
  const mockTimeframeIndex = 0;
  const mockTimeframeInitialDate = new Date(2018, 0, 1);
  const mockTimeframeWeeks = getTimeframeForWeeksView(mockTimeframeInitialDate);

  function mountComponent({ timeframeItem = mockTimeframeWeeks[mockTimeframeIndex] } = {}) {
    wrapper = shallowMountExtended(WeeksHeaderItemComponent, {
      propsData: {
        timeframeItem,
      },
    });
  }

  beforeEach(() => {
    mountComponent();
  });

  const findHeaderLabel = () => wrapper.findByTestId('timeline-header-label');

  describe('timelineHeaderLabel', () => {
    it('returns string containing Month item in the timeframe', () => {
      expect(findHeaderLabel().text()).toBe('Jan');
    });
  });
});
