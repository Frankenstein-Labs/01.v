<script>
import { GlExperimentBadge, GlToastMixin } from '@gitlab/ui';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AI_CATALOG_MCP_SERVERS_SHOW_ROUTE } from '../router/constants';
import AiCatalogMcpServerForm from '../components/ai_catalog_mcp_server_form.vue';
import aiCatalogMcpServerUpdateMutation from '../graphql/mutations/ai_catalog_mcp_server_update.mutation.graphql';

export default {
  name: 'AiCatalogMcpServersEdit',
  components: { AiCatalogMcpServerForm, PageHeading, GlExperimentBadge },
  mixins: [GlToastMixin],
  props: {
    aiCatalogMcpServer: {
      type: Object,
      required: true,
    },
  },
  data() {
    return { errors: [], isSubmitting: false };
  },
  computed: {
    initialValues() {
      return {
        name: this.aiCatalogMcpServer.name,
        description: this.aiCatalogMcpServer.description,
        url: this.aiCatalogMcpServer.url,
        homepageUrl: this.aiCatalogMcpServer.homepageUrl,
        transport: this.aiCatalogMcpServer.transport,
        authType: this.aiCatalogMcpServer.authType,
        oauthClientId: this.aiCatalogMcpServer.oauthClientId,
      };
    },
  },
  methods: {
    async handleSubmit(input) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      try {
        const { data } = await this.$apollo.mutate({
          mutation: aiCatalogMcpServerUpdateMutation,
          variables: { input: { id: this.aiCatalogMcpServer.id, ...input } },
        });
        if (data) {
          const { errors } = data.aiCatalogMcpServerUpdate;
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }
          this.$toast.show(s__('AICatalog|MCP server updated.'));
          this.$router.push({
            name: AI_CATALOG_MCP_SERVERS_SHOW_ROUTE,
            params: { id: this.$route.params.id },
          });
        }
      } catch (error) {
        this.errors = [s__('AICatalog|Could not update MCP server. Please try again.')];
        Sentry.captureException(error);
      } finally {
        this.isSubmitting = false;
      }
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
          {{ s__('AICatalog|Edit MCP server') }}
          <gl-experiment-badge type="experiment" class="gl-self-center" />
        </span>
      </template>
      <template #description>
        {{ s__('AICatalog|Update the settings for this MCP server.') }}
      </template>
    </page-heading>
    <ai-catalog-mcp-server-form
      mode="edit"
      :is-loading="isSubmitting"
      :errors="errors"
      :initial-values="initialValues"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
