<script>
import { GlToastMixin } from '@gitlab/ui';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { getPreviousRoute } from 'ee/ai/duo_agents_platform/router/utils';
import createAiFlowTriggerMutation from 'ee/ai/duo_agents_platform/graphql/mutations/create_ai_flow_trigger.mutation.graphql';
import { FLOW_TRIGGERS_INDEX_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import FlowTriggerForm from './components/flow_trigger_form.vue';

export default {
  name: 'FlowTriggersNew',
  components: {
    FlowTriggerForm,
    PageHeading,
  },
  mixins: [GlToastMixin],
  inject: ['projectPath', 'projectId'],
  data() {
    return {
      errorMessages: [],
      isLoading: false,
    };
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
    async createAiFlowTrigger(input) {
      this.resetErrorMessages();
      this.isLoading = true;

      try {
        const {
          data: {
            aiFlowTriggerCreate: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: createAiFlowTriggerMutation,
          variables: {
            input: {
              ...input,
              projectPath: this.projectPath,
            },
          },
        });

        if (errors.length > 0) {
          this.errorMessages = errors;
          return;
        }
        this.$toast.show(s__('DuoAgentsPlatform|Trigger created successfully.'));
        this.$router.push({
          name: FLOW_TRIGGERS_INDEX_ROUTE,
        });
      } catch (error) {
        this.errorMessages = [
          error.message || s__('DuoAgentsPlatform|The trigger could not be created. Try again.'),
        ];
      } finally {
        this.isLoading = false;
      }
    },
    resetErrorMessages() {
      this.errorMessages = [];
    },
  },
};
</script>

<template>
  <div class="gl-mx-auto @lg/panel:gl-w-2/3">
    <page-heading :heading="s__('DuoAgentsPlatform|New trigger')">
      <template #description>
        {{
          s__(
            'DuoAgentsPlatform|Create a trigger to run a flow or external agent based on project events.',
          )
        }}
      </template>
    </page-heading>
    <flow-trigger-form
      :error-messages="errorMessages"
      :project-path="projectPath"
      :project-id="projectId"
      :is-loading="isLoading"
      mode="create"
      @cancel="goToPreviousRoute"
      @dismiss-errors="resetErrorMessages"
      @submit="createAiFlowTrigger"
    />
  </div>
</template>
