<script>
import { debounce, uniqBy, get } from 'lodash-es';
import { GlButton, GlCollapsibleListbox, GlLabel, GlFormGroup, GlPopover } from '@gitlab/ui';
import produce from 'immer';
import { s__, __, n__ } from '~/locale';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPE_COMPLIANCE_FRAMEWORK } from '~/graphql_shared/constants';
import { renderMultiSelectText } from 'ee/security_orchestration/components/policy_editor/utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import ComplianceFrameworkFormModal from 'ee/groups/settings/compliance_frameworks/components/form_modal.vue';
import ProjectsCountMessage from 'ee/security_orchestration/components/shared/projects_count_message.vue';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import getComplianceFrameworksForDropdownQuery from './graphql/get_compliance_frameworks_for_dropdown.query.graphql';

export default {
  i18n: {
    complianceFrameworkCreateButton: s__('SecurityOrchestration|Create new framework label'),
    complianceFrameworkHeader: s__('SecurityOrchestration|Select frameworks'),
    complianceFrameworkTypeName: s__('SecurityOrchestration|compliance frameworks'),
    complianceFrameworkPopoverPlaceholder: s__(
      'SecurityOrchestration|Compliance framework has no projects',
    ),
    errorMessage: s__('SecurityOrchestration|At least one framework label should be selected'),
    noFrameworksText: s__('SecurityOrchestration|No compliance frameworks'),
    selectAllLabel: __('Select all'),
    clearAllLabel: __('Clear all'),
    CSPFramework: s__('ComplianceFramework|Instance level compliance framework'),
  },
  name: 'ComplianceFrameworkDropdown',
  components: {
    ComplianceFrameworkFormModal,
    GlButton,
    GlCollapsibleListbox,
    GlFormGroup,
    GlLabel,
    GlPopover,
    ProjectsCountMessage,
  },
  apollo: {
    complianceFrameworks: {
      query: getComplianceFrameworksForDropdownQuery,
      variables() {
        return {
          search: this.searchTerm,
          fullPath: this.fullPath,
          ids: null,
          withCount: this.withItemsCount,
        };
      },
      update(data) {
        if (!this.namespaceId) {
          this.namespaceId = data.namespace.id;
        }
        return this.getUniqueFrameworks(data.namespace?.complianceFrameworks?.nodes);
      },
      result({ data }) {
        this.pageInfo = data?.namespace?.complianceFrameworks?.pageInfo || {};

        if (this.selectedButNotLoadedComplianceIds.length > 0) {
          this.fetchComplianceFrameworksByIds();
        }

        if (!this.allItemsCountSaved) {
          this.allItemsCount = get(data, 'namespace.complianceFrameworks.count', 0);
        }
      },
      error() {
        this.emitError();
      },
    },
  },
  provide() {
    return {
      groupPath: this.fullPath,
      pipelineConfigurationFullPathEnabled: true,
      pipelineConfigurationEnabled: true,
      namespaceId: this.namespaceId,
    };
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    fullPath: {
      type: String,
      required: true,
    },
    selectedFrameworkIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    showError: {
      type: Boolean,
      required: false,
      default: false,
    },
    /**
     * selected ids passed as short format
     * [21,34,45] as number
     * needs to be converted to full graphql id
     * if false, selectedFrameworkIds needs to be
     * an array of full graphQl ids
     */
    useShortIdFormat: {
      type: Boolean,
      required: false,
      default: true,
    },
    withItemsCount: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['framework-query-error', 'select'],
  data() {
    return {
      complianceFrameworks: [],
      searchTerm: '',
      pageInfo: {},
      namespaceId: null,
      allItemsCount: 0,
    };
  },
  computed: {
    allItemsCountSaved() {
      return this.allItemsCount > 0;
    },
    allItemsLoaded() {
      return this.complianceFrameworks.length === this.allItemsCount;
    },
    hasNextPage() {
      return this.pageInfo.hasNextPage;
    },
    itemsText() {
      return n__('framework', 'frameworks', this.allItemsCount);
    },
    formattedSelectedFrameworkIds() {
      if (this.useShortIdFormat) {
        return (
          this.selectedFrameworkIds?.map((id) =>
            convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, id),
          ) || []
        );
      }

      return this.selectedFrameworkIds || [];
    },
    existingFormattedSelectedFrameworkIds() {
      return this.formattedSelectedFrameworkIds.filter((id) =>
        this.complianceFrameworkIds.includes(id),
      );
    },
    selectedButNotLoadedComplianceIds() {
      return this.formattedSelectedFrameworkIds.filter(
        (id) => !this.complianceFrameworkIds.includes(id),
      );
    },
    complianceFrameworkItems() {
      return this.complianceFrameworks?.reduce((acc, { id, name }) => {
        acc[id] = name;
        return acc;
      }, {});
    },
    dropdownPlaceholder() {
      return renderMultiSelectText({
        selected: this.formattedSelectedFrameworkIds,
        items: this.complianceFrameworkItems,
        itemTypeName: this.$options.i18n.complianceFrameworkTypeName,
        useAllSelected: false,
      });
    },
    listBoxItems() {
      return (
        this.complianceFrameworks?.map(({ id, name, ...framework }) => ({
          value: id,
          text: name,
          ...framework,
        })) || []
      );
    },
    filteredListBoxItems() {
      return searchInItemsProperties({
        items: this.listBoxItems,
        properties: ['text'],
        searchQuery: this.searchTerm,
      });
    },
    complianceFrameworkIds() {
      return this.complianceFrameworks?.map(({ id }) => id);
    },
    loading() {
      return this.$apollo.queries.complianceFrameworks?.loading;
    },
    listBoxCategory() {
      return this.showError ? 'secondary' : 'primary';
    },
    listBoxVariant() {
      return this.showError ? 'danger' : 'default';
    },
    showFooter() {
      return this.withItemsCount && !this.loading;
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    async fetchComplianceFrameworksByIds() {
      try {
        const { data } = await this.$apollo.query({
          query: getComplianceFrameworksForDropdownQuery,
          variables: {
            fullPath: this.fullPath,
            ids: this.selectedButNotLoadedComplianceIds,
          },
        });

        this.complianceFrameworks = this.getUniqueFrameworks(
          data?.namespace?.complianceFrameworks?.nodes,
        );
      } catch {
        this.emitError();
      }
    },
    fetchMoreItems() {
      this.$apollo.queries.complianceFrameworks
        .fetchMore({
          variables: {
            after: this.pageInfo.endCursor,
            fullPath: this.fullPath,
            ids: null,
            search: this.searchTerm,
          },
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              draftData.namespace.complianceFrameworks.nodes = [
                ...previousResult.namespace.complianceFrameworks.nodes,
                ...draftData.namespace.complianceFrameworks.nodes,
              ];
            });
          },
        })
        .catch(() => {
          this.emitError();
        });
    },
    emitError() {
      this.$emit('framework-query-error');
    },
    showCreateFrameworkForm() {
      this.$refs.formModal.show();
    },
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
    },
    /**
     * Only works with ListBox multiple mode
     * Without multiple prop select method emits single id
     * and includes method won't work
     * @param ids selected ids in full graphql format
     */
    selectFrameworks(ids) {
      const payload = this.useShortIdFormat ? ids.map((id) => getIdFromGraphQLId(id)) : ids;
      this.$emit('select', payload);
    },
    onComplianceFrameworkCreated() {
      this.$refs.formModal.hide();
      this.$refs.listbox.open();
      this.$apollo.queries.complianceFrameworks.refetch();
    },
    getUniqueFrameworks(items = []) {
      return uniqBy([...this.complianceFrameworks, ...items], 'id');
    },
    isCSPFramework(framework) {
      if (!framework.namespaceId || !this.namespaceId) {
        return false;
      }

      return getIdFromGraphQLId(framework.namespaceId) !== getIdFromGraphQLId(this.namespaceId);
    },
  },
};
</script>

