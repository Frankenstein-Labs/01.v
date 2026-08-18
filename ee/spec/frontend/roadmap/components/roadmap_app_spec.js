import { GlLoadingIcon } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import { createAlert } from '~/alert';

import EpicsListEmpty from 'ee/roadmap/components/epics_list_empty.vue';
import RoadmapApp from 'ee/roadmap/components/roadmap_app.vue';
import RoadmapFilters from 'ee/roadmap/components/roadmap_filters.vue';
import RoadmapShell from 'ee/roadmap/components/roadmap_shell.vue';
import { PRESET_TYPES, DATE_RANGES } from 'ee/roadmap/constants';
import { getTimeframeForRangeType } from 'ee/roadmap/utils/roadmap_utils';

import epicChildEpicsQuery from 'ee/roadmap/queries/epic_child_epics.query.graphql';
import groupEpicsWithColorQuery from 'ee/roadmap/queries/group_epics_with_color.query.graphql';

import {
  mockSvgPath,
  mockPageInfo,
  mockTimeframeInitialDate,
  mockGroupEpicsQueryResponse,
  mockEpicChildEpicsQueryResponse,
  mockGroupEpicsQueryResponseEmpty,
} from 'ee_jest/roadmap/mock_data';
import { setLocalSettingsInCache } from '../local_cache_helpers';

Vue.use(VueApollo);

jest.mock('~/alert');

const childEpicsQueryHandler = jest.fn().mockResolvedValue(mockEpicChildEpicsQueryResponse);
const groupEpicsWithColorQueryHandler = jest.fn().mockResolvedValue(mockGroupEpicsQueryResponse);

