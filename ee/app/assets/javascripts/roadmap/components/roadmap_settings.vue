<script>
import { GlDrawer } from '@gitlab/ui';

import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import updateLocalRoadmapSettingsMutation from '../queries/update_local_roadmap_settings.mutation.graphql';
import localRoadmapSettingsQuery from '../queries/local_roadmap_settings.query.graphql';

import { mapLocalSettings } from '../utils/roadmap_utils';

import RoadmapDaterange from './roadmap_daterange.vue';
import RoadmapEpicsState from './roadmap_epics_state.vue';
import RoadmapMilestones from './roadmap_milestones.vue';
import RoadmapProgressTracking from './roadmap_progress_tracking.vue';
import RoadmapToggleLabels from './roadmap_toggle_labels.vue';

export default {
  name: 'RoadmapSettings',
  components: {
    GlDrawer,
    RoadmapDaterange,
    RoadmapMilestones,
    RoadmapEpicsState,
    RoadmapProgressTracking,
    RoadmapToggleLabels,
  },
  props: {
    isOpen: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['toggle-settings'],
  data() {
    return {
      headerHeight: '0px',
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    localRoadmapSettings: {
      query: localRoadmapSettingsQuery,
    },
  },
  computed: {
    ...mapLocalSettings([
      'epicsState',
      'progressTracking',
      'isProgressTrackingActive',
      'milestonesType',
      'isShowingMilestones',
      'isShowingLabels',
    ]),
  },
  watch: {
    isOpen(newIsOpen) {
      if (newIsOpen === true) {
        this.setHeaderHeight();
      }
    },
  },
  methods: {
    setLocalSettings(settings) {
      this.$apollo.mutate({
        mutation: updateLocalRoadmapSettingsMutation,
        variables: {
          input: settings,
        },
      });
    },
    setHeaderHeight() {
      const { offsetTop = 0 } = this.$root.$el;
      const clientHeight = this.$parent.$refs?.roadmapFilters?.$el.clientHeight || 0;

      this.headerHeight = `${offsetTop + clientHeight}px`;
    },
  },
  DRAWER_Z_INDEX,
};
</script>

<template>
  <gl-drawer
    v-bind="$attrs"
    :open="isOpen"
    :z-index="$options.DRAWER_Z_INDEX"
    :header-height="headerHeight"
    header-sticky
    @close="$emit('toggle-settings', $event)"
  >
    <template #title>
      <h2 class="gl-my-0 gl-text-size-h2 gl-leading-24">{{ __('Roadmap settings') }}</h2>
    </template>
    <template #default>
      <roadmap-daterange @set-date-range="setLocalSettings" />
      <roadmap-milestones
        :milestones-type="milestonesType"
        :is-showing-milestones="isShowingMilestones"
        @set-milestones-settings="setLocalSettings"
      />
      <roadmap-epics-state :epics-state="epicsState" @set-epics-state="setLocalSettings" />
      <roadmap-progress-tracking
        :progress-tracking="progressTracking"
        :is-progress-tracking-active="isProgressTrackingActive"
        @set-progress-tracking="setLocalSettings"
      />
      <roadmap-toggle-labels
        class="gl-mb-12"
        :is-showing-labels="isShowingLabels"
        @set-labels-visibility="setLocalSettings"
      />
    </template>
  </gl-drawer>
</template>
