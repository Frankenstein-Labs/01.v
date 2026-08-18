<script>
import { GlButton, GlDisclosureDropdownItem, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import getDuoWorkflowStatusCheck from 'ee/ai/graphql/get_duo_workflow_status_check.query.graphql';
import getConfiguredFlows from 'ee/ai/graphql/get_configured_flows.query.graphql';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';
import { s__, __ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { buildApiUrl } from '~/api/api_utils';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

const FLOW_WEB_ENVIRONMENT = 'web';
const INIT_ERROR_MESSAGE = __('Something went wrong');

export default {
  name: 'DuoWorkflowAction',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
    GlDisclosureDropdownItem,
    GlIcon,
  },
  mixins: [glSlotsMixin],
  inject: {
    currentRef: {
      default: null,
      type: String,
    },
  },
  props: {
    projectPath: {
      type: String,
      required: true,
    },
    hoverMessage: {
      type: String,
      required: false,
      default: '',
    },
    goal: {
      type: String,
      required: true,
    },
    workflowDefinition: {
      type: String,
      required: true,
    },
    agentPrivileges: {
      type: Array,
      required: false,
      default: () => [1, 2],
    },
    promptValidatorRegex: {
      type: RegExp,
      required: false,
      default: null,
    },
    size: {
      type: String,
      default: 'small',
      required: false,
      validator: (size) => ['small', 'medium', 'large'].includes(size),
    },
    variant: {
      type: String,
      default: 'default',
      required: false,
      validator: (variant) => ['default', 'confirm', 'danger', 'link'].includes(variant),
    },
    category: {
      type: String,
      default: 'primary',
      required: false,
      validator: (category) => ['primary', 'secondary', 'tertiary'].includes(category),
    },
    sourceBranch: {
      type: String,
      required: false,
      default: null,
    },
    workItemIid: {
      type: [String, Number],
      required: false,
      default: null,
    },
    mergeRequestId: {
      type: [String, Number],
      required: false,
      default: null,
    },
    additionalContext: {
      type: Array,
      required: false,
      default: () => [],
    },
    source: {
      type: String,
      required: false,
      default: null,
    },
    renderAs: {
      type: String,
      default: 'button',
      required: false,
      validator: (v) => ['button', 'dropdown-item'].includes(v),
    },
  },
  emits: ['agent-flow-started', 'prompt-validation-error', 'triggering', 'triggered'],
  data() {
    return {
      isStartingFlow: false,
      duoWorkflowData: null,
      aiCatalogItemConsumerId: null,
    };
  },
  computed: {
    duoWorkflowInvokePath() {
      return buildApiUrl(`/api/:version/ai/duo_workflows/workflows`);
    },
    isDuoActionEnabled() {
      return (
        this.duoWorkflowData?.isDuoActionEnabled &&
        this.duoWorkflowData?.projectId &&
        this.isFlowEnabledInSettings
      );
    },
    projectId() {
      return this.duoWorkflowData?.projectId || null;
    },
    projectGid() {
      return this.duoWorkflowData?.projectGid || null;
    },
    isFlowEnabledInSettings() {
      return Boolean(this.aiCatalogItemConsumerId);
    },
  },
  apollo: {
    duoWorkflowData: {
      query: getDuoWorkflowStatusCheck,
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      context: {
        featureCategory: 'duo_agent_platform',
      },
      skip() {
        return !this.projectPath;
      },
      update(data) {
        if (data.project) {
          const { id, duoWorkflowStatusCheck } = data.project;

          return {
            isDuoActionEnabled: this.duoActionEnabledFromStatusCheck(duoWorkflowStatusCheck),
            projectId: getIdFromGraphQLId(id),
            projectGid: id,
          };
        }
        return null;
      },
      error(error) {
        createAlert({
          message: error?.message || INIT_ERROR_MESSAGE,
          captureError: true,
          error,
        });
      },
    },
    aiCatalogItemConsumerId: {
      query: getConfiguredFlows,
      variables() {
        return {
          projectId: this.projectGid,
          foundationalFlowReference: this.workflowDefinition,
        };
      },
      context: {
        featureCategory: 'duo_agent_platform',
      },
      skip() {
        return !this.projectGid || !this.workflowDefinition;
      },
      update(data) {
        const configuredItems = data.aiCatalogConfiguredItems?.nodes || [];
        if (configuredItems.length > 0) {
          return data.aiCatalogConfiguredItems.nodes[0].id;
        }

        return null;
      },
      error(error) {
        createAlert({
          message: error?.message || INIT_ERROR_MESSAGE,
          captureError: true,
          error,
        });
      },
    },
  },
  methods: {
    duoActionEnabledFromStatusCheck(duoWorkflowStatusCheck) {
      if (duoWorkflowStatusCheck) {
        const { enabled, remoteFlowsEnabled, createDuoWorkflowForCiAllowed } =
          duoWorkflowStatusCheck;

        return enabled && remoteFlowsEnabled && createDuoWorkflowForCiAllowed !== false;
      }
      return false;
    },
    startWorkflow() {
      if (this.isStartingFlow) return;

      if (this.promptValidatorRegex && !this.promptValidatorRegex.test(this.goal)) {
        this.$emit('prompt-validation-error', this.goal);
        return;
      }

      const requestData = {
        project_id: this.projectId,
        start_workflow: true,
        goal: this.goal,
        environment: FLOW_WEB_ENVIRONMENT,
        workflow_definition: this.workflowDefinition,
        agent_privileges: this.agentPrivileges,
        additional_context: this.additionalContext,
      };

      if (this.source) {
        requestData.source = this.source;
      }

      if (this.aiCatalogItemConsumerId) {
        requestData.ai_catalog_item_consumer_id = getIdFromGraphQLId(this.aiCatalogItemConsumerId);
      }

      if (this.sourceBranch) {
        requestData.source_branch = this.sourceBranch;
      } else if (this.currentRef) {
        requestData.source_branch = this.currentRef;
      }

      if (this.workItemIid) {
        requestData.issue_id = this.workItemIid;
      }

      if (this.mergeRequestId) {
        requestData.merge_request_id = this.mergeRequestId;
      }

      this.isStartingFlow = true;
      this.$emit('triggering');

      axios
        .post(this.duoWorkflowInvokePath, requestData)
        .then(({ data }) => {
          if (data.workload && !data.workload.id && data.workload.message) {
            throw new Error(data.workload.message);
          }

          this.$emit('agent-flow-started', data);

          eventHub.$emit(SHOW_SESSION, data);
        })
        .catch((error) => {
          const errorMessage =
            error.response?.data?.message ||
            s__('DuoAgentPlatform|Error occurred when starting the flow.');

          createAlert({
            message: errorMessage,
            captureError: true,
            error,
            renderMessageHTML: true,
          });
        })
        .finally(() => {
          this.isStartingFlow = false;
          this.$emit('triggered');
        });
    },
  },
  dropdownItemExtraAttrs: {
    text: __('Duo workflow'),
    extraAttrs: { class: '!gl-whitespace-nowrap' },
  },
};
</script>
<template>
  <gl-button
    v-if="isDuoActionEnabled && renderAs === 'button'"
    v-gl-tooltip.hover.focus.viewport="{ placement: 'top' }"
    :category="category"
    icon="tanuki-ai"
    :loading="isStartingFlow"
    :title="hoverMessage"
    :size="size"
    :variant="variant"
    data-testid="duo-workflow-action-button"
    @click="startWorkflow"
    ><template v-if="glSlots().default" #default><slot></slot></template
  ></gl-button>
  <gl-disclosure-dropdown-item
    v-else-if="isDuoActionEnabled && renderAs === 'dropdown-item'"
    :item="$options.dropdownItemExtraAttrs"
    @action="startWorkflow"
  >
    <template #list-item><gl-icon name="tanuki-ai" class="gl-mr-2" /><slot></slot></template>
  </gl-disclosure-dropdown-item>
</template>
