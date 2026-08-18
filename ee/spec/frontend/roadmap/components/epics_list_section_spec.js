import { GlIntersectionObserver, GlLoadingIcon } from '@gitlab/ui';

import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';

import EpicItem from 'ee/roadmap/components/epic_item.vue';
import EpicsListSection from 'ee/roadmap/components/epics_list_section.vue';
import {
  DATE_RANGES,
  PRESET_TYPES,
  EPIC_DETAILS_CELL_WIDTH,
  TIMELINE_CELL_MIN_WIDTH,
} from 'ee/roadmap/constants';
import { scrollToCurrentDay } from 'ee/roadmap/utils/epic_utils';
import { getTimeframeForRangeType } from 'ee/roadmap/utils/roadmap_utils';
import {
  mockTimeframeInitialDate,
  mockGroupId,
  rawEpics,
  mockEpicsWithParents,
  mockEpicsWithSkippedParents,
} from 'ee_jest/roadmap/mock_data';
import eventHub from 'ee/roadmap/event_hub';

import { expectPayload } from '../local_cache_helpers';

Vue.use(VueApollo);
jest.mock('ee/roadmap/utils/epic_utils');

const updateLocalRoadmapSettingsMutationMock = jest.fn();

const mockTimeframeMonths = getTimeframeForRangeType({
  timeframeRangeType: DATE_RANGES.CURRENT_YEAR,
  presetType: PRESET_TYPES.MONTHS,
  initialDate: mockTimeframeInitialDate,
});

describe('EpicsListSectionComponent', () => {
  let wrapper;

  const findBottomShadow = () => wrapper.findByTestId('epic-scroll-bottom-shadow');
  const findEmptyRowEl = () => wrapper.find('.epics-list-item-empty');
  const findAllEpicItems = () => wrapper.findAllComponents(EpicItem);
  const findIntersectionObserver = () => wrapper.findComponent(GlIntersectionObserver);

  const createComponent = ({
    epics = rawEpics,
    epicsFetchNextPageInProgress = false,
    hasNextPage = false,
    epicIid = null,
    bufferSize = rawEpics.length + 1,
  } = {}) => {
    wrapper = shallowMountExtended(EpicsListSection, {
      propsData: {
        presetType: PRESET_TYPES.MONTHS,
        timeframe: mockTimeframeMonths,
        epics,
        epicsFetchNextPageInProgress,
        hasNextPage,
        bufferSize,
      },
      provide: {
        currentGroupId: mockGroupId,
        epicIid,
      },
      apolloProvider: createMockApollo([], {
        Mutation: {
          updateLocalRoadmapSettings: updateLocalRoadmapSettingsMutationMock,
        },
      }),
    });
  };

  it('renders all top-level epics by default', () => {
    createComponent();

    expect(findAllEpicItems()).toHaveLength(
      // Only top-level epics are visible by default, any child
      // epics are shown only when the parent is expanded.
      rawEpics.filter((epic) => !epic.hasParent).length,
    );
  });

  it('renders empty row container when number of epics is smaller than buffer size', async () => {
    createComponent();

    await nextTick();

    expect(findEmptyRowEl().exists()).toBe(true);
  });

  it('renders correct styles for container element based on sectionShellWidth', () => {
    createComponent();

    expect(wrapper.attributes('style')).toContain(
      `width: ${EPIC_DETAILS_CELL_WIDTH + TIMELINE_CELL_MIN_WIDTH * mockTimeframeMonths.length}px;`,
    );
  });

  it('does not set style attribute on empty row when no epics are available to render', async () => {
    createComponent({ epics: [] });
    await nextTick();

    expect(findEmptyRowEl().attributes('style')).not.toBeDefined();
  });

  describe('epics with associated parents', () => {
    it('should return only epics where parent is not present on top level', async () => {
      createComponent({ epics: mockEpicsWithParents });

      await nextTick();

      expect(findAllEpicItems()).toHaveLength(1);
    });

    it('should return epics which match the applied filter when one of the epic in hierarchy is not matching the filter', async () => {
      createComponent({ epics: mockEpicsWithSkippedParents });

      await nextTick();

      expect(findAllEpicItems()).toHaveLength(mockEpicsWithSkippedParents.length);
    });

    it('returns all epics if epicIid is specified', () => {
      createComponent({ epics: mockEpicsWithParents, epicIid: '1' });

      expect(findAllEpicItems()).toHaveLength(mockEpicsWithParents.length);
    });
  });

  describe('when mounted', () => {
    beforeEach(async () => {
      createComponent();

      await nextTick();
      jest.runAllTimers();
    });

    it('calls `setBufferSize` mutation with value based on window.innerHeight and component element position', () => {
      expect(updateLocalRoadmapSettingsMutationMock).toHaveBeenCalledWith(
        ...expectPayload({ bufferSize: 16 }),
      );
    });

    it('calls `scrollToCurrentDay` following the component render', () => {
      expect(scrollToCurrentDay).toHaveBeenCalledWith(wrapper.element);
    });

    it('sets style attribute containing `height` on empty row', () => {
      expect(findEmptyRowEl().attributes('style')).toBe('height: calc(100vh - 1px);');
    });
  });

  describe('on global epic scroll event', () => {
    it('toggles value of `showBottomShadow` based on provided `scrollTop`, `clientHeight` & `scrollHeight`', async () => {
      createComponent();

      const bottomShadow = findBottomShadow();

      eventHub.$emit('epicsListScrolled', {
        scrollTop: 5,
        clientHeight: 5,
        scrollHeight: 15,
      });
      await nextTick();

      // Math.ceil(scrollTop) + clientHeight < scrollHeight
      expect(bottomShadow.isVisible()).toBe(true);

      eventHub.$emit('epicsListScrolled', {
        scrollTop: 15,
        clientHeight: 5,
        scrollHeight: 15,
      });
      await nextTick();

      // Math.ceil(scrollTop) + clientHeight < scrollHeight
      expect(bottomShadow.isVisible()).toBe(false);
    });
  });

  describe('when epics list has next page', () => {
    it('renders gl-intersection-observer component', () => {
      createComponent({ hasNextPage: true });

      expect(findIntersectionObserver().exists()).toBe(true);
    });

    it('emits `scrolled-to-end` event when gl-intersection-observer appears in viewport', () => {
      createComponent({ hasNextPage: true });

      findIntersectionObserver().vm.$emit('appear');

      expect(wrapper.emitted('scrolled-to-end')).toHaveLength(1);
    });

    it('renders loading icon when epicsFetchForNextPageInProgress is true', () => {
      createComponent({ hasNextPage: true, epicsFetchNextPageInProgress: true });

      expect(wrapper.findByTestId('next-page-loading').text()).toContain('Loading epics');
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });

    it('renders bottom shadow element when `showBottomShadow` prop is true', () => {
      createComponent({ hasNextPage: true });
      eventHub.$emit('epicsListScrolled', {
        scrollTop: 5,
        clientHeight: 5,
        scrollHeight: 15,
      });

      expect(findBottomShadow().exists()).toBe(true);
    });
  });
});
