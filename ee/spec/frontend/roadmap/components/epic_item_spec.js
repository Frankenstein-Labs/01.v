import Vue from 'vue';
import VueApollo from 'vue-apollo';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { createAlert } from '~/alert';

import CurrentDayIndicator from 'ee/roadmap/components/current_day_indicator.vue';
import EpicItemComponent from 'ee/roadmap/components/epic_item.vue';
import EpicItemContainer from 'ee/roadmap/components/epic_item_container.vue';
import EpicItemDetails from 'ee/roadmap/components/epic_item_details.vue';
import EpicItemTimeline from 'ee/roadmap/components/epic_item_timeline.vue';

import epicChildEpicsQuery from 'ee/roadmap/queries/epic_child_epics.query.graphql';

import { DATE_RANGES, PRESET_TYPES } from 'ee/roadmap/constants';
import { getTimeframeForRangeType } from 'ee/roadmap/utils/roadmap_utils';

import { mockEpic, mockGroupId, mockEpicChildEpicsQueryResponse } from 'ee_jest/roadmap/mock_data';
import { setLocalSettingsInCache } from '../local_cache_helpers';

Vue.use(VueApollo);

jest.mock('~/alert');

const mockTimeframeMonths = getTimeframeForRangeType({
  timeframeRangeType: DATE_RANGES.CURRENT_YEAR,
  presetType: PRESET_TYPES.MONTHS,
  initialDate: new Date(2017, 0, 1),
});

const childEpicsQueryHandler = jest.fn().mockResolvedValue(mockEpicChildEpicsQueryResponse);

