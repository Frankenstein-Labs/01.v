<script>
import { GlButton, GlExperimentBadge, GlIcon, GlLink } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { AI_CATALOG_MCP_SERVERS_EDIT_ROUTE } from '../router/constants';
import FormSection from '../components/form_section.vue';
import AiCatalogItemField from '../components/ai_catalog_item_field.vue';

export default {
  name: 'AiCatalogMcpServersShow',
  components: {
    AiCatalogItemField,
    ErrorsAlert,
    FormSection,
    GlButton,
    GlExperimentBadge,
    GlIcon,
    GlLink,
    PageHeading,
  },
  mixins: [timeagoMixin, glAbilitiesMixin()],
  props: {
    aiCatalogMcpServer: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      errors: [],
      errorTitle: null,
    };
  },
  computed: {
    canEdit() {
      return Boolean(this.glAbilities.updateAiCatalogMcpServer);
    },
    editRoute() {
      return {
        name: AI_CATALOG_MCP_SERVERS_EDIT_ROUTE,
        params: { id: this.$route.params.id },
      };
    },
    authTypeLabel() {
      if (this.aiCatalogMcpServer?.authType === 'OAUTH') {
        return s__('AICatalog|OAuth');
      }
      if (this.aiCatalogMcpServer?.authType === 'NO_AUTH') {
        return s__('AICatalog|No authentication');
      }
      return this.aiCatalogMcpServer?.authType;
    },
    metaData() {
      if (!this.aiCatalogMcpServer) return [];

      const items = [
        {
          text: __('Created on'),
          icon: 'calendar',
          value: formatDate(this.aiCatalogMcpServer.createdAt, 'mmmm d, yyyy'),
          testId: 'created-on',
        },
      ];

      if (
        this.aiCatalogMcpServer.updatedAt &&
        this.aiCatalogMcpServer.updatedAt !== this.aiCatalogMcpServer.createdAt
      ) {
        items.push({
          text: __('Modified'),
          icon: 'clock',
          value: this.timeFormatted(this.aiCatalogMcpServer.updatedAt),
          testId: 'modified',
        });
      }

      return items;
    },
  },
  methods: {
    setErrors({ title = null, errors = [] } = {}) {
      this.errorTitle = title;
      this.errors = errors;
    },
    dismissErrors() {
      this.setErrors();
    },
  },
};
</script>

<template>
  <div>
    <errors-alert class="gl-mt-5" :title="errorTitle" :errors="errors" @dismiss="dismissErrors" />
    <page-heading>
      <template #heading>
        <div class="gl-flex gl-items-baseline gl-gap-3">
          <span class="gl-line-clamp-1 gl-wrap-anywhere" data-testid="server-name">
            {{ aiCatalogMcpServer.name }}
          </span>
          <gl-experiment-badge type="experiment" class="gl-self-center" />
        </div>
      </template>
      <template #actions>
        <gl-button
          v-if="canEdit"
          :to="editRoute"
          category="secondary"
          icon="pencil"
          data-testid="edit-mcp-server-button"
        >
          {{ __('Edit') }}
        </gl-button>
      </template>
      <template #description>
        <div class="gl-mb-3 gl-flex gl-flex-wrap gl-gap-3 gl-text-subtle">
          <span
            v-for="item in metaData"
            :key="item.testId"
            class="gl-flex gl-items-center gl-gap-2"
            :data-testid="item.testId"
          >
            <gl-icon :name="item.icon" class="gl-text-subtle" />
            <span>{{ item.text }} {{ item.value }}</span>
          </span>
        </div>
        <p v-if="aiCatalogMcpServer.description" class="gl-mb-0">
          {{ aiCatalogMcpServer.description }}
        </p>
      </template>
    </page-heading>

    <div>
      <h2 class="gl-heading-3">
        {{ s__('AICatalog|MCP server configuration') }}
      </h2>
      <dl class="gl-flex gl-flex-col gl-gap-5">
        <form-section :title="s__('AICatalog|Configuration')" is-display>
          <ai-catalog-item-field :title="s__('AICatalog|Server URL')" data-testid="server-url">
            <gl-link :href="aiCatalogMcpServer.url" target="_blank" class="gl-font-monospace">
              {{ aiCatalogMcpServer.url }}
            </gl-link>
          </ai-catalog-item-field>
          <ai-catalog-item-field
            v-if="aiCatalogMcpServer.homepageUrl"
            :title="s__('AICatalog|Homepage')"
            data-testid="server-homepage"
          >
            <gl-link :href="aiCatalogMcpServer.homepageUrl" target="_blank">
              {{ aiCatalogMcpServer.homepageUrl }}
            </gl-link>
          </ai-catalog-item-field>
          <ai-catalog-item-field
            :title="s__('AICatalog|Transport')"
            :value="aiCatalogMcpServer.transport"
            data-testid="server-transport"
          />
          <ai-catalog-item-field
            :title="s__('AICatalog|Authentication')"
            :value="authTypeLabel"
            data-testid="server-auth-type"
          />
        </form-section>
      </dl>
    </div>
  </div>
</template>
