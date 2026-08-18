import Vue from 'vue';
import VueApollo from 'vue-apollo';

import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';

import RoadmapShell from 'ee/roadmap/components/roadmap_shell.vue';
import MilestonesListSection from 'ee/roadmap/components/milestones_list_section.vue';
import { DATE_RANGES, PRESET_TYPES } from 'ee/roadmap/constants';
import eventHub from 'ee/roadmap/event_hub';
import { getTimeframeForRangeType } from 'ee/roadmap/utils/roadmap_utils';

import groupMilestonesQuery from 'ee/roadmap/queries/group_milestones.query.graphql';

import {
  mockEpic,
  mockTimeframeInitialDate,
  mockGroupMilestonesQueryResponse,
  mockGroupMilestonesQueryResponseWithInvalidDates,
} from 'ee_jest/roadmap/mock_data';
import { setLocalSettingsInCache } from '../local_cache_helpers';

jest.mock('~/alert');

Vue.use(VueApollo);

const mockTimeframeMonths = getTimeframeForRangeType({
  timeframeRangeType: DATE_RANGES.CURRENT_YEAR,
  presetType: PRESET_TYPES.MONTHS,
  initialDate: mockTimeframeInitialDate,
});

const groupMilestonesQueryHandler = jest.fn().mockResolvedValue(mockGroupMilestonesQueryResponse);

describe('RoadmapShell', () => {
  let wrapper;
  let apolloProvider;

  const findRoadmapShellWrapper = () => wrapper.findByTestId('roadmap-shell');
  const findMilestonesListSection = () => wrapper.findComponent(MilestonesListSection);

  const createComponent = ({
    epics = [mockEpic],
    timeframe = mockTimeframeMonths,
    isShowingMilestones = false,
  } = {}) => {
    apolloProvider = createMockApollo([[groupMilestonesQuery, groupMilestonesQueryHandler]]);
    setLocalSettingsInCache(apolloProvider, {
      timeframeRangeType: DATE_RANGES.CURRENT_YEAR,
      presetType: PRESET_TYPES.MONTHS,
      timeframe,
      isShowingMilestones,
    });

    wrapper = shallowMountExtended(RoadmapShell, {
      attachTo: document.body,
      propsData: {
        epics,
        epicsFetchNextPageInProgress: false,
        hasNextPage: false,
      },
      provide: {
        fullPath: 'gitlab-org',
        epicIid: null,
      },
      apolloProvider,
    });
  };

  it('sets container styles on component mount', async () => {
    createComponent();
    await waitForPromises();

    expect(findRoadmapShellWrapper().attributes('style')).toBe('height: calc(100vh - 0px);');
  });

  it('emits `epicListScrolled` event via event hub on scroll', () => {
    jest.spyOn(eventHub, '$emit').mockImplementation();

    createComponent();
    findRoadmapShellWrapper().trigger('scroll');

    expect(eventHub.$emit).toHaveBeenCalledWith('epicsListScrolled', {
      clientHeight: 0,
      scrollHeight: 0,
      scrollLeft: 0,
      scrollTop: 0,
    });
  });

  it('does not call milestones query if milestones are not shown', () => {
    createComponent();

    expect(groupMilestonesQueryHandler).not.toHaveBeenCalled();
  });

  describe('when milestones are shown', () => {
    it('calls the groupMilestonesQuery with the correct timeframe', async () => {
      createComponent({ isShowingMilestones: true });
      await waitForPromises();

      expect(groupMilestonesQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          timeframe: {
            end: '2018-12-31',
            start: '2018-01-01',
          },
        }),
      );
    });

    describe('when milestones query is successful', () => {
      it('renders the MilestonesListSection component', async () => {
        createComponent({ isShowingMilestones: true });
        await waitForPromises();

        expect(findMilestonesListSection().exists()).toBe(true);
      });

      it('passes the correct number of milestones to the MilestonesListSection component', async () => {
        createComponent({ isShowingMilestones: true });
        await waitForPromises();

        expect(findMilestonesListSection().props('milestones')).toHaveLength(2);
      });

      it('filters away a milestone with invalid dates', async () => {
        groupMilestonesQueryHandler.mockResolvedValue(
          mockGroupMilestonesQueryResponseWithInvalidDates,
        );

        createComponent({ isShowingMilestones: true });
        await waitForPromises();

        expect(findMilestonesListSection().props('milestones')).toHaveLength(1);
      });
    });

    describe('when milestones query is unsuccessful', () => {
      beforeEach(async () => {
        groupMilestonesQueryHandler.mockRejectedValue('Houston, we have a problem');

        createComponent({ isShowingMilestones: true });
        await waitForPromises();
      });

      it('does not render the MilestonesListSection component', () => {
        expect(findMilestonesListSection().exists()).toBe(false);
      });

      it('creates an alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Something went wrong while fetching milestones',
        });
      });
    });
  });
});