describe('EpicItemComponent', () => {
  let wrapper;

  const findTimelineCells = () => wrapper.findAllByTestId('epic-timeline-cell');
  const findEpicItemContainer = () => wrapper.findComponent(EpicItemContainer);
  const findEpicItemDetails = () => wrapper.findComponent(EpicItemDetails);
  const findEpicItemTimeline = () => wrapper.findComponent(EpicItemTimeline);

  const createComponent = ({
    epic = mockEpic,
    timeframe = mockTimeframeMonths,
    filterParams = {},
  } = {}) => {
    const apolloProvider = createMockApollo([[epicChildEpicsQuery, childEpicsQueryHandler]]);
    setLocalSettingsInCache(apolloProvider, {
      timeframeRangeType: DATE_RANGES.CURRENT_YEAR,
      presetType: PRESET_TYPES.MONTHS,
      filterParams,
      timeframe,
    });

    wrapper = shallowMountExtended(EpicItemComponent, {
      apolloProvider,
      propsData: {
        epic,
        childLevel: 0,
      },
      provide: {
        currentGroupId: mockGroupId,
      },
      data() {
        return {
          // Arbitrarily set the current date to be in timeframe[1] (2017-12-01)
          currentDate: timeframe[1],
        };
      },
    });
  };

  describe('start date', () => {
    it('returns Epic.startDate when start date is within range', () => {
      createComponent();

      expect(findEpicItemTimeline().props('startDate')).toBe(mockEpic.startDate);
    });

    it('returns Epic.originalStartDate when start date is out of range', () => {
      const mockStartDate = new Date(2018, 0, 1);
      const epic = { ...mockEpic, startDateOutOfRange: true, originalStartDate: mockStartDate };
      createComponent({ epic });

      expect(findEpicItemTimeline().props('startDate')).toBe(mockStartDate);
    });
  });

  describe('end date', () => {
    it('returns Epic.endDate when end date is within range', () => {
      createComponent();

      expect(findEpicItemTimeline().props('endDate')).toBe(mockEpic.endDate);
    });

    it('returns Epic.originalEndDate when end date is out of range', () => {
      const mockEndDate = new Date(2018, 0, 1);
      const epic = { ...mockEpic, endDateOutOfRange: true, originalEndDate: mockEndDate };
      createComponent({ epic });

      expect(findEpicItemTimeline().props('endDate')).toBe(mockEndDate);
    });
  });

  describe('timeframeString', () => {
    it('returns timeframe string correctly when both start and end dates are defined', () => {
      createComponent();

      expect(findEpicItemDetails().props('timeframeString')).toBe('Nov 10, 2017 – Jun 2, 2018');
    });

    it('returns timeframe string correctly when no dates are defined', () => {
      const epic = { ...mockEpic, endDateUndefined: true, startDateUndefined: true };
      createComponent({ epic });

      expect(findEpicItemDetails().props('timeframeString')).toBe('No start and end date');
    });

    it('returns timeframe string correctly when only start date is defined', () => {
      const epic = { ...mockEpic, endDateUndefined: true };
      createComponent({ epic });

      expect(findEpicItemDetails().props('timeframeString')).toBe('Nov 10, 2017 – No end date');
    });

    it('returns timeframe string correctly when only end date is defined', () => {
      const epic = { ...mockEpic, startDateUndefined: true };
      createComponent({ epic });

      expect(findEpicItemDetails().props('timeframeString')).toBe('No start date – Jun 2, 2018');
    });

    it('returns timeframe string with hidden year for start date when both start and end dates are from same year', () => {
      const epic = {
        ...mockEpic,
        startDate: new Date(2018, 0, 1),
        endDate: new Date(2018, 3, 1),
      };
      createComponent({ epic });

      expect(findEpicItemDetails().props('timeframeString')).toBe('Jan 1 – Apr 1, 2018');
    });
  });

  describe('timeframe', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders correct number of timeframe items', () => {
      expect(findTimelineCells()).toHaveLength(12);
    });

    it('renders current day indicator', () => {
      expect(wrapper.findComponent(CurrentDayIndicator).exists()).toBe(true);
    });
  });

  describe('when has children epics', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render EpicItemContainer component', () => {
      expect(findEpicItemContainer().exists()).toBe(false);
    });

    it('passes `isChildrenEmpty` prop as true to EpicDetails', () => {
      expect(findEpicItemDetails().props('isChildrenEmpty')).toBe(true);
    });

    it('passes `isExpanded` prop as false to EpicDetails', () => {
      expect(findEpicItemDetails().props('isExpanded')).toBe(false);
    });

    it('does not call children epics query by default', () => {
      expect(childEpicsQueryHandler).not.toHaveBeenCalled();
    });

    describe('when expanding an epic', () => {
      beforeEach(() => {
        findEpicItemDetails().vm.$emit('toggle-epic');
      });

      it('calls children epics query', async () => {
        await waitForPromises();
        expect(childEpicsQueryHandler).toHaveBeenCalledWith({
          authorUsername: '',
          fullPath: '/groups/gitlab-org/',
          iid: 1,
          labelName: [],
          search: '',
          sort: 'START_DATE_ASC',
          state: 'all',
        });
      });

      it('passes `isFetchingChildren` prop as true when query is in flight', () => {
        expect(findEpicItemDetails().props('isFetchingChildren')).toBe(true);
      });

      describe('when children epics query is successful', () => {
        it('passes `isFetchingChildren` prop as false', async () => {
          await waitForPromises();

          expect(findEpicItemDetails().props('isFetchingChildren')).toBe(false);
        });

        it('renders EpicItemContainer component with correct number of children', async () => {
          await waitForPromises();

          expect(findEpicItemContainer().exists()).toBe(true);
          expect(findEpicItemContainer().props('children')).toHaveLength(1);
        });
      });

      describe('when children epics query fails', () => {
        beforeEach(() => {
          childEpicsQueryHandler.mockRejectedValue('Houston, we have a problem');
        });

        it('passes `isFetchingChildren` prop as false', async () => {
          await waitForPromises();

          expect(findEpicItemDetails().props('isFetchingChildren')).toBe(false);
        });

        it('creates an alert', async () => {
          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith({
            message: 'Something went wrong while fetching epics',
          });
        });
      });
    });
  });
});
