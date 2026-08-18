<script>
import {
  GlAttributeList,
  GlBadge,
  GlButton,
  GlLink,
  GlSkeletonLoader,
  GlTooltipDirective,
} from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { localeDateFormat } from '~/lib/utils/datetime/locale_dateformat';
import { getAgentStatusBadge } from 'ee/ai/duo_agents_platform/utils';
import {
  AGENT_PLATFORM_CANCELABLE_STATUSES,
  WORKFLOW_TERMINAL_STATUSES,
} from 'ee/ai/duo_agents_platform/constants';
import { WorkflowUtils } from 'ee/ai/duo_agentic_chat/utils/workflow_utils';
import { projectAutomateAgentSessionPath } from 'ee/lib/utils/path_helpers/project';
import AgentFlowTriggeredUser from '../../../components/common/agent_flow_triggered_user.vue';
import TodoChecklist from '../../../components/common/todo_checklist.vue';

export default {
  name: 'AgentFlowInfo',
  components: {
    GlAttributeList,
    GlBadge,
    GlButton,
    GlLink,
    GlSkeletonLoader,
    AgentFlowTriggeredUser,
    TodoChecklist,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    isLoading: {
      required: true,
      type: Boolean,
    },
    status: {
      required: true,
      type: String,
    },
    humanStatus: {
      required: true,
      type: String,
    },
    agentFlowDefinition: {
      required: true,
      type: String,
    },
    modelName: {
      type: String,
      required: false,
      default: '',
    },
    modelIdentifier: {
      type: String,
      required: false,
      default: '',
    },
    allExecutorUrls: {
      required: false,
      type: Array,
      default: () => [],
    },
    createdAt: {
      type: String,
      required: false,
      default: '',
    },
    updatedAt: {
      type: String,
      required: false,
      default: '',
    },
    project: {
      type: Object,
      required: true,
    },
    user: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    canUpdateWorkflow: {
      type: Boolean,
      required: true,
    },
    workItem: {
      type: Object,
      required: false,
      default: null,
    },
    mergeRequest: {
      type: Object,
      required: false,
      default: null,
    },
    isSidePanelView: {
      type: Boolean,
      required: false,
      default: false,
    },
    duoMessages: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['cancel-session'],
  computed: {
    itemStatus() {
      return getAgentStatusBadge(this.status);
    },
    latestTodoToolInfo() {
      const messages = WorkflowUtils.normalizeDuoMessages(this.duoMessages);
      return WorkflowUtils.findLatestTodoToolInfo(messages);
    },
    showPlan() {
      return Boolean(this.latestTodoToolInfo);
    },
    todos() {
      return this.latestTodoToolInfo?.args?.todos || [];
    },
    todoProgressText() {
      return sprintf(s__('DuoAgentPlatform|%{completed} of %{total}'), {
        completed: this.todos.filter((todo) => todo.status === 'completed').length,
        total: this.todos.length,
      });
    },
    isTerminal() {
      return WORKFLOW_TERMINAL_STATUSES.includes(this.status);
    },
    projectAgentSessionsUrl() {
      const sessionId = this.$route.params.id;
      const projectFullPath = this.project?.fullPath;

      return sessionId && projectFullPath
        ? projectAutomateAgentSessionPath(projectFullPath, sessionId)
        : '';
    },
    canCancelSession() {
      return AGENT_PLATFORM_CANCELABLE_STATUSES.includes(this.status);
    },
    buttonTooltip() {
      return this.canUpdateWorkflow
        ? ''
        : s__('DuoAgentsPlatform|You do not have permission to cancel this session.');
    },
    payload() {
      const jobItems = (this.allExecutorUrls ?? [])
        .map((url) => ({ webPath: url, iid: this.getIdFromUrl(url) }))
        .filter((item) => item.iid !== null);

      return [
        {
          label: s__('AI|AI Item'),
          text: this.agentFlowDefinition,
        },
        {
          label: s__('DuoAgentPlatform|Session ID'),
          text: `${this.$route.params.id}`,
          link: this.projectAgentSessionsUrl,
        },
        {
          label: __('Type'),
          text: s__('DuoAgentPlatform|Flow'),
        },
        {
          label: __('Project'),
          text: this.project?.name || __('None'),
          link: this.project?.webUrl,
        },
        {
          label: __('Group'),
          text: this.project?.namespace?.name || __('None'),
          link: this.project?.namespace?.webUrl,
        },
        {
          label: __('Triggered by'),
          text: this.user?.name || __('Unknown'),
          type: 'triggeredUser',
        },
        {
          label: __('Work item'),
          text: this.workItem ? `#${this.workItem.iid}` : __('None'),
          link: this.workItem?.webUrl ?? null,
        },
        {
          label: __('Merge request'),
          text: this.mergeRequest ? `!${this.mergeRequest.iid}` : __('None'),
          link: this.mergeRequest?.webUrl ?? null,
        },
        {
          label: __('Status'),
          text: this.humanStatus,
          type: 'status',
        },
        {
          label: __('Started'),
          text: this.formatTimestamp(this.createdAt),
          hideIfEmpty: true,
        },
        {
          label: __('Last updated'),
          text: this.formatTimestamp(this.updatedAt),
          hideIfEmpty: true,
        },
        {
          label: s__('DuoAgentPlatform|Job IDs'),
          text: jobItems.length ? jobItems.map((item) => `${item.iid}`).join(', ') : __('None'),
          type: 'jobItems',
          jobItems,
        },
        ...(this.modelName
          ? [
              {
                label: s__('DuoAgentPlatform|Default model'),
                type: 'model',
                text: this.modelName,
                tooltip: this.modelIdentifier,
              },
            ]
          : []),
      ].filter((entry) => !entry.hideIfEmpty || entry.text);
    },
  },
  methods: {
    getIdFromUrl(url) {
      const id = url.split('/').pop();
      if (!id || Number.isNaN(Number(id))) {
        return null;
      }
      return id;
    },
    formatTimestamp(isoString) {
      if (!isoString) {
        return null;
      }

      try {
        const date = new Date(isoString);
        if (Number.isNaN(date.getTime())) {
          return null;
        }
        return localeDateFormat.asDateTime.format(date);
      } catch (error) {
        return null;
      }
    },
  },
};
</script>
<template>
  <div>
    <div
      v-if="showPlan"
      class="gl-ml-4 gl-py-5"
      :class="{ 'gl-border-b': !isSidePanelView, 'gl-border-t': isSidePanelView }"
      data-testid="plan-section"
    >
      <div class="gl-mb-2 gl-mr-4 gl-flex gl-items-center gl-justify-between gl-gap-3">
        <span class="gl-font-bold" data-testid="todos-heading">
          {{ s__('DuoAgentPlatform|Agent todos') }}
        </span>
        <span class="gl-text-sm gl-text-subtle" data-testid="todo-progress-summary">
          {{ todoProgressText }}
        </span>
      </div>
      <todo-checklist
        :tool-info="latestTodoToolInfo"
        :flow-finished="isTerminal"
        :bordered="false"
      />
    </div>

    <div
      class="gl-ml-4 gl-overflow-hidden"
      :class="{ 'gl-border-t': isSidePanelView }"
      data-testid="attribute-list-section"
    >
      <div
        class="gl-@container"
        :style="isSidePanelView ? { minWidth: '30rem' } : {}"
        data-testid="attribute-list-container"
      >
        <gl-attribute-list :items="payload">
          <template #label="{ item }">
            <span data-testid="info-title">
              {{ sprintf(__('%{label}'), { label: item.label }) }}
            </span>
          </template>
          <template #description="{ item }">
            <div :data-testid="`info-row-${item.label}`">
              <gl-skeleton-loader v-if="isLoading" :lines="1" />
              <template v-else>
                <agent-flow-triggered-user
                  v-if="item.type === 'triggeredUser'"
                  class="gl-link"
                  :user="user"
                />
                <span
                  v-else-if="item.type === 'jobItems'"
                  class="gl-min-w-0"
                  data-testid="info-value"
                >
                  <template v-if="item.jobItems.length">
                    <span v-for="(jobItem, index) in item.jobItems" :key="jobItem.iid">
                      <template v-if="index > 0">{{ __(', ') }}</template>
                      <gl-link :href="jobItem.webPath">{{ jobItem.iid }}</gl-link>
                    </span>
                  </template>
                  <template v-else>{{ __('None') }}</template>
                </span>
                <span v-else-if="item.type === 'model'" data-testid="info-value">
                  <gl-badge
                    v-gl-tooltip="item.tooltip"
                    class="gl-font-monospace"
                    data-testid="model-badge"
                  >
                    {{ item.text }}
                  </gl-badge>
                </span>
                <span v-else data-testid="info-value">
                  <gl-link v-if="item.link" :href="item.link">{{ item.text }}</gl-link>
                  <gl-badge
                    v-else-if="item.type === 'status'"
                    class="gl-mr-3"
                    :icon="itemStatus.icon"
                    icon-size="sm"
                    :variant="itemStatus.variant"
                  >
                    {{ item.text }}
                  </gl-badge>
                  <template v-else>{{ item.text }}</template>
                </span>
              </template>
            </div>
          </template>
        </gl-attribute-list>
      </div>
    </div>

    <div v-if="canCancelSession" class="gl-ml-4 gl-py-4">
      <div class="gl-flex gl-gap-3">
        <span v-gl-tooltip="buttonTooltip">
          <gl-button
            category="secondary"
            variant="danger"
            :disabled="!canUpdateWorkflow"
            data-testid="cancel-session-button"
            @click="$emit('cancel-session')"
          >
            {{ s__('DuoAgentsPlatform|Cancel session') }}
          </gl-button>
        </span>
      </div>
    </div>
  </div>
</template>
