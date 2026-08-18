<script>
import { GlExperimentBadge, GlToastMixin } from '@gitlab/ui';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AI_CATALOG_MCP_SERVERS_ROUTE } from '../router/constants';
import AiCatalogMcpServerForm from '../components/ai_catalog_mcp_server_form.vue';
import aiCatalogMcpServerCreateMutation from '../graphql/mutations/ai_catalog_mcp_server_create.mutation.graphql';

export default {
  name: 'AiCatalogMcpServersNew',
  components: {
    AiCatalogMcpServerForm,
    PageHeading,
    GlExperimentBadge,
  },
  mixins: [GlToastMixin],
  data() {
    return {
      errors: [],
      isSubmitting: false,
    };
  },
  methods: {
    async handleSubmit(input) {
      this.isSubmitting = true;
      this.resetErrorMessages();

      try {
        const { data } = await this.$apollo.mutate({
          mutation: aiCatalogMcpServerCreateMutation,
          variables: {
            input,
          },
        });

        if (data) {
          const { errors } = data.aiCatalogMcpServerCreate;
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }

          this.$toast.show(s__('AICatalog|MCP server created.'));
          this.$router.push({
            name: AI_CATALOG_MCP_SERVERS_ROUTE,
          });
        }
      } catch (error) {
        this.errors = [s__('AICatalog|Could not create MCP server. Please try again.')];
        Sentry.captureException(error);
      } finally {
        this.isSubmitting = false;
      }
    },
    handleCancel() {
      this.$router.push({
        name: AI_CATALOG_MCP_SERVERS_ROUTE,
      });
    },
    resetErrorMessages() {
      this.errors = [];
    },
  },
};
</script>

<template>
  <div>
    <page-heading>
      <template #heading>
        <span class="gl-flex">
          {{ s__('AICatalog|New MCP server') }}
          <gl-experiment-badge type="experiment" class="gl-self-center" />
        </span>
      </template>
      <template #description>
        {{ s__('AICatalog|Add a Model Context Protocol server to extend agent capabilities.') }}
      </template>
    </page-heading>
    <ai-catalog-mcp-server-form
      mode="create"
      :is-loading="isSubmitting"
      :errors="errors"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
      @cancel="handleCancel"
    />
  </div>
</template>