describe('RoadmapApp', () => {
  let wrapper;

  const emptyStateIllustrationPath = mockSvgPath;
  const presetType = PRESET_TYPES.MONTHS;
  const timeframeRangeType = DATE_RANGES.CURRENT_YEAR;
  const timeframe = getTimeframeForRangeType({
    timeframeRangeType: DATE_RANGES.CURRENT_YEAR,
    presetType: PRESET_TYPES.MONTHS,
    initialDate: mockTimeframeInitialDate,
  });

  const createComponent = ({ epicIid, filterParams = {} } = {}) => {
    const apolloProvider = createMockApollo([
      [epicChildEpicsQuery, childEpicsQueryHandler],
      [groupEpicsWithColorQuery, groupEpicsWithColorQueryHandler],
    ]);
    setLocalSettingsInCache(apolloProvider, {
      filterParams,
      presetType,
      timeframe,
      timeframeRangeType,
    });

    wrapper = shallowMountExtended(RoadmapApp, {
      propsData: {
        emptyStateIllustrationPath,
      },
      provide: {
        fullPath: 'gitlab-org',
        groupMilestonesPath: '/groups/gitlab-org/-/milestones.json',
        listEpicsPath: '/groups/gitlab-org/-/epics',
        epicIid,
      },
      apolloProvider,
    });
  };

  const findSettingsSidebar = () => wrapper.findByTestId('roadmap-settings');
  const findEpicsListEmpty = () => wrapper.findComponent(EpicsListEmpty);
  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findRoadmapFilters = () => wrapper.findComponent(RoadmapFilters);
  const findRoadmapShell = () => wrapper.findComponent(RoadmapShell);

  describe.each`
    testLabel         | hasEpics | hasError | showLoading | showRoadmapShell | showEpicsListEmpty | showAlert
    ${'is loading'}   | ${true}  | ${false} | ${true}     | ${false}         | ${false}           | ${false}
    ${'has epics'}    | ${true}  | ${false} | ${false}    | ${true}          | ${false}           | ${false}
    ${'has no epics'} | ${false} | ${false} | ${false}    | ${false}         | ${true}            | ${false}
    ${'has error'}    | ${true}  | ${true}  | ${false}    | ${false}         | ${true}            | ${true}
  `(
    `when epic list $testLabel`,
    ({ hasEpics, hasError, showLoading, showRoadmapShell, showEpicsListEmpty, showAlert }) => {
      beforeEach(async () => {
        if (hasError) {
          groupEpicsWithColorQueryHandler.mockRejectedValueOnce('Houston, we have a problem');
        } else if (!hasEpics) {
          groupEpicsWithColorQueryHandler.mockResolvedValueOnce(mockGroupEpicsQueryResponseEmpty);
        }
        createComponent();

        if (!showLoading) {
          await waitForPromises();
        }
      });

      it(`loading icon is${showLoading ? '' : ' not'} shown`, () => {
        expect(findGlLoadingIcon().exists()).toBe(showLoading);
      });

      it(`roadmap is${showRoadmapShell ? '' : ' not'} shown`, () => {
        expect(findRoadmapShell().exists()).toBe(showRoadmapShell);
      });

      it(`empty state view is${showEpicsListEmpty ? '' : ' not'} shown`, () => {
        expect(findEpicsListEmpty().exists()).toBe(showEpicsListEmpty);
      });

      it(`alert is${showAlert ? '' : ' not'} shown`, () => {
        expect(createAlert).toHaveBeenCalledTimes(showAlert ? 1 : 0);
      });
    },
  );

  describe('roadmap view', () => {
    it('disables search when epicIid is present', () => {
      createComponent({ epicIid: '1' });

      expect(findRoadmapFilters().exists()).toBe(true);
      expect(findRoadmapFilters().props('viewOnly')).toBe(true);
    });

    it('shows roadmap filters UI when epicIid is not present', () => {
      createComponent({ filterParams: { groupPath: 'test-group' } });

      expect(findRoadmapFilters().exists()).toBe(true);
    });

    it('shows roadmap-shell component', async () => {
      createComponent();

      await waitForPromises();

      const roadmapShell = findRoadmapShell();
      expect(roadmapShell.exists()).toBe(true);
    });

    it('renders settings sidebar', () => {
      createComponent();

      expect(findSettingsSidebar().exists()).toBe(true);
    });
  });

  it('calls group epic query with correct variables if epicIid is not present', async () => {
    createComponent();
    await waitForPromises();

    expect(groupEpicsWithColorQueryHandler).toHaveBeenCalledWith(
      expect.objectContaining({
        first: 50,
        endCursor: '',
      }),
    );

    expect(childEpicsQueryHandler).not.toHaveBeenCalled();
  });

  it('calls group epic query with correct variables from filterParams', async () => {
    const groupPath = 'test-group';
    const epicIid = '1::&Epic 1';

    createComponent({ filterParams: { groupPath, epicIid } });
    await waitForPromises();

    expect(groupEpicsWithColorQueryHandler).toHaveBeenCalledWith(
      expect.objectContaining({
        groupPath,
        iid: 'Epic 1',
      }),
    );
  });

  it('calls child epics query with correct variables when epicIid is present', async () => {
    const epicIid = '1';
    createComponent({ epicIid });
    await waitForPromises();

    expect(childEpicsQueryHandler).toHaveBeenCalledWith(
      expect.objectContaining({
        iid: epicIid,
        fullPath: 'gitlab-org',
      }),
    );

    expect(groupEpicsWithColorQueryHandler).not.toHaveBeenCalled();
  });

  it('calls group epic query with or filter parameter when provided', async () => {
    const filterParams = {
      'or[labelName]': ['bug', 'feature'],
    };

    createComponent({ filterParams });
    await waitForPromises();

    expect(groupEpicsWithColorQueryHandler).toHaveBeenCalledWith(
      expect.objectContaining({
        or: {
          labelName: ['bug', 'feature'],
        },
      }),
    );
  });

  it('calls group epic query with multiple or filter parameters when provided', async () => {
    const filterParams = {
      'or[labelName]': ['bug', 'feature'],
      'or[authorUsername]': ['user1', 'user2'],
    };

    createComponent({ filterParams });
    await waitForPromises();

    expect(groupEpicsWithColorQueryHandler).toHaveBeenCalledWith(
      expect.objectContaining({
        or: {
          labelName: ['bug', 'feature'],
          authorUsername: ['user1', 'user2'],
        },
      }),
    );
  });

  it('fetches next page when there is next page and epics list is scrolled to bottom', async () => {
    createComponent();
    await waitForPromises();
    expect(groupEpicsWithColorQueryHandler).toHaveBeenCalledTimes(1);

    findRoadmapShell().vm.$emit('scrolled-to-end');
    await waitForPromises();
    expect(groupEpicsWithColorQueryHandler).toHaveBeenCalledTimes(2);
    expect(groupEpicsWithColorQueryHandler).toHaveBeenCalledWith(
      expect.objectContaining({ endCursor: mockPageInfo.endCursor }),
    );
  });
});