<template>
  <div>
    <gl-form-group
      class="gl-mb-0"
      label-sr-only
      :label="$options.i18n.errorMessage"
      :state="!showError"
      :optional="false"
      :invalid-feedback="$options.i18n.errorMessage"
    >
      <gl-collapsible-listbox
        ref="listbox"
        block
        multiple
        searchable
        :category="listBoxCategory"
        :variant="listBoxVariant"
        :disabled="disabled"
        :header-text="$options.i18n.complianceFrameworkHeader"
        :loading="loading"
        :no-results-text="$options.i18n.noFrameworksText"
        :items="filteredListBoxItems"
        :infinite-scroll="hasNextPage"
        :reset-button-label="$options.i18n.clearAllLabel"
        :show-select-all-button-label="$options.i18n.selectAllLabel"
        :toggle-text="dropdownPlaceholder"
        :title="dropdownPlaceholder"
        :selected="existingFormattedSelectedFrameworkIds"
        @bottom-reached="fetchMoreItems"
        @reset="selectFrameworks([])"
        @search="debouncedSearch"
        @select="selectFrameworks"
        @select-all="selectFrameworks(complianceFrameworkIds)"
      >
        <template #list-item="{ item }">
          <div :id="item.value">
            <gl-label
              :background-color="item.color"
              :description="$options.i18n.editFramework"
              :title="item.text"
              :target="item.editPath"
            />
            <gl-popover
              boundary="viewport"
              placement="right"
              triggers="hover"
              :target="item.value"
              :title="item.text"
            >
              <div>
                <span>{{ item.description }}</span>
                <span
                  v-if="isCSPFramework(item)"
                  class="gl-border-t gl-mb-2 gl-block gl-pt-2 gl-text-sm gl-text-subtle"
                  >{{ $options.i18n.CSPFramework }}</span
                >
              </div>
            </gl-popover>
          </div>
        </template>
        <template #footer>
          <div v-if="showFooter" class="gl-border-t gl-px-4 gl-py-2">
            <projects-count-message
              :count="filteredListBoxItems.length"
              :info-text="itemsText"
              :total-count="allItemsCount"
              :show-info-icon="!allItemsLoaded"
            />
          </div>

          <div class="gl-border-t">
            <gl-button
              category="tertiary"
              class="gl-w-full !gl-justify-start"
              target="_blank"
              @click="showCreateFrameworkForm"
            >
              {{ $options.i18n.complianceFrameworkCreateButton }}
            </gl-button>
          </div>
        </template>
      </gl-collapsible-listbox>
    </gl-form-group>

    <compliance-framework-form-modal ref="formModal" @change="onComplianceFrameworkCreated" />
  </div>
</template>
