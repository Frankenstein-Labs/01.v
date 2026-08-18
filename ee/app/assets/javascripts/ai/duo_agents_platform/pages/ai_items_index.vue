<script>
import { GlTabs, GlTab } from '@gitlab/ui';
import { fetchPolicies } from '~/lib/graphql';
import { InternalEvents } from '~/tracking';
import { __, s__, sprintf } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { TYPENAME_PROJECT, TYPENAME_GROUP } from '~/graphql_shared/constants';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogListWrapper from 'ee/ai/catalog/components/ai_catalog_list_wrapper.vue';
import {
  AI_CATALOG_CONSUMER_LABELS,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_MANAGED,
  TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_CATALOG,
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AI_CATALOG_APOLLO_PROJECT_LIST_QUERY,
  AI_CATALOG_APOLLO_PROJECT_TAB_LIST_QUERY,
  DEFAULT_SORT,
} from 'ee/ai/catalog/constants';
import { initialPaginationParams, reactivePaginationMethods } from 'ee/ai/catalog/pagination_utils';
import { isSortDirectionless, sortingComputeds } from 'ee/ai/catalog/sorting_utils';
import { getRegistryItem, itemTypeValidator } from 'ee/ai/catalog/item_type_registry';
import { isItemTypeEnabledInDuoSettings } from 'ee/ai/catalog/permissions';
import { itemTypeDisabledAlertLink } from 'ee/ai/catalog/utils';
import AiCatalogConfiguredItemsWrapper from '../components/catalog/ai_catalog_configured_items_wrapper.vue';

const TAB_QUERY_VALUES = ['enabled', 'managed', 'catalog'];

const tabIndexFromQuery = (tab) => {
  const index = TAB_QUERY_VALUES.indexOf(tab);
  return index === -1 ? 0 : index;
};

const tabQueryFromIndex = (index) => TAB_QUERY_VALUES[index];

