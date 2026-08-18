<script>
import { GlModalDirective, GlTooltipDirective, GlButton, GlDisclosureDropdown } from '@gitlab/ui';
import { v4 as uuidv4 } from 'uuid';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import toast from '~/vue_shared/plugins/global_toast';
import { sendDuoChatCommand } from 'ee/ai/utils';
import { i18n } from 'ee/ai/constants';
import vulnerabilityStateMutations from 'ee/security_dashboard/graphql/mutate_vulnerability_state';
import vulnerabilitiesSeverityOverrideMutation from 'ee/security_dashboard/graphql/mutations/vulnerabilities_severity_override.mutation.graphql';
import StatusBadge from 'ee/vue_shared/security_reports/components/status_badge.vue';
import { latestNonClosedMergeRequest } from 'ee/vue_shared/security_reports/utils';
import { createAlert, VARIANT_SUCCESS } from '~/alert';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  TYPENAME_USER,
  TYPENAME_VULNERABILITY,
  TYPENAME_PROJECT,
} from '~/graphql_shared/constants';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import axios from '~/lib/utils/axios_utils';
import { convertObjectPropsToSnakeCase } from '~/lib/utils/common_utils';
import download from '~/lib/utils/downloader';
import { visitUrl } from '~/lib/utils/url_utility';
import { projectAutomateAgentSessionPath } from 'ee/lib/utils/path_helpers/project';
import UsersCache from '~/lib/utils/users_cache';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { sprintf, s__ } from '~/locale';
import Api from 'ee/api';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import getConfiguredFlows from 'ee/ai/graphql/get_configured_flows.query.graphql';
import aiResolveVulnerability from '../graphql/ai_resolve_vulnerability.mutation.graphql';
import { VULNERABILITY_STATE_OBJECTS, FEEDBACK_TYPES } from '../constants';
import {
  hasActiveAiFpDetection,
  isAiDetectedAsFalsePositive,
  isSastVrApplicable,
} from '../flag_helpers';
import { normalizeGraphQLVulnerability, normalizeGraphQLLastStateTransition } from '../helpers';
import ResolutionAlert from './resolution_alert.vue';
import StatusDescription from './status_description.vue';
import VulnerabilityActionsDropdown from './vulnerability_actions_dropdown.vue';
import StateModal from './state_modal.vue';
import SeverityModal from './severity_modal.vue';

export const VULNERABILITY_STATE_MODAL_ID = 'vulnerability-state-modal';
export const VULNERABILITY_SEVERITY_MODAL_ID = 'vulnerability-severity-modal';

export const CREATE_MR_AI_ACTION = {
  name: s__('ciReport|Resolve with merge request'),
  tagline: s__('ciReport|Use GitLab Duo AI to generate a merge request with a suggested solution'),
  action: 'start-subscription',
  icon: 'tanuki-ai',
  category: 'primary',
};

export const EXPLAIN_VULNERABILITY_AI_ACTION = {
  name: s__('ciReport|Explain vulnerability'),
  tagline: s__(
    'ciReport|Use GitLab Duo AI to provide insights about the vulnerability and suggested solutions',
  ),
  action: 'explain-vulnerability',
  icon: 'tanuki-ai',
  category: 'primary',
};

export const CLIENT_SUBSCRIPTION_ID = uuidv4();

