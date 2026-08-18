import Vue from 'vue';
import VueApollo from 'vue-apollo';

import createMockApollo from 'helpers/mock_apollo_helper';

import MilestoneItemComponent from 'ee/roadmap/components/milestone_item.vue';
import { DATE_RANGES, PRESET_TYPES } from 'ee/roadmap/constants';
import { getTimeframeForRangeType } from 'ee/roadmap/utils/roadmap_utils';
import { mockTimeframeInitialDate, mockMilestone2 } from 'ee_jest/roadmap/mock_data';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { setLocalSettingsInCache } from '../local_cache_helpers';

Vue.use(VueApollo);

const mockTimeframeMonths = getTimeframeForRangeType({
  timeframeRangeType: DATE_RANGES.THREE_YEARS,
  presetType: PRESET_TYPES.MONTHS,
  initialDate: mockTimeframeInitialDate,
});

const apolloProvider = createMockApollo();
setLocalSettingsInCache(apolloProvider, {
  presetType: PRESET_TYPES.MONTHS,
  timeframe: mockTimeframeMonths,
});

describe('MilestoneItemComponent', () => {
  let wrapper;

  const findMilestoneItemWrapper = () => wrapper.findByTestId('milestone-item-wrapper');

  const createComponent = ({ milestone = mockMilestone2 } = {}) => {
    wrapper = shallowMountExtended(MilestoneItemComponent, {
      propsData: {
        milestone,
        timeframeItem: mockTimeframeMonths[16], // timeframe item where milestone begins,
      },
      apolloProvider,
    });
  };

  it('does not render milestone wrapper if there is no start date for current preset', () => {
    createComponent({ milestone: { ...mockMilestone2, startDate: new Date(2020, 1, 1) } });

    expect(findMilestoneItemWrapper().exists()).toBe(false);
  });

  describe('when there is valid start date', () => {
    it('adds `start-date-undefined` class to milestone wrapper if start date is undefined', () => {
      createComponent({ milestone: { ...mockMilestone2, startDateUndefined: true } });

      expect(findMilestoneItemWrapper().classes('start-date-undefined')).toBe(true);
    });

    it('adds `end-date-undefined` class to milestone wrapper if end date is undefined', () => {
      createComponent({ milestone: { ...mockMilestone2, endDateUndefined: true } });

      expect(findMilestoneItemWrapper().classes('end-date-undefined')).toBe(true);
    });
  });
});
