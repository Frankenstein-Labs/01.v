<script>
import { GlButton, GlBadge, GlLink } from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { s__, __ } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { formatAgentStatus, getAgentStatusBadge } from 'ee/ai/duo_agents_platform/utils';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import ReadinessItem from './readiness_item.vue';

const SKIP_REASONS = {
  already_present: s__('DuoAgentsPlatform|Already set up'),
  prerequisite_missing: s__('DuoAgentsPlatform|Prerequisite missing'),
};

const RETRYABLE_STATUSES = ['failed', 'stopped'];

export default {
  name: 'InitializerSection',
  components: { GlButton, GlBadge, GlLink, CrudComponent, ReadinessItem },
  props: {
    title: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: false,
      default: '',
    },
    icon: {
      type: String,
      required: false,
      default: null,
    },
    anchorId: {
      type: String,
      required: true,
    },
    testid: {
      type: String,
      required: true,
    },
    initializers: {
      type: Array,
      required: false,
      default: () => [],
    },
    setupPath: {
      type: String,
      required: false,
      default: '',
    },
    runLabel: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      rows: this.initializers.map((item) => ({ ...item })),
      busy: {},
    };
  },
  methods: {
    sessionUrl(workflowId) {
      if (!workflowId) return null;

      return this.$router.resolve({
        name: AGENTS_PLATFORM_SHOW_ROUTE,
        params: { id: workflowId },
      }).href;
    },
    statusVariant(status) {
      return getAgentStatusBadge(String(status).toUpperCase()).variant;
    },
    statusLabel(status) {
      return formatAgentStatus(status);
    },
    skipLabel(reason) {
      return SKIP_REASONS[reason] || s__('DuoAgentsPlatform|Skipped');
    },
    isRetryable(status) {
      return RETRYABLE_STATUSES.includes(status);
    },
    showActionButton(row) {
      return row.applicable && (!row.status || this.isRetryable(row.status));
    },
    actionLabel(row) {
      if (row.status) return this.$options.i18n.retry;

      return this.runLabel || this.$options.i18n.generate;
    },
    async run(eventType) {
      if (!this.setupPath) {
        createAlert({ message: s__('DuoAgentsPlatform|Onboarding setup path not configured.') });
        return;
      }

      this.busy = { ...this.busy, [eventType]: true };

      try {
        const { data } = await axios.post(this.setupPath, { event_type: eventType });
        const row = this.rows.find((item) => item.event_type === eventType);

        if (row) {
          row.status = 'created';
          row.workflow_id = data?.workflow_id;
        }
      } catch (error) {
        createAlert({
          message:
            error.response?.data?.message ||
            s__('DuoAgentsPlatform|Something went wrong while running the initializer.'),
          captureError: true,
          error,
        });
      } finally {
        this.busy = { ...this.busy, [eventType]: false };
      }
    },
  },
  i18n: {
    generate: s__('DuoAgentsPlatform|Generate'),
    retry: __('Retry'),
    viewSession: s__('DuoAgentsPlatform|View session'),
  },
};
</script>

<template>
  <crud-component
    :title="title"
    :description="description"
    :count="rows.length"
    :icon="icon"
    :anchor-id="anchorId"
    :data-testid="testid"
    is-collapsible
  >
    <ul class="gl-m-0 gl-list-none gl-p-0">
      <readiness-item
        v-for="row in rows"
        :key="row.event_type"
        :title="row.display_name"
        :description="row.description"
        :target-file="row.target_file"
        :data-testid="`initializer-row-${row.event_type}`"
      >
        <template #status>
          <gl-badge v-if="!row.applicable" variant="neutral" data-testid="skipped-badge">
            {{ skipLabel(row.skipped_reason) }}
          </gl-badge>
          <gl-badge
            v-else-if="row.status"
            :variant="statusVariant(row.status)"
            data-testid="status-badge"
          >
            {{ statusLabel(row.status) }}
          </gl-badge>
        </template>

        <template v-if="row.applicable" #actions>
          <gl-link
            v-if="row.workflow_id"
            :href="sessionUrl(row.workflow_id)"
            data-testid="session-link"
          >
            {{ $options.i18n.viewSession }}
          </gl-link>
          <gl-button
            v-if="showActionButton(row)"
            variant="confirm"
            size="small"
            :loading="busy[row.event_type]"
            data-testid="action-button"
            @click="run(row.event_type)"
          >
            {{ actionLabel(row) }}
          </gl-button>
        </template>
      </readiness-item>
    </ul>
  </crud-component>
</template>