export default {
  name: 'VulnerabilityHeader',
  i18n,
  components: {
    GlButton,
    GlDisclosureDropdown,
    StatusBadge,
    ResolutionAlert,
    StatusDescription,
    StateModal,
    SeverityModal,
    VulnerabilityActionsDropdown,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    GlModal: GlModalDirective,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagMixin()],
  inject: [
    'duoAgentPlatformAvailable',
    'duoSecretDetectionFpEnabled',
    'duoSastFalsePositiveDetectionEnabled',
  ],
  props: {
    vulnerability: {
      type: Object,
      required: true,
    },
  },
  emits: ['vulnerability-severity-change', 'vulnerability-state-change'],
  data() {
    return {
      isProcessingAction: false,
      isLoadingVulnerability: false,
      isLoadingUser: false,
      user: undefined,
      errorAlert: null,
      aiCatalogItemConsumerId: null,
      resolutionAiCatalogItemConsumerId: null,
      secretDetectionAiCatalogItemConsumerId: null,
    };
  },
  computed: {
    canDownloadPatch() {
      return (
        this.vulnerability.state !== VULNERABILITY_STATE_OBJECTS.resolved.state &&
        !this.mergeRequest &&
        this.hasRemediation
      );
    },
    hasRemediation() {
      return this.vulnerability.remediations?.[0]?.diff?.length > 0;
    },
    mergeRequest() {
      return latestNonClosedMergeRequest(this.vulnerability.mergeRequestLinks);
    },
    canCreateMergeRequest() {
      return !this.mergeRequest && this.vulnerability.createMrUrl && this.hasRemediation;
    },
    canResolveWithSingleShotAi() {
      return (
        this.glAbilities.resolveVulnerabilityWithAi &&
        this.vulnerability.aiResolutionAvailable &&
        !this.detectedAsFalsePositive
      );
    },
    canResolveWithAgenticAi() {
      return isSastVrApplicable({
        vulnerability: this.vulnerability,
        duoAgentPlatformAvailable: this.duoAgentPlatformAvailable,
        agenticSastVrUi: this.glFeatures.agenticSastVrUi,
      });
    },
    showSeverityModal() {
      return !this.glFeatures.hideVulnerabilitySeverityOverride;
    },
    canExplainWithAi() {
      return this.duoAgentPlatformAvailable && this.vulnerability.aiExplanationAvailable;
    },
    canRunAiFalsePositiveDetection() {
      return (
        this.canAdminVulnerability &&
        this.duoAgentPlatformAvailable &&
        this.duoSastFalsePositiveDetectionEnabled &&
        this.vulnerability.reportType === 'sast' &&
        !this.hasActiveFpDetection
      );
    },
    canRunSecretDetectionFalsePositiveDetection() {
      return (
        this.canAdminVulnerability &&
        this.duoAgentPlatformAvailable &&
        this.glFeatures.duoSecretDetectionFalsePositive &&
        this.duoSecretDetectionFpEnabled &&
        this.vulnerability.reportType === 'secret_detection' &&
        !this.hasActiveFpDetection
      );
    },
    showResolutionAlert() {
      return (
        this.vulnerability.resolvedOnDefaultBranch &&
        this.vulnerability.state !== VULNERABILITY_STATE_OBJECTS.resolved.state
      );
    },
    detectedAsFalsePositive() {
      return isAiDetectedAsFalsePositive(this.vulnerability.latestFlag);
    },
    hasActiveFpDetection() {
      return hasActiveAiFpDetection(this.vulnerability.latestFlag);
    },
    dismissalReason() {
      return this.vulnerability.stateTransitions?.at(-1)?.dismissalReason;
    },
    latestComment() {
      return this.vulnerability.stateTransitions?.at(-1)?.comment;
    },
    canAdminVulnerability() {
      return this.vulnerability.canAdmin;
    },
    vulnerabilityGraphqlId() {
      return convertToGraphQLId(TYPENAME_VULNERABILITY, this.vulnerability.id);
    },
    vulnerabilityProjectId() {
      return this.vulnerability.project.id;
    },
    editVulnerabilityActions() {
      return [
        {
          text: s__('SecurityReports|Change status'),
          action: () => this.$root.$emit(BV_SHOW_MODAL, VULNERABILITY_STATE_MODAL_ID),
        },
        {
          text: s__('SecurityReports|Change severity'),
          action: () => this.$root.$emit(BV_SHOW_MODAL, VULNERABILITY_SEVERITY_MODAL_ID),
        },
      ];
    },
  },
  watch: {
    'vulnerability.state': {
      immediate: true,
      handler(state) {
        const id = this.vulnerability[`${state}ById`];

        if (!id) {
          return;
        }

        this.isLoadingUser = true;

        UsersCache.retrieveById(id)
          .then((userData) => {
            this.user = userData;
          })
          .catch(() => {
            createAlert({
              message: s__('VulnerabilityManagement|Something went wrong, could not get user.'),
            });
          })
          .finally(() => {
            this.isLoadingUser = false;
          });
      },
    },
  },
  apollo: {
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      aiCompletionResponse: {
        query: aiResponseSubscription,
        skip: true, // We manually start and stop the subscription.
        variables() {
          return {
            resourceId: this.vulnerabilityGraphqlId,
            userId: convertToGraphQLId(TYPENAME_USER, gon.current_user_id),
            clientSubscriptionId: CLIENT_SUBSCRIPTION_ID,
          };
        },
        async result({ data }) {
          const { errors, content } = data.aiCompletionResponse || {};
          // Once the subscription is ready, we will receive a null aiCompletionResponse. Once we get this, it's safe to
          // start the AI request mutation. Otherwise, it's possible that backend will send the AI response before the
          // subscription is ready, and the AI response will be lost.
          if (!data.aiCompletionResponse) {
            this.resolveVulnerability();
          } else if (errors?.length) {
            this.handleError(errors[0]);
          } else if (content) {
            this.stopSubscription();
            visitUrl(content);
          }
        },
        error(e) {
          this.handleError(e?.message || e.toString());
        },
      },
    },
    aiCatalogItemConsumerId: {
      query: getConfiguredFlows,
      variables() {
        return {
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.vulnerabilityProjectId),
          foundationalFlowReference: 'sast_fp_detection/v1',
        };
      },
      skip() {
        return !this.vulnerabilityProjectId;
      },
      update(data) {
        const configuredItems = data.aiCatalogConfiguredItems?.nodes || [];
        if (configuredItems.length > 0) {
          return data.aiCatalogConfiguredItems.nodes[0].id;
        }
        return null;
      },
      error(error) {
        Sentry.captureException(error);
      },
    },
    resolutionAiCatalogItemConsumerId: {
      query: getConfiguredFlows,
      variables() {
        return {
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.vulnerability.project.id),
          foundationalFlowReference: 'resolve_sast_vulnerability/v1',
        };
      },
      skip() {
        return !this.vulnerability.project.id;
      },
      update(data) {
        const configuredItems = data.aiCatalogConfiguredItems?.nodes || [];
        if (configuredItems.length > 0) {
          return data.aiCatalogConfiguredItems.nodes[0].id;
        }
        return null;
      },
      error(error) {
        Sentry.captureException(error);
        createAlert({
          message: s__(
            'VulnerabilityManagement|Something went wrong, could not fetch AI resolution configuration.',
          ),
        });
      },
    },
    secretDetectionAiCatalogItemConsumerId: {
      query: getConfiguredFlows,
      variables() {
        return {
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.vulnerabilityProjectId),
          foundationalFlowReference: 'secrets_fp_detection/v1',
        };
      },
      skip() {
        return !this.vulnerabilityProjectId;
      },
      update(data) {
        const configuredItems = data.aiCatalogConfiguredItems?.nodes || [];
        if (configuredItems.length > 0) {
          return configuredItems[0].id;
        }
        return null;
      },
      error(error) {
        Sentry.captureException(error);
        createAlert({
          message: s__(
            'VulnerabilityManagement|Something went wrong, could not fetch AI secret detection configuration.',
          ),
        });
      },
    },
  },
  methods: {
    async changeVulnerabilityState({ action, dismissalReason, comment }) {
      this.isLoadingVulnerability = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: vulnerabilityStateMutations[action],
          variables: {
            id: convertToGraphQLId(TYPENAME_VULNERABILITY, this.vulnerability.id),
            dismissalReason,
            comment,
          },
        });
        const [queryName] = Object.keys(data);

        this.$emit('vulnerability-state-change', {
          ...this.vulnerability,
          ...normalizeGraphQLVulnerability(data[queryName].vulnerability),
          ...normalizeGraphQLLastStateTransition(data[queryName].vulnerability, this.vulnerability),
        });
      } catch (error) {
        createAlert({
          error,
          captureError: true,
          message: s__(
            'VulnerabilityManagement|Something went wrong, could not update vulnerability state.',
          ),
        });
      } finally {
        this.isLoadingVulnerability = false;
      }
    },
    async changeVulnerabilitySeverity({ newSeverity, comment }) {
      this.isLoadingVulnerability = true;

      try {
        const {
          data: {
            vulnerabilitiesSeverityOverride: {
              vulnerabilities: [{ severity }],
            },
          },
        } = await this.$apollo.mutate({
          mutation: vulnerabilitiesSeverityOverrideMutation,
          variables: {
            vulnerabilityIds: [convertToGraphQLId(TYPENAME_VULNERABILITY, this.vulnerability.id)],
            severity: newSeverity.toUpperCase(),
            comment,
          },
        });

        this.$emit('vulnerability-severity-change', {
          ...this.vulnerability,
          severity: severity.toLowerCase(),
        });
        toast(
          sprintf(s__('VulnerabilityManagement|Vulnerability set to %{severity} severity'), {
            severity: severity.toLowerCase(),
          }),
        );
      } catch (error) {
        Sentry.captureException(error);
        createAlert({
          error,
          captureError: true,
          message: s__(
            'VulnerabilityManagement|Something went wrong, could not update vulnerability severity.',
          ),
        });
      } finally {
        this.isLoadingVulnerability = false;
      }
    },
    explainVulnerability() {
      sendDuoChatCommand({
        // eslint-disable-next-line @gitlab/no-hardcoded-urls -- Duo Chat command, not a navigational URL
        question: '/vulnerability_explain',
        resourceId: this.vulnerabilityGraphqlId,
        agenticPrompt: this.$options.i18n.AGENTIC_PROMPT_EXPLAIN_VULNERABILITY,
      });
    },
    resolveVulnerability() {
      this.$apollo
        .mutate({
          mutation: aiResolveVulnerability,
          variables: {
            clientSubscriptionId: CLIENT_SUBSCRIPTION_ID,
            resourceId: this.vulnerabilityGraphqlId,
          },
        })
        .then(({ data }) => {
          const error = data.aiAction.errors[0];
          if (error) {
            this.handleError(error);
          }
        })
        .catch((e) => {
          this.handleError(e.message);
        });
    },
    createMergeRequest() {
      this.isProcessingAction = true;

      const {
        reportType: category,
        pipeline: { sourceBranch },
        uuid,
      } = this.vulnerability;

      // note: this direct API call will be replaced when migrating the vulnerability details page to GraphQL
      // related epic: https://gitlab.com/groups/gitlab-org/-/epics/3657
      axios
        .post(this.vulnerability.createMrUrl, {
          vulnerability_feedback: {
            feedback_type: FEEDBACK_TYPES.MERGE_REQUEST,
            category,
            finding_uuid: uuid,
            vulnerability_data: {
              ...convertObjectPropsToSnakeCase(this.vulnerability),
              category,
              target_branch: sourceBranch,
            },
          },
        })
        .then(({ data }) => {
          const mergeRequestPath = data.merge_request_links.at(-1).merge_request_path;

          visitUrl(mergeRequestPath);
        })
        .catch(() => {
          this.isProcessingAction = false;
          createAlert({
            message: s__(
              'ciReport|There was an error creating the merge request. Please try again.',
            ),
          });
        });
    },
    downloadPatch() {
      download({
        fileData: this.vulnerability.remediations[0].diff,
        fileName: `remediation.patch`,
      });
    },
    startSubscription() {
      this.isProcessingAction = true;
      this.errorAlert?.dismiss();
      this.$apollo.subscriptions.aiCompletionResponse.start();
    },
    stopSubscription() {
      this.$apollo.subscriptions.aiCompletionResponse.stop();
    },
    triggerResolution() {
      Api.triggerVulnerabilityResolution(
        this.vulnerability.id,
        this.vulnerabilityProjectId,
        this.resolutionAiCatalogItemConsumerId
          ? getIdFromGraphQLId(this.resolutionAiCatalogItemConsumerId)
          : null,
      )
        .then(({ data }) => {
          createAlert({
            variant: VARIANT_SUCCESS,
            message: s__(
              'VulnerabilityManagement|You can track the progress in the AI session via Automate → Sessions.',
            ),
            primaryButton: {
              text: s__('VulnerabilityManagement|View agent session'),
              link: projectAutomateAgentSessionPath(
                this.vulnerability.project.fullPath,
                data.id.toString(),
              ),
            },
          });
        })
        .catch((error) => {
          createAlert({
            captureError: true,
            error,
            message: s__(
              'VulnerabilityManagement|Something went wrong, could not start Duo agent session.',
            ),
          });
        });
    },
    runAiFalsePositiveDetection() {
      this.isProcessingAction = true;

      Api.triggerFalsePositiveDetection(
        this.vulnerability.id,
        this.vulnerabilityProjectId,
        getIdFromGraphQLId(this.aiCatalogItemConsumerId),
      )
        .then(({ data }) => {
          if (data.workload && !data.workload.id && data.workload.message) {
            createAlert({
              message: data.workload.message,
              captureError: true,
              error: new Error(data.workload.message),
            });
            return;
          }

          createAlert({
            variant: VARIANT_SUCCESS,
            message: s__('AI|GitLab Duo False Positive Detection workflow started successfully'),
            primaryButton: {
              text: s__('VulnerabilityManagement|View agent session'),
              link: projectAutomateAgentSessionPath(
                this.vulnerability.project.fullPath,
                data.id.toString(),
              ),
            },
          });
        })
        .catch((error) => {
          const errorMessage =
            error.response?.data?.message ||
            s__('AI|Error occurred when starting the AI False Positive Detection workflow.');

          createAlert({
            message: errorMessage,
            captureError: true,
            error,
          });
        })
        .finally(() => {
          this.isProcessingAction = false;
        });
    },
    runSecretDetectionFalsePositiveDetection() {
      this.isProcessingAction = true;

      Api.triggerSecretDetectionFalsePositiveDetection(
        this.vulnerability.id,
        this.vulnerabilityProjectId,
        getIdFromGraphQLId(this.secretDetectionAiCatalogItemConsumerId),
      )
        .then(({ data }) => {
          if (data.workload && !data.workload.id && data.workload.message) {
            createAlert({
              message: data.workload.message,
              captureError: true,
              error: new Error(data.workload.message),
            });
            return;
          }

          createAlert({
            variant: VARIANT_SUCCESS,
            message: s__('AI|GitLab Duo False Positive Detection workflow started successfully'),
            primaryButton: {
              text: s__('VulnerabilityManagement|View agent session'),
              link: projectAutomateAgentSessionPath(
                this.vulnerability.project.fullPath,
                data.id?.toString(),
              ),
            },
          });
        })
        .catch((error) => {
          const errorMessage =
            error.response?.data?.message ||
            s__('AI|Error occurred when starting the AI False Positive Detection workflow.');

          createAlert({
            message: errorMessage,
            captureError: true,
            error,
          });
        })
        .finally(() => {
          this.isProcessingAction = false;
        });
    },
    handleError(error) {
      this.stopSubscription();
      this.isProcessingAction = false;
      this.errorAlert = createAlert({ message: error });
    },
  },
  VULNERABILITY_STATE_MODAL_ID,
  VULNERABILITY_SEVERITY_MODAL_ID,
};
</script>

