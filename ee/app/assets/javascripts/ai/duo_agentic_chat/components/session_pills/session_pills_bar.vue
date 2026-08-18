<script>
import { GlCollapse, GlDisclosureDropdown, GlResizeObserverDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import getWorkflowsByIdsQuery from 'ee/ai/graphql/get_workflows_by_ids.query.graphql';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';
import {
  MESSAGE_SUB_TYPE_START_FLOW,
  WORKFLOW_TERMINAL_STATUSES,
  WORKFLOW_AWAITING_INPUT_STATUSES,
} from 'ee/ai/duo_agents_platform/constants';
import { captureExceptionForDuoChat } from '../../observability/sentry_utils';
import SessionPill from './session_pill.vue';
import { getStatusDotClass } from './utils';
import { POLL_INTERVAL_MS, OVERFLOW_RESERVE_PX } from './constants';

export default {
  name: 'SessionPillsBar',
  components: {
    GlCollapse,
    GlDisclosureDropdown,
    SessionPill,
  },
  directives: {
    GlResizeObserver: GlResizeObserverDirective,
  },
  apollo: {
    activeWorkflows: {
      query: getWorkflowsByIdsQuery,
      variables() {
        return { ids: this.chatWorkflowIds };
      },
      skip() {
        return this.chatWorkflowIds.length === 0;
      },
      context: {
        featureCategory: 'duo_agent_platform',
      },
      pollInterval: POLL_INTERVAL_MS,
      update(data) {
        return data?.duoWorkflowWorkflows?.edges?.map((edge) => edge.node) ?? [];
      },
      error(error) {
        captureExceptionForDuoChat(error);
      },
    },
  },
  props: {
    messages: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['height-change'],
  data() {
    return {
      activeWorkflows: [],
      containerWidth: 0,
      pillWidths: [],
      moreSessionsLabel: s__('DuoAgenticChat|More active sessions'),
    };
  },
  computed: {
    chatWorkflows() {
      return this.messages.reduce((map, message) => {
        if (message?.message_sub_type !== MESSAGE_SUB_TYPE_START_FLOW) return map;

        let payload;
        try {
          payload = JSON.parse(message?.tool_info?.tool_response?.content ?? '{}');
        } catch {
          return map;
        }

        const workflowId = Number(payload.workflow_id);
        const flowName = payload.flow_name;
        if (!workflowId || !flowName) return map;

        map.set(workflowId, { workflowId, flowName });
        return map;
      }, new Map());
    },
    chatWorkflowIds() {
      return Array.from(this.chatWorkflows.keys()).map((id) =>
        convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, id),
      );
    },
    visiblePills() {
      const pills = this.activeWorkflows.flatMap((workflow) => {
        const status = workflow.status?.toUpperCase();
        if (WORKFLOW_TERMINAL_STATUSES.includes(status)) return [];

        // The query already returns only the ids we asked for. `flowName`
        // still comes from the chat message so the pill label is meaningful
        // even when the server response is minimal.
        const workflowId = Number(getIdFromGraphQLId(workflow.id));
        const fromChat = this.chatWorkflows.get(workflowId);
        if (!fromChat) return [];

        return [{ workflowId, flowName: fromChat.flowName, status }];
      });

      // Surface workflows waiting on the user (e.g. INPUT_REQUIRED) ahead of
      // anything else so they stay visible when the row overflows.
      return pills.sort((a, b) => {
        const aAwaiting = WORKFLOW_AWAITING_INPUT_STATUSES.includes(a.status);
        const bAwaiting = WORKFLOW_AWAITING_INPUT_STATUSES.includes(b.status);
        if (aAwaiting === bAwaiting) return 0;
        return aAwaiting ? -1 : 1;
      });
    },
    hasPills() {
      return this.visiblePills.length > 0;
    },
    visibleCount() {
      const { visiblePills, containerWidth, pillWidths: widths } = this;

      // Bootstrap: before the first ResizeObserver tick (or before pills have
      // been measured) we render all pills so `measurePills` has DOM nodes to
      // size. The next tick fills `pillWidths` and re-evaluates this getter
      // to collapse overflow into the dropdown — a deliberate two-pass render.
      if (!containerWidth || visiblePills.length === 0 || widths.length === 0) {
        return visiblePills.length;
      }

      let total = 0;
      let count = 0;
      for (let i = 0; i < visiblePills.length; i += 1) {
        const width = widths[i] ?? widths[widths.length - 1];
        const reserve = i < visiblePills.length - 1 ? OVERFLOW_RESERVE_PX : 0;
        if (total + width + reserve > containerWidth) break;
        total += width;
        count += 1;
      }
      return Math.max(count, 1);
    },
    renderedPills() {
      return this.visiblePills.slice(0, this.visibleCount);
    },
    overflowPills() {
      return this.visiblePills.slice(this.visibleCount);
    },
    overflowItems() {
      return this.overflowPills.map((pill) => ({
        text: `${pill.flowName} #${pill.workflowId}`,
        action: () => this.openSession(pill.workflowId),
        extraAttrs: {
          'data-workflow-id': pill.workflowId,
        },
        statusDotClass: getStatusDotClass(pill.status),
      }));
    },
  },
  watch: {
    visiblePills() {
      this.$nextTick(() => {
        this.measurePills();
      });
    },
  },
  methods: {
    handleResize(entry) {
      this.containerWidth = entry.contentRect.width;
      this.measurePills();
    },
    measurePills() {
      const refs = this.$refs.pill;
      if (!refs?.length) {
        this.pillWidths = [];
        return;
      }

      this.pillWidths = refs.map((ref) => {
        const el = ref?.$el ?? ref;
        return el?.getBoundingClientRect?.().width ?? 0;
      });
    },
    openSession(workflowId) {
      eventHub.$emit(SHOW_SESSION, { id: workflowId });
    },
  },
};
</script>

<template>
  <gl-collapse :visible="hasPills" @shown="$emit('height-change')" @hidden="$emit('height-change')">
    <div
      v-gl-resize-observer="handleResize"
      data-testid="session-pills-bar"
      class="gl-flex gl-min-h-7 gl-items-center gl-gap-2 gl-overflow-hidden gl-py-2"
    >
      <session-pill
        v-for="pill in renderedPills"
        ref="pill"
        :key="pill.workflowId"
        :ref-in-for="true"
        :workflow-id="pill.workflowId"
        :flow-name="pill.flowName"
        :status="pill.status"
        @click="openSession"
      />
      <gl-disclosure-dropdown
        v-if="overflowPills.length"
        data-testid="session-pills-overflow"
        icon="ellipsis_h"
        category="tertiary"
        size="small"
        no-caret
        text-sr-only
        :toggle-text="moreSessionsLabel"
        :items="overflowItems"
      >
        <template #list-item="{ item }">
          <span class="gl-inline-flex gl-items-center gl-gap-2">
            <span
              class="gl-inline-block gl-h-3 gl-w-3 gl-shrink-0 gl-rounded-full"
              :class="item.statusDotClass"
              aria-hidden="true"
            ></span>
            <span>{{ item.text }}</span>
          </span>
        </template>
      </gl-disclosure-dropdown>
    </div>
  </gl-collapse>
</template>
