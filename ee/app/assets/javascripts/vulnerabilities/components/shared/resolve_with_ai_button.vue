<script>
import { GlButton } from '@gitlab/ui';
import { v4 as uuidv4 } from 'uuid';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import aiResolveVulnerability from 'ee/vulnerabilities/graphql/ai_resolve_vulnerability.mutation.graphql';
import securityFindingCreateVulnerability from 'ee/vulnerabilities/graphql/security_finding_create_vulnerability.mutation.graphql';
import ResolveWithAiInfoPopover from 'ee/vulnerabilities/components/shared/resolve_with_ai_info_popover.vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import {
  TYPENAME_USER,
  TYPENAME_MERGE_REQUEST,
  TYPENAME_VULNERABILITY,
} from '~/graphql_shared/constants';

const CLIENT_SUBSCRIPTION_ID = uuidv4();

export default {
  name: 'ResolveWithAiButton',
  components: {
    GlButton,
    ResolveWithAiInfoPopover,
  },
  props: {
    mergeRequestId: {
      type: [String, Number],
      required: false,
      default: null,
    },
    // required only when there is no vulnerabilityId yet, so we can create a vulnerability from the finding first
    findingUuid: {
      type: String,
      required: false,
      default: null,
    },
    // some findings don't have a vulnerability yet, so this is not required
    vulnerabilityId: {
      type: [String, Number],
      required: false,
      default: null,
    },
    showPublicProjectWarning: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['resolve-start', 'success', 'error'],
  data() {
    return {
      isResolving: false,
      createdVulnerabilityId: null,
    };
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
            this.resolveVulnerabilityWithAi();
          } else if (errors?.length) {
            this.handleError(errors[0]);
          } else if (content) {
            this.stopResolveWithAISubscription();
            this.$emit('success', content);
          }
        },
        error(e) {
          this.handleError(e?.message || e.toString());
        },
      },
    },
  },
  computed: {
    mergeRequestGraphQLId() {
      return convertToGraphQLId(TYPENAME_MERGE_REQUEST, this.mergeRequestId);
    },
    vulnerabilityGraphqlId() {
      if (this.createdVulnerabilityId) {
        return this.createdVulnerabilityId;
      }
      if (this.vulnerabilityId) {
        return convertToGraphQLId(TYPENAME_VULNERABILITY, this.vulnerabilityId);
      }

      return null;
    },
  },
  methods: {
    createVulnerabilityForFinding() {
      return this.$apollo
        .mutate({
          mutation: securityFindingCreateVulnerability,
          variables: {
            uuid: this.findingUuid,
          },
        })
        .then(({ data }) => {
          this.createdVulnerabilityId = data.securityFindingCreateVulnerability.vulnerability.id;
        });
    },
    resolveVulnerabilityWithAi() {
      this.$apollo
        .mutate({
          mutation: aiResolveVulnerability,
          variables: {
            clientSubscriptionId: CLIENT_SUBSCRIPTION_ID,
            resourceId: this.vulnerabilityGraphqlId,
            ...(this.mergeRequestId && { vulnerableMergeRequestId: this.mergeRequestGraphQLId }),
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
    startResolveWithAISubscription() {
      this.$apollo.subscriptions.aiCompletionResponse.start();
    },
    stopResolveWithAISubscription() {
      this.isResolving = false;
      this.$apollo.subscriptions.aiCompletionResponse.stop();
    },
    async handleClick() {
      this.isResolving = true;
      // if there is no vulnerability then kick of the mutation to create one
      if (!this.vulnerabilityId) {
        try {
          await this.createVulnerabilityForFinding();
        } catch (e) {
          this.handleError(e);
          return;
        }
      }
      this.startResolveWithAISubscription();
      this.$emit('resolve-start');
    },
    handleError(e) {
      // The full error handling will be done in https://gitlab.com/gitlab-org/gitlab/-/issues/481792
      this.stopResolveWithAISubscription();
      this.$emit('error', e);
    },
  },
};
</script>

<template>
  <gl-button
    id="resolve-with-ai-button"
    data-testid="resolve-with-ai"
    variant="confirm"
    icon="tanuki-ai"
    :loading="isResolving"
    @click="handleClick"
  >
    {{ s__('AI|Resolve with AI') }}
    <resolve-with-ai-info-popover
      v-if="!isResolving"
      target="resolve-with-ai-button"
      :show-public-project-warning="showPublicProjectWarning"
    />
  </gl-button>
</template>