export default {
  name: 'AiItemsIndex',
  components: {
    GlTabs,
    GlTab,
    ErrorsAlert,
    AiCatalogListHeader,
    AiCatalogListWrapper,
    AiCatalogConfiguredItemsWrapper,
  },
  mixins: [glFeatureFlagsMixin(), InternalEvents.mixin(), glAbilitiesMixin()],
  inject: {
    isProjectNamespace: {},
    isGroupNamespace: {
      default: false,
    },
    groupPath: {
      default: null,
    },
    projectId: {
      default: null,
    },
    projectPath: {
      default: null,
    },
    exploreAiCatalogAgentsPath: {
      default: '',
    },
    exploreAiCatalogFlowsPath: {
      default: '',
    },
    rootGroupId: {
      default: null,
    },
    groupId: {
      default: null,
    },
    duoSettings: {
      default: {},
    },
  },
  props: {
    itemType: {
      type: String,
      required: true,
      validator: itemTypeValidator,
    },
  },
  apollo: {
    managedItems: {
      query: AI_CATALOG_APOLLO_PROJECT_LIST_QUERY,
      skip() {
        return (
          !this.projectPath ||
          !this.effectiveGroupId ||
          this.selectedTabIndex !== this.$options.PROJECT_TAB_INDICES.MANAGED
        );
      },
      variables() {
        return {
          projectPath: this.projectPath,
          itemTypes: this.resolvedItemTypes,
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId),
          groupId: convertToGraphQLId(TYPENAME_GROUP, this.effectiveGroupId),
          search: this.searchTerm,
          sort: this.sortGraphQLValue,
          ...this.paginationVariables,
        };
      },
      // fetchPolicy needed to refresh items after creating an item
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update(data) {
        return this.indexConfig.managedItemsUpdate(data);
      },
      result({ data }) {
        this.pageInfo = data?.project?.aiCatalogItems?.pageInfo || {};
      },
      error() {
        this.errors = [this.indexConfig.errorMessage];
      },
    },
    catalogItems: {
      query: AI_CATALOG_APOLLO_PROJECT_TAB_LIST_QUERY,
      skip() {
        return (
          !this.projectPath || this.selectedTabIndex !== this.$options.PROJECT_TAB_INDICES.CATALOG
        );
      },
      variables() {
        return {
          projectPath: this.projectPath,
          search: this.searchTerm,
          sort: this.sortGraphQLValue,
          ...this.paginationVariables,
          itemTypes: this.resolvedItemTypes,
        };
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => data?.project?.aiCatalogItems?.nodes || [],
      result({ data }) {
        this.pageInfo = data?.project?.aiCatalogItems?.pageInfo || {};
      },
      error() {
        this.errors = [this.indexConfig.errorMessage];
      },
    },
  },
  data() {
    return {
      managedItems: [],
      catalogItems: [],
      errors: [],
      errorTitle: null,
      pageInfo: {},
      paginationVariables: initialPaginationParams(),
      searchTerm: '',
      sort: DEFAULT_SORT,
    };
  },
  computed: {
    itemRegistry() {
      return getRegistryItem(this.itemType);
    },
    indexConfig() {
      return this.itemRegistry.index;
    },
    effectiveGroupId() {
      return this.projectId ? this.rootGroupId : this.groupId;
    },
    canAdmin() {
      return Boolean(this.glAbilities.adminAiCatalogItem);
    },
    canAdminConsumer() {
      return Boolean(this.glAbilities.adminAiCatalogItemConsumer);
    },
    canCreate() {
      return this.itemRegistry.canCreateFn({ glAbilities: this.glAbilities });
    },
    isLoading() {
      return this.$apollo.queries.managedItems.loading;
    },
    isCatalogLoading() {
      return this.$apollo.queries.catalogItems.loading;
    },
    resolvedItemTypes() {
      if (this.itemType === AI_CATALOG_TYPE_AGENT && this.glFeatures.aiCatalogThirdPartyFlows) {
        return [AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_THIRD_PARTY_FLOW];
      }
      return [this.itemType];
    },
    disabledItemTypes() {
      return this.resolvedItemTypes.filter(
        (itemType) => !isItemTypeEnabledInDuoSettings({ duoSettings: this.duoSettings, itemType }),
      );
    },
    disabledItemTypeMessages() {
      return this.disabledItemTypes.map((type) => {
        const registry = getRegistryItem(type).index;
        const message = this.canAdmin
          ? registry.itemTypeDisabledCanAdminAlert
          : registry.itemTypeDisabledAlert;
        return itemTypeDisabledAlertLink(message, this.duoSettings.duoSettingsPath);
      });
    },
    itemTypeConfig() {
      return {
        showRoute: this.itemRegistry.routes.show,
        visibilityTooltip: this.itemRegistry.visibilityDescriptions,
      };
    },
    itemTypeConfigEnabled() {
      return {
        disableActionItem: {
          showActionItem: (item) =>
            this.indexConfig.showActionItem(item, this.canAdminConsumer, {
              isGroupNamespace: this.isGroupNamespace,
            }),
          text: __('Disable'),
        },
        ...this.itemTypeConfig,
      };
    },
    itemTypeConfigManaged() {
      return {
        showStatusBadge: true,
        ...this.itemTypeConfig,
      };
    },
    namespaceTypeLabel() {
      return this.isProjectNamespace
        ? AI_CATALOG_CONSUMER_LABELS[AI_CATALOG_CONSUMER_TYPE_PROJECT]
        : AI_CATALOG_CONSUMER_LABELS[AI_CATALOG_CONSUMER_TYPE_GROUP];
    },
    disableConfirmTitle() {
      return sprintf(this.itemRegistry.disable.confirmTitleTemplate, {
        namespaceType: this.namespaceTypeLabel,
      });
    },
    disableConfirmMessage() {
      return this.isProjectNamespace
        ? this.itemRegistry.disable.confirmMessageProject
        : this.itemRegistry.disable.confirmMessageGroup;
    },
    emptyStateTitle() {
      return sprintf(this.indexConfig.emptyStateTitleTemplate, {
        namespaceType: this.namespaceTypeLabel,
      });
    },
    emptyStateDescription() {
      return this.indexConfig.emptyStateDescription;
    },
    emptyStateButtonText() {
      return s__('AICatalog|Explore the AI Catalog');
    },
    exploreAiCatalogPath() {
      return this[this.indexConfig.explorePathKey];
    },
    testIdSlug() {
      return `${this.itemType.toLowerCase()}s`;
    },
    selectedTabIndex() {
      return tabIndexFromQuery(this.$route.query.tab);
    },
    ...sortingComputeds,
  },
  watch: {
    selectedTabIndex() {
      this.resetPagination();
    },
  },
  methods: {
    ...reactivePaginationMethods,
    handleFilter({ search } = {}) {
      this.searchTerm = search || '';
    },
    handleSort(sortValue) {
      // FilteredSearchBar emits the fully-resolved sort string, or the bare
      // 'CATALOG_PRIORITY' for the directionless default.
      this.sort = isSortDirectionless(sortValue) ? DEFAULT_SORT : sortValue;
      this.resetPagination();
    },
    handleError({ title, errors }) {
      this.errorTitle = title;
      this.errors = errors;
    },
    dismissErrors() {
      this.errors = [];
      this.errorTitle = null;
    },
    onTabInput(nextIndex) {
      if (nextIndex === this.selectedTabIndex) return;
      const nextQuery = { ...this.$route.query };
      if (nextIndex === this.$options.PROJECT_TAB_INDICES.ENABLED) {
        delete nextQuery.tab;
      } else {
        nextQuery.tab = tabQueryFromIndex(nextIndex);
      }
      this.$router.push({ query: nextQuery });
    },
    onClickManagedTab() {
      this.resetPagination();
      if (this.selectedTabIndex !== this.$options.PROJECT_TAB_INDICES.MANAGED) {
        this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_MANAGED, {
          label: this.itemRegistry.trackLabel,
        });
      }
    },
    onClickCatalogTab() {
      this.resetPagination();
      if (this.selectedTabIndex !== this.$options.PROJECT_TAB_INDICES.CATALOG) {
        this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_CATALOG, {
          label: this.itemRegistry.trackLabel,
        });
      }
    },
  },
  PROJECT_TAB_INDICES: {
    ENABLED: 0,
    MANAGED: 1,
    CATALOG: 2,
  },
};
</script>