<template>
  <div data-testid="vulnerability-header">
    <resolution-alert
      v-if="showResolutionAlert"
      :vulnerability-id="vulnerability.id"
      :default-branch-name="vulnerability.projectDefaultBranch"
    />
    <div class="detail-page-header">
      <div class="detail-page-header-body" data-testid="vulnerability-detail-body">
        <status-badge
          :state="vulnerability.state"
          :loading="isLoadingVulnerability"
          class="gl-mr-3"
        />
        <status-description
          :vulnerability="vulnerability"
          :user="user"
          :is-loading-vulnerability="isLoadingVulnerability"
          :is-loading-user="isLoadingUser"
        />
      </div>

      <div class="detail-page-header-actions gl-flex gl-flex-wrap gl-items-center gl-gap-3">
        <template v-if="showSeverityModal">
          <gl-disclosure-dropdown
            :disabled="!canAdminVulnerability"
            :toggle-text="s__('SecurityReports|Edit vulnerability')"
            :items="editVulnerabilityActions"
            :loading="isLoadingVulnerability"
            data-testid="edit-vulnerability-dropdown"
          />
          <severity-modal
            :modal-id="$options.VULNERABILITY_SEVERITY_MODAL_ID"
            :severity="vulnerability.severity"
            @change="changeVulnerabilitySeverity"
          />
        </template>
        <template v-else>
          <gl-button
            v-gl-modal="$options.VULNERABILITY_STATE_MODAL_ID"
            :disabled="!canAdminVulnerability || isLoadingVulnerability"
            data-testid="change-status-btn"
            >{{ s__('SecurityReports|Change status') }}</gl-button
          >
        </template>
        <state-modal
          :modal-id="$options.VULNERABILITY_STATE_MODAL_ID"
          :state="vulnerability.state"
          :dismissal-reason="dismissalReason"
          :comment="latestComment"
          @change="changeVulnerabilityState"
        />
        <vulnerability-actions-dropdown
          data-testid="vulnerability-actions-dropdown"
          :loading="isProcessingAction"
          :show-download-patch="canDownloadPatch"
          :show-create-merge-request="canCreateMergeRequest"
          :show-resolve-with-single-shot-ai="canResolveWithSingleShotAi"
          :show-resolve-with-agentic-ai="canResolveWithAgenticAi"
          :show-explain-with-ai="canExplainWithAi"
          :can-run-ai-false-positive-detection="canRunAiFalsePositiveDetection"
          :can-run-secret-detection-false-positive-detection="
            canRunSecretDetectionFalsePositiveDetection
          "
          :ai-resolution-enabled="vulnerability.aiResolutionEnabled"
          :show-public-project-warning="vulnerability.belongsToPublicProject"
          :merge-requests="vulnerability.mergeRequestLinks"
          @create-merge-request="createMergeRequest"
          @download-patch="downloadPatch"
          @explain-vulnerability="explainVulnerability"
          @resolve-vulnerability="startSubscription"
          @agentic-resolve-vulnerability="triggerResolution"
          @run-ai-false-positive-detection="runAiFalsePositiveDetection"
          @run-secret-detection-false-positive-detection="runSecretDetectionFalsePositiveDetection"
        />
      </div>
    </div>
  </div>
</template>
