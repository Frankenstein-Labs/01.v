<script>
import { debounce, uniqBy } from 'lodash-es';
import {
  GlAvatarLabeled,
  GlCollapsibleListbox,
  GlLink,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import produce from 'immer';
import { createAlert } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import getSppLinkedGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_groups.graphql';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { __, s__ } from '~/locale';
import {
  BLOCK_GROUP_BRANCH_MODIFICATION_WITH_EXCEPTIONS_HUMANIZED_STRING,
  BLOCK_GROUP_BRANCH_MODIFICATION_HUMANIZED_STRING,
  EXCEPT_GROUPS,
  EXCEPTION_GROUPS_TEXTS,
  EXCEPTION_GROUPS_LISTBOX_ITEMS,
  WITHOUT_EXCEPTIONS,
  createGroupObject,
} from '../lib';

export default {
  name: 'BlockGroupBranchModification',
  apollo: {
    groups: {
      query: getSppLinkedGroups,
      variables() {
        return {
          fullPath: this.assignedPolicyProjectPath,
          topLevelOnly: true,
          search: this.searchValue,
        };
      },
      update(data) {
        const groups =
          data.project?.securityPolicyProjectLinkedGroups?.nodes?.map(createGroupObject) || [];
        this.pageInfo = data.project?.securityPolicyProjectLinkedGroups?.pageInfo || {};
        return this.joinUniqueGroups(groups);
      },
      async result() {
        if (this.hasNotLoadedExceptions) {
          const groups = await this.getGroupsByIds();
          this.groups = this.joinUniqueGroups(groups);
        }
      },
      error() {
        createAlert({
          message: s__('SecurityOrchestration|Something went wrong, unable to fetch groups'),
        });
      },
    },
  },
  components: {
    GlAvatarLabeled,
    GlCollapsibleListbox,
    GlLink,
    GlSprintf,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['assignedPolicyProject', 'namespacePath'],
  props: {
    enabled: {
      type: Boolean,
      required: true,
    },
    exceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['change'],
  data() {
    return {
      groups: [],
      selectedExceptionType: this.exceptions.length ? EXCEPT_GROUPS : WITHOUT_EXCEPTIONS,
      searchValue: '',
      pageInfo: {},
    };
  },
  computed: {
    assignedPolicyProjectPath() {
      return this.assignedPolicyProject?.fullPath || this.namespacePath;
    },
    notLoadedExceptions() {
      const groupIds = this.groups.map((group) => group.id);
      return this.exceptionIds.filter((id) => !groupIds.includes(id));
    },
    hasNotLoadedExceptions() {
      return this.notLoadedExceptions.length > 0;
    },
    filteredGroups() {
      return searchInItemsProperties({
        items: this.groups,
        properties: ['text', 'fullPath', 'fullName'],
        searchQuery: this.searchValue,
      });
    },
    selectedGroups() {
      return this.groups.filter(({ id }) => this.exceptionIds.includes(id));
    },
    loading() {
      return this.$apollo.queries.groups.loading;
    },
    exceptionIds() {
      return this.exceptions.map(({ id }) => id);
    },
    exceptionGraphqlIds() {
      return this.notLoadedExceptions.map((id) => convertToGraphQLId(TYPENAME_GROUP, id));
    },
    text() {
      return this.selectedExceptionType === WITHOUT_EXCEPTIONS
        ? BLOCK_GROUP_BRANCH_MODIFICATION_HUMANIZED_STRING
        : BLOCK_GROUP_BRANCH_MODIFICATION_WITH_EXCEPTIONS_HUMANIZED_STRING;
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.selectedGroups,
        selected: this.exceptionIds,
        placeholder: __('Select groups'),
        maxOptionsShown: 2,
      });
    },
    hasNextPage() {
      return this.pageInfo.hasNextPage;
    },
  },
  watch: {
    enabled(value) {
      if (value) {
        this.selectExceptionType(this.selectedExceptionType);
      } else {
        this.selectExceptionType(WITHOUT_EXCEPTIONS);
      }
    },
  },
  created() {
    this.handleSearch = debounce(this.setSearchValue, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.handleSearch.cancel();
  },
  methods: {
    async getGroupsByIds() {
      try {
        const { data } = await this.$apollo.query({
          query: getSppLinkedGroups,
          variables: {
            fullPath: this.assignedPolicyProjectPath,
            topLevelOnly: true,
            ids: this.exceptionGraphqlIds,
          },
        });

        return data.project?.securityPolicyProjectLinkedGroups?.nodes?.map(createGroupObject) || [];
      } catch {
        return [];
      }
    },
    joinUniqueGroups(groups) {
      return uniqBy([...this.groups, ...groups], 'id');
    },
    setSearchValue(value = '') {
      this.searchValue = value;
    },
    selectExceptionType(type) {
      this.selectedExceptionType = type;

      if (this.enabled) {
        const value =
          type === EXCEPT_GROUPS
            ? { enabled: this.enabled, exceptions: this.exceptions }
            : this.enabled;
        this.emitChangeEvent(value);
      }
    },
    updateGroupExceptionValue(ids) {
      if (this.enabled) {
        this.emitChangeEvent({ enabled: this.enabled, exceptions: ids.map((id) => ({ id })) });
      }
    },
    emitChangeEvent(value) {
      this.$emit('change', value);
    },
    async loadMoreGroups() {
      if (!this.hasNextPage) return [];
      try {
        return await this.$apollo.queries.groups.fetchMore({
          variables: {
            search: this.searchValue,
            after: this.pageInfo.endCursor,
          },
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              draftData.project.securityPolicyProjectLinkedGroups.nodes = [
                ...previousResult.project.securityPolicyProjectLinkedGroups.nodes,
                ...fetchMoreResult.project.securityPolicyProjectLinkedGroups.nodes,
              ];
            });
          },
        });
      } catch {
        return [];
      }
    },
  },

  GROUP_PROTECTED_BRANCHES_DOCS: helpPagePath('user/project/repository/branches/protected', {
    anchor: 'in-a-group',
  }),
  EXCEPTION_GROUPS_TEXTS,
  EXCEPTION_GROUPS_LISTBOX_ITEMS,
};
</script>

<template>
  <div>
    <gl-sprintf :message="text">
      <template #link="{ content }">
        <gl-link :href="$options.GROUP_PROTECTED_BRANCHES_DOCS" target="_blank">{{
          content
        }}</gl-link>
      </template>
      <template #exceptSelection>
        <gl-collapsible-listbox
          data-testid="has-exceptions-selector"
          class="gl-my-3 gl-mr-2 @md/panel:gl-my-0"
          :disabled="!enabled"
          :items="$options.EXCEPTION_GROUPS_LISTBOX_ITEMS"
          :selected="selectedExceptionType"
          @select="selectExceptionType"
        />
      </template>
      <template #groupSelection>
        <gl-collapsible-listbox
          data-testid="exceptions-selector"
          is-check-centered
          multiple
          searchable
          :items="filteredGroups"
          :infinite-scroll="hasNextPage"
          :loading="loading"
          :selected="exceptionIds"
          :toggle-text="toggleText"
          @bottom-reached="loadMoreGroups"
          @search="handleSearch"
          @select="updateGroupExceptionValue"
        >
          <template #list-item="{ item }">
            <gl-avatar-labeled
              shape="circle"
              :size="32"
              :src="item.avatar_url"
              :entity-name="item.text"
              :label="item.text"
              :sub-label="item.fullPath"
            />
          </template>
        </gl-collapsible-listbox>
      </template>
    </gl-sprintf>
  </div>
</template>