<template>
  <div>
    <ai-catalog-list-header
      :heading="itemRegistry.pageTitle"
      :can-admin="canAdmin"
      :can-create="canCreate"
      new-button-variant="default"
    />
    <errors-alert class="gl-mt-5" :title="errorTitle" :errors="errors" @dismiss="dismissErrors" />

    <gl-tabs
      v-if="isProjectNamespace"
      :value="selectedTabIndex"
      content-class="gl-py-0"
      @input="onTabInput"
    >
      <gl-tab :title="__('Enabled')">
        <ai-catalog-configured-items-wrapper
          :item-types="resolvedItemTypes"
          :disable-confirm-title="disableConfirmTitle"
          :disable-confirm-message="disableConfirmMessage"
          :empty-state-title="emptyStateTitle"
          :empty-state-description="emptyStateDescription"
          :empty-state-button-text="emptyStateButtonText"
          :item-type-config="itemTypeConfigEnabled"
          :disabled-item-type-messages="disabledItemTypeMessages"
          @empty-state-click="onTabInput($options.PROJECT_TAB_INDICES.CATALOG)"
          @error="handleError"
        />
      </gl-tab>
      <gl-tab :title="s__('AICatalog|Managed')" lazy @click="onClickManagedTab">
        <ai-catalog-list-wrapper
          :is-loading="isLoading"
          :items="managedItems"
          :item-type-config="itemTypeConfigManaged"
          :page-info="pageInfo"
          :empty-state-title="emptyStateTitle"
          :empty-state-description="emptyStateDescription"
          :empty-state-button-text="emptyStateButtonText"
          :disable-confirm-title="disableConfirmTitle"
          :disable-confirm-message="disableConfirmMessage"
          :disabled-item-type-messages="disabledItemTypeMessages"
          :search-term="searchTerm"
          :initial-sort-by="initialSortBy"
          :data-testid="`managed-${testIdSlug}-list`"
          @empty-state-click="onTabInput($options.PROJECT_TAB_INDICES.CATALOG)"
          @next-page="handleNextPage"
          @prev-page="handlePrevPage"
          @filter="handleFilter"
          @sort="handleSort"
        />
      </gl-tab>
      <gl-tab :title="s__('AICatalog|AI Catalog')" lazy @click="onClickCatalogTab">
        <ai-catalog-list-wrapper
          :is-loading="isCatalogLoading"
          :items="catalogItems"
          :item-type-config="itemTypeConfig"
          :page-info="pageInfo"
          :search-term="searchTerm"
          :initial-sort-by="initialSortBy"
          :data-testid="`catalog-${testIdSlug}-list`"
          @next-page="handleNextPage"
          @prev-page="handlePrevPage"
          @filter="handleFilter"
          @sort="handleSort"
        />
      </gl-tab>
    </gl-tabs>
    <ai-catalog-configured-items-wrapper
      v-else
      :disable-confirm-title="disableConfirmTitle"
      :disable-confirm-message="disableConfirmMessage"
      :empty-state-title="emptyStateTitle"
      :empty-state-description="emptyStateDescription"
      :empty-state-button-href="exploreAiCatalogPath"
      :empty-state-button-text="emptyStateButtonText"
      :item-types="resolvedItemTypes"
      :item-type-config="itemTypeConfigEnabled"
      @error="handleError"
    />
  </div>
</template>
