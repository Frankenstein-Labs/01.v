<script>
import { defineAsyncComponent } from 'vue';
import { GlAlert, GlBadge, GlButton, GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { TYPENAME_CD_APPLICATION } from 'ee/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import cdApplicationFlowQuery from '../graphql/cd_application_flow.query.graphql';
import cdApplicationFlowDefinitionCreateMutation from '../graphql/cd_application_flow_definition_create.mutation.graphql';

export default {
  name: 'FlowEditor',
  components: {
    GlAlert,
    GlBadge,
    GlButton,
    GlEmptyState,
    GlLoadingIcon,
    SourceEditor: defineAsyncComponent(
      () =>
        import(
          /* webpackChunkName: 'flow_source_editor' */ '~/vue_shared/components/source_editor.vue'
        ),
    ),
  },
  props: {
    id: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      application: null,
      draft: '',
      isSeeded: false,
      isSaving: false,
      hasError: false,
      errors: [],
    };
  },
  apollo: {
    application: {
      query: cdApplicationFlowQuery,
      variables() {
        return { applicationId: this.applicationId };
      },
      update: (data) => data?.organization?.cdApplication ?? null,
      result() {
        if (this.isSeeded) {
          return;
        }
        this.draft = this.originalDefinition;
        this.isSeeded = true;
      },
      error() {
        this.hasError = true;
      },
      watchLoading(isLoading) {
        if (isLoading) {
          this.hasError = false;
        }
      },
    },
  },
  computed: {
    applicationId() {
      return convertToGraphQLId(TYPENAME_CD_APPLICATION, this.id);
    },
    isLoading() {
      return this.$apollo.queries.application.loading;
    },
    applicationsShowRoute() {
      return { name: 'applications_show_route', params: { id: this.id } };
    },
    applicationName() {
      return this.application?.name ?? '';
    },
    currentVersion() {
      return this.application?.applicationFlowDefinitions?.nodes?.[0]?.version ?? 0;
    },
    originalDefinition() {
      return this.application?.applicationFlowDefinitions?.nodes?.[0]?.definition ?? '';
    },
    isUnchanged() {
      return this.draft === this.originalDefinition;
    },
    draftVersion() {
      return this.currentVersion + 1;
    },
    draftLabel() {
      return sprintf(s__('FlowEditor|Draft v%{version}'), { version: this.draftVersion });
    },
  },
  methods: {
    goBack() {
      this.$router.push(this.applicationsShowRoute);
    },
    async saveFlow() {
      this.isSaving = true;
      this.errors = [];

      try {
        const { data } = await this.$apollo.mutate({
          mutation: cdApplicationFlowDefinitionCreateMutation,
          variables: {
            input: {
              applicationId: this.applicationId,
              definition: this.draft,
            },
          },
          refetchQueries: [
            { query: cdApplicationFlowQuery, variables: { applicationId: this.applicationId } },
          ],
          awaitRefetchQueries: true,
        });

        const errors = data?.cdApplicationFlowDefinitionCreate?.errors ?? [];
        if (errors.length) {
          this.errors = errors;
          return;
        }

        this.goBack();
      } catch (error) {
        this.errors = [s__('FlowEditor|Failed to save the flow. Please try again.')];
        Sentry.captureException(error);
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="isLoading" size="lg" class="gl-mt-5" />

    <gl-alert
      v-else-if="hasError"
      variant="danger"
      :dismissible="false"
      class="gl-mt-5"
      data-testid="flow-editor-load-error-alert"
    >
      {{ s__('FlowEditor|Failed to load the application flow. Refresh to try again.') }}
    </gl-alert>

    <gl-empty-state
      v-else-if="!application"
      :title="s__('ContinuousDeployment|Application not found')"
      :description="
        s__(
          'ContinuousDeployment|The application may have been removed or you may not have access to it.',
        )
      "
      data-testid="flow-editor-not-found"
    />

    <template v-else>
      <gl-alert
        v-if="errors.length"
        variant="danger"
        class="gl-mt-5"
        data-testid="flow-editor-error-alert"
        @dismiss="errors = []"
      >
        <ul class="gl-m-0 gl-pl-5">
          <li v-for="(error, index) in errors" :key="index">{{ error }}</li>
        </ul>
      </gl-alert>

      <div class="gl-my-5 gl-flex gl-items-center gl-justify-between gl-gap-3">
        <div class="gl-flex gl-items-center gl-gap-3">
          <gl-button
            category="tertiary"
            icon="chevron-lg-left"
            :aria-label="__('Go back')"
            :to="applicationsShowRoute"
            data-testid="back-button"
          />
          <h1 class="gl-heading-4 gl-mb-0">{{ applicationName }}</h1>
          <gl-badge variant="neutral">{{ draftLabel }}</gl-badge>
        </div>

        <div class="gl-flex gl-gap-3">
          <gl-button data-testid="discard-flow-button" @click="goBack">
            {{ s__('FlowEditor|Discard') }}
          </gl-button>
          <gl-button
            variant="confirm"
            :loading="isSaving"
            :disabled="isUnchanged"
            data-testid="save-flow-button"
            @click="saveFlow"
          >
            {{ s__('FlowEditor|Save flow') }}
          </gl-button>
        </div>
      </div>

      <div class="gl-overflow-hidden gl-rounded-base gl-border-1 gl-border-solid gl-border-default">
        <source-editor
          :value="draft"
          file-name="flow.yaml"
          :use-dynamic-height="false"
          data-testid="flow-source-editor"
          @input="draft = $event"
        />
      </div>
    </template>
  </div>
</template>
