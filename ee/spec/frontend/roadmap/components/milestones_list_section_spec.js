import { GlButton } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';

import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';

import milestonesListSectionComponent from 'ee/roadmap/components/milestones_list_section.vue';
import {
  DATE_RANGES,
  PRESET_TYPES,
  EPIC_DETAILS_CELL_WIDTH,
  TIMELINE_CELL_MIN_WIDTH,
} from 'ee/roadmap/constants';
import { scrollToCurrentDay } from 'ee/roadmap/utils/epic_utils';
import eventHub from 'ee/roadmap/event_hub';
import { getTimeframeForRangeType } from 'ee/roadmap/utils/roadmap_utils';
import { mockTimeframeInitialDate, mockGroupMilestones } from 'ee_jest/roadmap/mock_data';
import { expectPayload } from '../local_cache_helpers';

Vue.use(VueApollo);
jest.mock('ee/roadmap/utils/epic_utils');

const updateLocalRoadmapSettingsMutationMock = jest.fn();

describe('MilestonesListSectionComponent', () => {
  let wrapper;

  const mockTimeframeMonths = getTimeframeForRangeType({
    timeframeRangeType: DATE_RANGES.CURRENT_YEAR,
    presetType: PRESET_TYPES.MONTHS,
    initialDate: mockTimeframeInitialDate,
  });
  const findMilestoneCount = () => wrapper.findByTestId('count');
  const findExpandButtonContainer = () => wrapper.findByTestId('expandButton');
  const findExpandButtonData = () => {
    const container = findExpandButtonContainer();
    return {
      icon: container.findComponent(GlButton).attributes('icon'),
      iconLabel: container.findComponent(GlButton).attributes('aria-label'),
      tooltip: getBinding(container.element, 'gl-tooltip').value.title,
    };
  };
  const findMilestonesListWrapper = () => wrapper.findByTestId('milestones-list-wrapper');
  const findBottomShadow = () => wrapper.findByTestId('scroll-bottom-shadow');

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(milestonesListSectionComponent, {
      propsData: {
        milestones: mockGroupMilestones,
        timeframe: mockTimeframeMonths,
        presetType: PRESET_TYPES.MONTHS,
        bufferSize: mockGroupMilestones.length + 1,
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      apolloProvider: createMockApollo([], {
        Mutation: {
          updateLocalRoadmapSettings: updateLocalRoadmapSettingsMutationMock,
        },
      }),
    });
  };

  beforeEach(() => {
    createWrapper();
  });

  describe('on mount', () => {
    it('emits `milestones-mounted` event', () => {
      expect(wrapper.emitted('milestones-mounted')).toEqual([[]]);
    });

    it('calls `scrollToCurrentDay` method', () => {
      expect(scrollToCurrentDay).toHaveBeenCalled();
    });

    it('calls `updateLocalRoadmapSettings` mutation with correct variables', () => {
      expect(updateLocalRoadmapSettingsMutationMock).toHaveBeenCalledWith(
        ...expectPayload({ bufferSize: 16 }),
      );
    });
  });

  it('does not render the shadow at the bottom of the list', () => {
    expect(findBottomShadow().isVisible()).toBe(false);
  });

  it('calculates section container styles correctly', () => {
    expect(findMilestonesListWrapper().attributes('style')).toEqual(
      `width: ${EPIC_DETAILS_CELL_WIDTH + TIMELINE_CELL_MIN_WIDTH * mockTimeframeMonths.length}px;`,
    );
  });

  it('calculates shadow styles correctly', () => {
    expect(findBottomShadow().attributes('style')).toEqual('left: 0px; display: none;');
  });

  describe('on `epicsListScrolled` global event', () => {
    it('scrolled to the bottom and back correctly', async () => {
      eventHub.$emit('epicsListScrolled', {
        scrollTop: 5,
        clientHeight: 5,
        scrollHeight: 15,
      });
      await nextTick();

      expect(findBottomShadow().isVisible()).toBe(true);

      eventHub.$emit('epicsListScrolled', {
        scrollTop: 15,
        clientHeight: 5,
        scrollHeight: 15,
      });
      await nextTick();

      expect(findBottomShadow().isVisible()).toBe(false);
    });
  });

  it('show the correct count of milestones', () => {
    expect(findMilestoneCount().text()).toBe('2');
  });

  it('shows "chevron-down" icon on toggle button', () => {
    expect(findExpandButtonData()).toEqual({
      icon: 'chevron-down',
      iconLabel: 'Collapse milestones',
      tooltip: 'Collapse',
    });
  });

  describe('when the milestone list is expanded', () => {
    beforeEach(() => {
      findExpandButtonContainer().findComponent(GlButton).vm.$emit('click');
    });

    it('shows "chevron-right" icon when the milestone toggle button is clicked', () => {
      expect(findExpandButtonData()).toEqual({
        icon: 'chevron-right',
        iconLabel: 'Expand milestones',
        tooltip: 'Expand',
      });
    });
  });
});
