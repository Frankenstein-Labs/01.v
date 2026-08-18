import { GlDrawer } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import RoadmapSettings from 'ee/roadmap/components/roadmap_settings.vue';
import RoadmapDaterange from 'ee/roadmap/components/roadmap_daterange.vue';
import RoadmapEpicsState from 'ee/roadmap/components/roadmap_epics_state.vue';
import RoadmapMilestones from 'ee/roadmap/components/roadmap_milestones.vue';
import RoadmapProgressTracking from 'ee/roadmap/components/roadmap_progress_tracking.vue';
import RoadmapToggleLabels from 'ee/roadmap/components/roadmap_toggle_labels.vue';
import { setLocalSettingsInCache, expectPayload } from '../local_cache_helpers';

Vue.use(VueApollo);

const updateLocalSettingsMutationMock = jest.fn();

const resolvers = {
  Mutation: {
    updateLocalRoadmapSettings: updateLocalSettingsMutationMock,
  },
};

const apolloProvider = createMockApollo([], resolvers);
setLocalSettingsInCache(apolloProvider);

describe('RoadmapSettings', () => {
  let wrapper;

  const createComponent = ({ isOpen = false } = {}) => {
    wrapper = shallowMountExtended(RoadmapSettings, {
      propsData: { isOpen },
      apolloProvider,
    });
  };

  const findSettingsDrawer = () => wrapper.findComponent(GlDrawer);
  const findDaterange = () => wrapper.findComponent(RoadmapDaterange);
  const findMilestones = () => wrapper.findComponent(RoadmapMilestones);
  const findEpicsSate = () => wrapper.findComponent(RoadmapEpicsState);
  const findProgressTracking = () => wrapper.findComponent(RoadmapProgressTracking);
  const findToggleLabels = () => wrapper.findComponent(RoadmapToggleLabels);

  beforeEach(() => {
    createComponent();
  });

  describe('template', () => {
    it('renders drawer and title', () => {
      const settingsDrawer = findSettingsDrawer();
      expect(settingsDrawer.exists()).toBe(true);
      expect(settingsDrawer.text()).toContain('Roadmap settings');
      expect(settingsDrawer.props('headerHeight')).toBe('0px');
    });

    it('renders roadmap daterange component', () => {
      expect(findDaterange().exists()).toBe(true);
    });

    it('renders roadmap milestones component', () => {
      expect(findMilestones().exists()).toBe(true);
    });

    it('renders roadmap epics state component', () => {
      expect(findEpicsSate().exists()).toBe(true);
    });

    it('renders roadmap progress tracking component', () => {
      expect(findProgressTracking().exists()).toBe(true);
    });

    it('renders roadmap toggle labels', () => {
      expect(findToggleLabels().exists()).toBe(true);
    });
  });

  describe('events', () => {
    it('emits close event when drawer is closed', () => {
      findSettingsDrawer().vm.$emit('close');

      expect(wrapper.emitted('toggle-settings')).toHaveLength(1);
    });

    it('calls `updateLocalRoadmapSettings` mutation when daterange emits `set-date-range` event', async () => {
      findDaterange().vm.$emit('set-date-range', { timeframeRangeType: 'CURRENT_QUARTER' });
      await waitForPromises();

      expect(updateLocalSettingsMutationMock).toHaveBeenCalledWith(
        ...expectPayload({ timeframeRangeType: 'CURRENT_QUARTER' }),
      );
    });

    it('calls `updateLocalRoadmapSettings` mutation when milestones emits `set-milestones-settings` event', async () => {
      findMilestones().vm.$emit('set-milestones-settings', { milestonesType: 'ALL' });
      await waitForPromises();

      expect(updateLocalSettingsMutationMock).toHaveBeenCalledWith(
        ...expectPayload({ milestonesType: 'ALL' }),
      );
    });

    it('calls `updateLocalRoadmapSettings` mutation when epics state emits `set-epics-state` event', async () => {
      findEpicsSate().vm.$emit('set-epics-state', { epicsState: 'ALL' });
      await waitForPromises();

      expect(updateLocalSettingsMutationMock).toHaveBeenCalledWith(
        ...expectPayload({ epicsState: 'ALL' }),
      );
    });

    it('calls `updateLocalRoadmapSettings` mutation when progress tracking emits `set-progress-tracking` event', async () => {
      findProgressTracking().vm.$emit('set-progress-tracking', { progressTracking: true });
      await waitForPromises();

      expect(updateLocalSettingsMutationMock).toHaveBeenCalledWith(
        ...expectPayload({ progressTracking: true }),
      );
    });

    it('calls `updateLocalRoadmapSettings` mutation when toggle labels emits `set-labels-visibility` event', async () => {
      findToggleLabels().vm.$emit('set-labels-visibility', { isLabelsVisible: true });
      await waitForPromises();

      expect(updateLocalSettingsMutationMock).toHaveBeenCalledWith(
        ...expectPayload({ isLabelsVisible: true }),
      );
    });
  });
});
