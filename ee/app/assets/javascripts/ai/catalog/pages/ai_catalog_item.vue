<script>
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { fetchPolicies } from '~/lib/graphql';
import { TYPENAME_PROJECT, TYPENAME_GROUP } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import {
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
  VERIFICATION_LEVEL_GITLAB_MAINTAINED,
} from '../constants';
import { resolveVersion } from '../utils';
import { getRegistryItem } from '../item_type_registry';

export default {
  name: 'AiCatalogItem',
  components: {
    ErrorsAlert,
    GlEmptyState,
    GlLoadingIcon,
  },
  inject: {
    isGlobalNamespace: {},
    isGroupNamespace: {
      default: false,
    },
    projectId: {
      default: null,
    },
    rootGroupId: {
      default: null,
    },
    groupId: {
      default: null,
    },
  },
  props: {
    itemType: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      aiCatalogItem: {},
      activeVersionKey: null,
      errors: [],
    };
  },
  apollo: {
    aiCatalogItem: {
      query() {
        return this.itemRegistry.queries.item;
      },
      variables() {
        if (this.itemType === AI_CATALOG_TYPE_FOUNDATIONAL_AGENT) {
          return {
            reference: this.$route.params.reference,
          };
        }

        const hasGroup = Boolean(this.projectId ? this.rootGroupId : this.groupId);
        const groupId = this.projectId ? this.rootGroupId : this.groupId;

        return {
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.$route.params.id),
          showSoftDeleted: !this.isGlobalNamespace,
          hasProject: Boolean(this.projectId),
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId || '0'),
          hasGroup,
          groupId: convertToGraphQLId(TYPENAME_GROUP, groupId || '0'),
        };
      },
      // fetchPolicy needed to refresh item after updating triggers
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update(data) {
        if (this.itemType === AI_CATALOG_TYPE_FOUNDATIONAL_AGENT) {
          const foundationalAgent = data.aiFoundationalChatAgent;
          if (!foundationalAgent) return {};
          return this.transformFoundationalAgentToItem(data.aiFoundationalChatAgent);
        }

        const item = data?.aiCatalogItem || {};
        if (!this.itemRegistry.acceptedTypes.includes(item.itemType)) {
          return {};
        }
        return item;
      },
      error(error) {
        this.errors = [this.itemRegistry.errorMessage];
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    itemRegistry() {
      return getRegistryItem(this.itemType);
    },
    isLoading() {
      return this.$apollo.queries.aiCatalogItem.loading;
    },
    isItemNotFound() {
      return this.aiCatalogItem && Object.keys(this.aiCatalogItem).length === 0;
    },
    isEnabled() {
      return this.groupId
        ? Boolean(this.aiCatalogItem?.configurationForGroup?.enabled)
        : Boolean(this.aiCatalogItem?.configurationForProject?.enabled);
    },
    resolvedVersion() {
      return resolveVersion(this.aiCatalogItem, {
        isGlobalNamespace: this.isGlobalNamespace,
        isGroupNamespace: this.isGroupNamespace,
      });
    },
    isUpdateAvailable() {
      const latestVersion = this.aiCatalogItem.latestVersion?.versionName;
      const pinnedVersion = this.resolvedVersion.versionName;

      // The backend always bumps *up*, so we don't need a complex comparison
      return this.isEnabled && latestVersion && latestVersion !== pinnedVersion;
    },
    version() {
      return {
        isUpdateAvailable: this.isUpdateAvailable,
        activeVersionKey: this.activeVersionKey ?? this.resolvedVersion.key,
        baseVersionKey: this.resolvedVersion.key,
        setActiveVersionKey: (selectedKey) => {
          this.activeVersionKey = selectedKey;
        },
      };
    },
  },
  watch: {
    'aiCatalogItem.name': {
      handler(name) {
        if (!this.baseTitle) {
          const { pageTitle } = this.itemRegistry;
          this.baseTitle = document.title.includes(pageTitle)
            ? document.title
            : `${pageTitle} · ${document.title}`;
        }
        if (name) document.title = `${name} · ${this.baseTitle}`;
      },
    },
  },
  methods: {
    transformFoundationalAgentToItem(foundationalAgent) {
      return {
        ...foundationalAgent,
        itemType: AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
        foundational: true,
        public: true,
        verificationLevel: VERIFICATION_LEVEL_GITLAB_MAINTAINED,
        latestVersion: {
          humanVersionName: foundationalAgent.version,
          versionName: foundationalAgent.version,
          systemPrompt: foundationalAgent.systemPrompt,
          tools: {
            nodes: foundationalAgent.tools,
          },
          mcpServers: {
            nodes: [],
          },
        },
      };
    },
  },
  emptySearchSvg,
};
</script>

<template>
  <div>
    <errors-alert :errors="errors" @dismiss="errors = []" />

    <gl-loading-icon v-if="isLoading" size="lg" class="gl-my-5" />

    <gl-empty-state
      v-else-if="isItemNotFound"
      :title="itemRegistry.notFoundTitle"
      :svg-path="$options.emptySearchSvg"
    />

    <router-view v-else :ai-catalog-item="aiCatalogItem" :version="version" />
  </div>
</template>
