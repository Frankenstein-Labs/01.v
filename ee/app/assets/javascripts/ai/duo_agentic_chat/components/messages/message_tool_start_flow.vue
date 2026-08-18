<script>
import { GlAnimatedLoaderIcon, GlIcon, GlLoadingIcon } from '@gitlab/ui';
import { last } from 'lodash-es';
import AgentStatusIcon from 'ee/ai/shared/widgets/agent_status_icon.vue';
import TodoChecklist from 'ee/ai/duo_agents_platform/components/common/todo_checklist.vue';
import { getMessageData } from 'ee/ai/duo_agents_platform/utils';
import { parseToolInfo } from 'ee/ai/duo_agents_platform/icon_utils';
import getWorkflowLatestCheckpointQuery from 'ee/ai/graphql/get_workflow_latest_checkpoint.query.graphql';
import { s__ } from '~/locale';
import { truncate } from '~/lib/utils/text_utility';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';
import { captureExceptionForDuoChat } from '../../observability/sentry_utils';
import { EventsTracker } from '../../observability/events_tracker';
import { WorkflowUtils } from '../../utils/workflow_utils';

const POLL_INTERVAL = 10000;
const TERMINAL_STATUSES = ['FINISHED', 'FAILED', 'STOPPED'];
const ACTIVITY_DETAIL_MAX_LENGTH = 140;
const isTerminalStatus = (status) => TERMINAL_STATUSES.includes(status);

const HOVER_CLASSES = ['gl-transition-colors', 'hover:gl-border-strong', 'active:gl-focus'];

const PILL_CLASSES = [
  'gl-border',
  'gl-inline-flex',
  '!gl-w-fit',
  'gl-items-center',
  'gl-gap-2',
  'gl-rounded-r-[1rem]',
  'gl-rounded-tl-[1rem]',
  'gl-border-default',
  'gl-bg-default',
  'gl-p-4',
  ...HOVER_CLASSES,
];

const EXPANDED_CARD_CLASSES = [
  'gl-flex',
  'gl-w-full',
  'gl-flex-col',
  'gl-gap-3',
  'gl-rounded-r-[1rem]',
  'gl-rounded-tl-[1rem]',
  'gl-border',
  'gl-border-default',
  'gl-bg-default',
  'gl-p-4',
  ...HOVER_CLASSES,
];

