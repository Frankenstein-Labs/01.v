<script>
import { s__, sprintf } from '~/locale';
import { formatEventName } from '../utils';
import SummarySection from './summary_section.vue';
import DetailsSection from './details_section.vue';

// Audit events for the Duo Agent Platform always target the workflow session.
// The backend does not expose entity/target as stored columns, so the target
// facts are reconstructed client-side from the workflow definition and id.
const TARGET_TYPE = 'Ai::DuoWorkflows::Workflow';

export default {
  name: 'AuditEventDetailsPanel',
  components: {
    SummarySection,
    DetailsSection,
  },
  props: {
    event: {
      type: Object,
      required: true,
    },
    workflowDefinition: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    targetType() {
      return TARGET_TYPE;
    },
    targetDetails() {
      const { workflowId } = this.event;

      if (!this.workflowDefinition || !workflowId) {
        return '';
      }

      return sprintf(this.$options.i18n.targetDetailsFormat, {
        workflowDefinition: this.workflowDefinition,
        workflowId,
      });
    },
    detailsData() {
      return this.event.details || {};
    },
  },
  methods: {
    formatEventName,
  },
  i18n: {
    targetDetailsFormat: s__('AgentArtifacts|%{workflowDefinition} session %{workflowId}'),
  },
};
</script>

<template>
  <div data-testid="audit-event-details-panel">
    <div class="gl-mt-6 gl-flex gl-items-center gl-justify-between gl-gap-3">
      <h4 class="gl-m-0" data-testid="audit-event-title">
        {{ formatEventName(event.eventName) }}
      </h4>
      <slot name="download-action"></slot>
    </div>

    <summary-section
      :event="event"
      :target-type="targetType"
      :target-details="targetDetails"
      class="gl-mt-6"
    />

    <details-section :details="detailsData" class="gl-mt-6" />
  </div>
</template>
