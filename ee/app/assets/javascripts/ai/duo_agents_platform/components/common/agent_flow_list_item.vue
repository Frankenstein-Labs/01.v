<script>
import { GlLink, GlTooltipDirective } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getTimeago } from '~/lib/utils/datetime/timeago_utility';
import { projectAutomateAgentSessionPath } from 'ee/lib/utils/path_helpers/project';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import { formatAgentStatus, formatAgentFlowTitle } from 'ee/ai/duo_agents_platform/utils';
import AgentStatusIcon from 'ee/ai/shared/widgets/agent_status_icon.vue';

export default {
  name: 'AgentFlowListItem',
  components: { GlLink, AgentStatusIcon },
  directives: { GlTooltip: GlTooltipDirective },
  props: {
    showProjectInfo: {
      required: false,
      type: Boolean,
      default: false,
    },
    item: {
      required: true,
      type: Object,
    },
  },
  computed: {
    numericId() {
      return getIdFromGraphQLId(this.item.id);
    },
    title() {
      return formatAgentFlowTitle(this.item.title, this.item.workflowDefinition);
    },
    tooltipText() {
      return `${this.title} #${this.numericId}`;
    },
    linkHoverStyles() {
      return [
        'hover:gl-bg-[--gl-action-neutral-background-color-hover]',
        'hover:gl-no-underline',
        'focus-visible:gl-no-underline',
        'active:gl-no-underline',
        'focus-visible:active:gl-no-underline',
      ];
    },
    sessionRoute() {
      return { name: this.$options.showRoute, params: { id: this.numericId } };
    },
    sessionUrl() {
      const fullPath = this.item.project?.fullPath;
      return fullPath ? projectAutomateAgentSessionPath(fullPath, this.numericId) : null;
    },
    humanStatus() {
      return formatAgentStatus(this.item.humanStatus);
    },
  },
  methods: {
    handleItemSelected(event) {
      if (event.metaKey || event.ctrlKey || event.shiftKey) return;
      event.preventDefault();
      this.$router.push(this.sessionRoute);
    },
    formatTimestamp(timestamp) {
      try {
        return getTimeago().format(timestamp);
      } catch {
        return timestamp || '';
      }
    },
  },
  showRoute: AGENTS_PLATFORM_SHOW_ROUTE,
};
</script>
<template>
  <li class="gl-list-none">
    <gl-link
      :href="sessionUrl"
      class="gl-flex gl-flex-col gl-p-4"
      :class="linkHoverStyles"
      @click="handleItemSelected"
    >
      <div class="gl-flex gl-items-center gl-justify-between">
        <div class="gl-flex gl-min-w-0 gl-items-center" data-testid="item-title">
          <agent-status-icon :status="item.status" :human-status="humanStatus" />
          <strong
            v-gl-tooltip
            class="gl-min-w-0 gl-truncate gl-pl-3 gl-text-strong"
            :title="tooltipText"
            >{{ title }}
          </strong>
        </div>
        <div
          v-if="showProjectInfo && item.project"
          class="gl-text-subtle"
          data-testid="item-project"
        >
          {{ item.project.name }}
        </div>
      </div>

      <div class="gl-ml-7 gl-mt-0 gl-flex gl-items-center gl-gap-2 gl-text-subtle">
        <span data-testid="item-status">{{ humanStatus }}</span>
        <span class="gl-text-subtle" aria-hidden="true">·</span>
        <span data-testid="item-updated-date">{{ formatTimestamp(item.updatedAt) }}</span>
      </div>
    </gl-link>
  </li>
</template>
