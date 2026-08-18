<script>
import { GlDrawer, GlLink, GlSprintf } from '@gitlab/ui';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import FrameworkBadge from '../../../shared/framework_badge.vue';
import StatusesList from './statuses_list.vue';

export default {
  components: {
    GlDrawer,
    GlLink,
    GlSprintf,

    FrameworkBadge,
    StatusesList,
  },
  props: {
    status: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['close'],
  computed: {
    title() {
      return this.status?.complianceRequirement.name || '';
    },
    relevantStatuses() {
      const statuses = this.status.project.complianceControlStatus.nodes;
      const knownControls = new Set(
        this.status.complianceRequirement.complianceRequirementsControls.nodes.map((n) => n.id),
      );
      return statuses.filter((status) =>
        knownControls.has(status.complianceRequirementsControl.id),
      );
    },
  },
  methods: {
    getContentWrapperHeight,
  },
  DRAWER_Z_INDEX,
};
</script>

<template>
  <gl-drawer
    :open="Boolean(status)"
    :header-height="getContentWrapperHeight()"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="$emit('close')"
  >
    <template #title>
      <h2 class="gl-heading-3 gl-mb-0">{{ title }}</h2>
    </template>
    <template v-if="status">
      <div class="gl-flex gl-flex-col gl-gap-3 gl-p-5">
        <framework-badge :framework="status.complianceFramework" popover-mode="details" />
        <gl-link :href="status.project.webUrl">{{ status.project.name }}</gl-link>
      </div>
      <div v-if="status.complianceRequirement.description" class="gl-p-5">
        <h3 class="gl-heading-3">{{ __('Description') }}</h3>
        {{ status.complianceRequirement.description }}
      </div>
      <div class="gl-p-5">
        <h3 class="gl-heading-3">{{ s__('ComplianceStandardsAdherence|Status') }}</h3>
        <div class="gl-flex gl-flex-row gl-gap-3">
          <span v-if="status.failCount" class="gl-text-status-danger">
            <gl-sprintf :message="s__('ComplianceStandardsAdherence|Failed controls: %{failed}')">
              <template #failed>{{ status.failCount }}</template>
            </gl-sprintf>
          </span>
          <span v-if="status.pendingCount" class="gl-text-status-neutral">
            <gl-sprintf :message="s__('ComplianceStandardsAdherence|Pending controls: %{pending}')">
              <template #pending>{{ status.pendingCount }}</template>
            </gl-sprintf>
          </span>
          <span v-if="status.passCount" class="gl-text-status-success">
            <gl-sprintf :message="s__('ComplianceStandardsAdherence|Passed controls: %{passed}')">
              <template #passed>{{ status.passCount }}</template>
            </gl-sprintf>
          </span>
        </div>
      </div>
      <statuses-list :control-statuses="relevantStatuses" :project="status.project" />
    </template>
  </gl-drawer>
</template>