export default {
  PILL_CLASSES,
  name: 'MessageToolStartFlow',
  components: {
    AgentStatusIcon,
    GlAnimatedLoaderIcon,
    GlIcon,
    GlLoadingIcon,
    TodoChecklist,
  },
  apollo: {
    checkpointMessages: {
      query: getWorkflowLatestCheckpointQuery,
      variables() {
        return { workflowId: convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, this.workflowId) };
      },
      skip() {
        return !this.workflowId;
      },
      pollInterval: POLL_INTERVAL,
      update(data) {
        return WorkflowUtils.parseWorkflowData(data)?.duoMessages ?? [];
      },
      result({ data }) {
        this.workflowStatus = WorkflowUtils.parseWorkflowStatus(data);
        if (isTerminalStatus(this.workflowStatus)) {
          this.$apollo.queries.checkpointMessages.stopPolling();
        }
      },
      error(error) {
        captureExceptionForDuoChat(error);
      },
    },
  },
  props: {
    message: {
      required: true,
      type: Object,
    },
  },
  data() {
    return {
      workflowStatus: '',
      checkpointMessages: [],
    };
  },
  computed: {
    toolResponse() {
      try {
        return JSON.parse(this.message.tool_info?.tool_response?.content ?? '{}');
      } catch {
        return {};
      }
    },
    flowName() {
      return this.toolResponse.flow_name ?? '';
    },
    workflowId() {
      return this.toolResponse.workflow_id ?? null;
    },
    sessionUrl() {
      return this.toolResponse.session_url ?? null;
    },
    toolName() {
      return this.message.tool_info?.name ?? '';
    },
    humanStatus() {
      return (this.workflowStatus ?? '').toLowerCase().replaceAll('_', ' ');
    },
    flowPlan() {
      const messages = WorkflowUtils.normalizeDuoMessages(this.checkpointMessages);
      return WorkflowUtils.findLatestTodoToolInfo(messages);
    },
    hasPlan() {
      return Boolean(this.flowPlan);
    },
    isTerminal() {
      return isTerminalStatus(this.workflowStatus);
    },
    latestMessage() {
      return last(this.checkpointMessages) ?? null;
    },
    latestActivity() {
      if (!this.latestMessage) return null;
      return getMessageData(this.latestMessage)?.title ?? null;
    },
    activityTitle() {
      return this.latestActivity ?? s__('DuoAgenticChat|Starting the session. Please wait');
    },
    activityDetail() {
      const content = this.latestMessage?.content?.trim();
      return content ? truncate(content, ACTIVITY_DETAIL_MAX_LENGTH) : '';
    },
    toolInfoName() {
      return parseToolInfo(this.latestMessage?.toolInfo)?.name ?? '';
    },
    showActivity() {
      return !this.hasPlan && !this.isTerminal;
    },
    isExpanded() {
      return this.hasPlan || this.showActivity;
    },
    isLoading() {
      return Boolean(this.workflowId) && !this.workflowStatus;
    },
    wrapperProps() {
      const baseClasses = this.isExpanded ? EXPANDED_CARD_CLASSES : PILL_CLASSES;
      return {
        class: baseClasses,
      };
    },
  },
  methods: {
    openSession() {
      EventsTracker.trackClickThroughFlowWidget({ toolName: this.toolName });
      eventHub.$emit(SHOW_SESSION, { id: this.workflowId });
    },
  },
};
</script>

<template>
  <div
    v-if="isLoading"
    :class="$options.PILL_CLASSES"
    class="gl-justify-center"
    data-testid="start-flow-loading"
  >
    <gl-loading-icon size="sm" inline />
  </div>
  <button
    v-else
    type="button"
    class="gl-text-left"
    v-bind="wrapperProps"
    data-testid="start-flow-message"
    @click="openSession"
  >
    <div class="gl-flex gl-items-center gl-gap-2">
      <span aria-hidden="true">
        <agent-status-icon :status="workflowStatus" :human-status="humanStatus" />
      </span>
      <span class="gl-mb-1" :class="{ 'gl-flex-1': isExpanded && sessionUrl }">
        {{ flowName }}<template v-if="workflowId"> #{{ workflowId }}</template>
        <strong class="gl-ml-1">{{ humanStatus }}</strong>
      </span>
      <gl-icon v-if="sessionUrl" name="chevron-right" aria-hidden="true" />
    </div>
    <todo-checklist
      v-if="hasPlan"
      :tool-info="flowPlan"
      :flow-finished="isTerminal"
      :bordered="false"
    />
    <div
      v-else-if="showActivity"
      class="gl-border-t -gl-mx-4 -gl-mb-4 gl-rounded-br-[1rem] gl-border-default gl-bg-subtle gl-px-4 gl-pb-4 gl-pt-3"
      data-testid="latest-activity"
    >
      <div class="gl-flex gl-items-center gl-gap-2">
        <strong class="gl-text-strong">{{ activityTitle }}</strong>
        <gl-animated-loader-icon is-on class="gl-shrink-0" />
      </div>
      <p
        v-if="activityDetail"
        class="gl-m-0 gl-mt-1 gl-text-subtle gl-wrap-anywhere"
        data-testid="latest-activity-detail"
      >
        <template v-if="toolInfoName"
          ><span data-testid="latest-activity-tool-name">{{ toolInfoName }}</span>
          <span aria-hidden="true">—</span> </template
        >{{ activityDetail }}
      </p>
    </div>
  </button>
</template>
