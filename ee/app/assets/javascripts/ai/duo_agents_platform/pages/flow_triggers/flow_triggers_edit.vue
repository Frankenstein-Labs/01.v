<script>
import { GlEmptyState, GlLoadingIcon, GlToastMixin } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { TYPENAME_AI_FLOW_TRIGGER } from 'ee/graphql_shared/constants';
import { getPreviousRoute } from 'ee/ai/duo_agents_platform/router/utils';
import { FLOW_TRIGGERS_INDEX_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import updateAiFlowTriggerMutation from 'ee/ai/duo_agents_platform/graphql/mutations/update_ai_flow_trigger.mutation.graphql';
import getAiFlowTriggersQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_ai_flow_triggers.query.graphql';
import FlowTriggerForm from './components/flow_trigger_form.vue';

export default {
  name: 'FlowTriggersEdit',
  components: {
    FlowTriggerForm,
    GlEmptyState,
    GlLoadingIcon,
    PageHeading,
  },
  mixins: [GlToastMixin],
  inject: ['projectPath', 'projectId'],
  data() {
    return {
      flowTrigger: {},
      errorMessages: [],
      isLoadingMutation: false,
    };
  },
  apollo: {
    flowTrigger: {
      query: getAiFlowTriggersQuery,
      variables() {
        return {
          projectPath: this.projectPath,
          ids: [this.flowTriggerGraphQlId],
        };
      },
      update(data) {
        const flowTrigger = data.project?.aiFlowTriggers?.nodes[0];
        return flowTrigger
          ? {
              description: flowTrigger.description,
              eventTypes: flowTrigger.eventTypes,
              user: flowTrigger.user,
              configPath: flowTrigger.configPath,
              filter: flowTrigger.filter || {},
              aiCatalogItemConsumer: {
                id: flowTrigger?.aiCatalogItemConsumer?.id,
                name: flowTrigger?.aiCatalogItemConsumer?.item.name,
              },
            }
          : {};
      },
      error(error) {
        createAlert({
          message: error.message,
          captureError: true,
        });
      },
    },
  },
  computed: {
    isQueryLoading() {
      return this.$apollo.queries.flowTrigger.loading;
    },
    flowTriggerGraphQlId() {
      return convertToGraphQLId(TYPENAME_AI_FLOW_TRIGGER, this.$route.params.id);
    },
    isNotFound() {
      return this.flowTrigger && Object.keys(this.flowTrigger).length === 0;
    },
  },
  methods: {
    goToPreviousRoute() {
      const previousRoute = getPreviousRoute();
      if (previousRoute) {
        this.$router.push(previousRoute);
      } else {
        this.$router.push({ name: FLOW_TRIGGERS_INDEX_ROUTE });
      }
    },
    async updateAiFlowTrigger(input) {
      this.resetErrorMessages();
      this.isLoadingMutation = true;

      try {
        const {
          data: {
            aiFlowTriggerUpdate: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: updateAiFlowTriggerMutation,
          variables: {
            input: {
              ...input,
              id: this.flowTriggerGraphQlId,
            },
          },
        });

        if (errors.length > 0) {
          this.errorMessages = errors;
          return;
        }

        this.$toast.show(s__('DuoAgentsPlatform|Trigger updated successfully.'));
        this.goToPreviousRoute();
      } catch (error) {
        this.errorMessages = [
          error.message || s__('DuoAgentsPlatform|The trigger could not be updated. Try again.'),
        ];
      } finally {
        this.isLoadingMutation = false;
      }
    },
    resetErrorMessages() {
      this.errorMessages = [];
    },
  },
  emptySearchSvg,
};
</script>

<template>
  <div class="gl-mx-auto @lg/panel:gl-w-2/3">
    <page-heading :heading="s__('DuoAgentsPlatform|Edit trigger')">
      <template #description>
        {{ s__('DuoAgentsPlatform|Change the target or events for this trigger.') }}
      </template>
    </page-heading>
    <gl-loading-icon v-if="isQueryLoading" size="lg" class="gl-my-5" />
    <gl-empty-state
      v-else-if="isNotFound"
      :title="s__('DuoAgentsPlatform|Trigger not found.')"
      :svg-path="$options.emptySearchSvg"
    />
    <flow-trigger-form
      v-else
      :error-messages="errorMessages"
      :project-path="projectPath"
      :project-id="projectId"
      :is-loading="isLoadingMutation"
      :initial-values="flowTrigger"
      mode="edit"
      @cancel="goToPreviousRoute"
      @dismiss-errors="resetErrorMessages"
      @submit="updateAiFlowTrigger"
    />
  </div>
</template>
