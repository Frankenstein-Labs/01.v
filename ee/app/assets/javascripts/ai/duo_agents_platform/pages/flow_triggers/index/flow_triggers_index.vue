<script>
import emptyStateIllustrationPath from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg?url';
import { GlToastMixin } from '@gitlab/ui';
import { s__ } from '~/locale';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { createAlert } from '~/alert';
import { fetchPolicies } from '~/lib/graphql';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import ResourceListsLoadingStateList from '~/vue_shared/components/resource_lists/loading_state_list.vue';
import getProjectAiFlowTriggers from 'ee/ai/duo_agents_platform/graphql/queries/get_ai_flow_triggers.query.graphql';
import deleteAiFlowTrigger from 'ee/ai/duo_agents_platform/graphql/mutations/delete_ai_flow_trigger.mutation.graphql';
import FlowTriggersCta from './components/flow_triggers_cta.vue';
import FlowTriggersTable from './components/flow_triggers_table.vue';

export default {
  name: 'FlowTriggersIndex',
  components: {
    ConfirmActionModal,
    FlowTriggersCta,
    FlowTriggersTable,
    PageHeading,
    ResourceListsEmptyState,
    ResourceListsLoadingStateList,
  },
  mixins: [glAbilitiesMixin(), GlToastMixin],
  inject: ['projectPath'],
  data() {
    return {
      aiFlowTriggers: [],
      idToBeDeleted: null,
    };
  },
  apollo: {
    aiFlowTriggers: {
      query: getProjectAiFlowTriggers,
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      update: (data) => data.project?.aiFlowTriggers?.nodes ?? [],
      error(error) {
        createAlert({
          message: error.message || s__('DuoAgentsPlatform|Failed to fetch triggers'),
          captureError: true,
        });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiFlowTriggers.loading;
    },
    showEmptyState() {
      return !this.isLoading && this.aiFlowTriggers.length === 0;
    },
    showNewTriggerButton() {
      return (
        this.glAbilities.readAiCatalogThirdPartyFlow || // User could select a configured AI Catalog external agent for the trigger
        this.glAbilities.readAiCatalogFlow || // User could select a configured AI Catalog flow for the trigger
        this.glAbilities.createAiCatalogThirdPartyFlow // User could create new "manual" external agent (one with a configuration path)
      );
    },
  },
  methods: {
    async deleteAiFlowTrigger() {
      try {
        await this.$apollo.mutate({
          mutation: deleteAiFlowTrigger,
          variables: {
            id: this.idToBeDeleted,
          },
          refetchQueries: [getProjectAiFlowTriggers],
        });

        this.$toast.show(s__('DuoAgentsPlatform|Trigger deleted successfully.'));
      } catch (error) {
        createAlert({
          message: error.message || s__('DuoAgentsPlatform|Failed to delete trigger.'),
        });
      } finally {
        this.resetItemIdToBeDeleted();
      }
    },
    resetItemIdToBeDeleted() {
      this.idToBeDeleted = null;
    },
  },
  emptyStateIllustrationPath,
};
</script>

<template>
  <div>
    <page-heading :heading="s__('DuoAgentsPlatform|Triggers')">
      <template #description>
        {{ s__('DuoAgentsPlatform|Manage automated flows within your project.') }}
      </template>
      <template v-if="showNewTriggerButton" #actions>
        <flow-triggers-cta />
      </template>
    </page-heading>
    <resource-lists-loading-state-list
      v-if="isLoading"
      :left-lines-count="1"
      :right-lines-count="1"
    />
    <resource-lists-empty-state
      v-else-if="showEmptyState"
      :title="s__('DuoAgentsPlatform|No triggers yet')"
      :description="
        s__(
          'DuoAgentsPlatform|Create triggers to automatically run pipelines when specified events occur in your project.',
        )
      "
      :svg-path="$options.emptyStateIllustrationPath"
    >
      <template v-if="showNewTriggerButton" #actions>
        <slot name="actions">
          <flow-triggers-cta />
        </slot>
      </template>
    </resource-lists-empty-state>
    <template v-else>
      <flow-triggers-table
        :ai-flow-triggers="aiFlowTriggers"
        class="gl-mt-8"
        @delete-trigger="(id) => (idToBeDeleted = id)"
      />
      <confirm-action-modal
        v-if="idToBeDeleted"
        modal-id="delete-item-modal"
        variant="danger"
        :title="s__('DuoAgentsPlatform|Delete trigger')"
        :action-fn="deleteAiFlowTrigger"
        :action-text="__('Delete')"
        @close="resetItemIdToBeDeleted"
      >
        {{
          s__(
            'DuoAgentsPlatform|Are you sure you want to delete this trigger? This action cannot be undone.',
          )
        }}
      </confirm-action-modal>
    </template>
  </div>
</template>
