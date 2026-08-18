<script>
import { GlLoadingIcon } from '@gitlab/ui';
import Draggable from '~/lib/utils/vue3compat/draggable_compat.vue';
import { __, s__ } from '~/locale';
import BoardCard from '~/boards/components/board_card.vue';
import BoardNewIssue from '~/boards/components/board_new_issue.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { STATUS_CLOSED } from '~/issues/constants';
import {
  addItemToList,
  removeItemFromList,
  updateIssueCountAndWeight,
  setError,
} from '~/boards/graphql/cache_updates';
import listsIssuesQuery from '~/boards/graphql/lists_issues.query.graphql';
import { shouldCloneCard } from '~/boards/boards_util';
import { defaultSortableOptions } from '~/sortable/constants';
import { BoardType, EpicFilterType, listIssuablesQueries } from 'ee/boards/constants';

export default {
  name: 'IssuesLaneList',
  components: {
    BoardCard,
    BoardNewIssue,
    GlLoadingIcon,
  },
  inject: ['boardType', 'fullPath'],
  props: {
    list: {
      type: Object,
      required: true,
    },
    issues: {
      type: Array,
      required: false,
      default: () => [],
    },
    lists: {
      type: Array,
      required: true,
    },
    isUnassignedIssuesLane: {
      type: Boolean,
      required: false,
      default: false,
    },
    canAdminList: {
      type: Boolean,
      required: false,
      default: false,
    },
    canAdminEpic: {
      type: Boolean,
      required: false,
      default: false,
    },
    epicId: {
      type: String,
      required: false,
      default: null,
    },
    boardId: {
      type: String,
      required: true,
    },
    filterParams: {
      type: Object,
      required: true,
    },
    isLoadingMoreIssues: {
      type: Boolean,
      required: false,
      default: false,
    },
    highlightedLists: {
      type: Array,
      required: false,
      default: () => [],
    },
    totalIssuesCount: {
      type: Number,
      required: false,
      default: 0,
    },
    showNewForm: {
      type: Boolean,
      required: false,
      default: false,
    },
    columnIndex: {
      type: Number,
      required: false,
      default: 0,
    },
    rowIndex: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  emits: ['issues-loaded', 'set-filters', 'toggle-new-form', 'update-page-info'],
  data() {
    return {
      toListId: null,
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    currentListWithUnassignedIssues: {
      query: listsIssuesQuery,
      variables() {
        return {
          ...this.baseVariables,
          id: this.list.id,
        };
      },
      skip() {
        return !this.isUnassignedIssuesLane;
      },
      update(data) {
        return data[this.boardType]?.board.lists.nodes[0];
      },
      result({ data }) {
        if (data) {
          const list = data[this.boardType]?.board.lists.nodes[0];
          this.$emit('update-page-info', list.issues.pageInfo, list.id);
        }
      },
      error(error) {
        setError({
          error,
          message: s__(
            'Boards|An error occurred while fetching unassigned issues. Please try again.',
          ),
        });
      },
    },
  },
  computed: {
    baseVariables() {
      return {
        fullPath: this.fullPath,
        boardId: this.boardId,
        isGroup: this.boardType === BoardType.group,
        isProject: this.boardType === BoardType.project,
        filters: this.isUnassignedIssuesLane
          ? { ...this.filterParams, epicWildcardId: EpicFilterType.none.toUpperCase() }
          : { ...this.filterParams, epicId: this.epicId, includeSubepics: false },

        first: 10,
      };
    },
    issuesToUse() {
      if (this.isUnassignedIssuesLane) {
        return this.currentListWithUnassignedIssues?.issues.nodes || [];
      }
      return this.issues;
    },

    treeRootWrapper() {
      return this.canAdminList && (this.canAdminEpic || this.isUnassignedIssuesLane)
        ? Draggable
        : 'ul';
    },
    treeRootOptions() {
      const options = {
        ...defaultSortableOptions,
        fallbackOnBody: false,
        group: 'board-epics-swimlanes',
        tag: 'ul',
        'ghost-class': 'board-card-drag-active',
        'data-epic-id': this.epicId,
        'data-list-id': this.list.id,
        value: this.issuesToUse,
      };

      return this.canAdminList ? options : {};
    },
    isLoading() {
      return (
        this.$apollo.queries.currentListWithUnassignedIssues.loading && !this.isLoadingMoreIssues
      );
    },
    pageInfo() {
      return this.currentListWithUnassignedIssues?.issues.pageInfo || {};
    },

    highlighted() {
      return this.highlightedLists.includes(this.list.id);
    },
    toList() {
      if (!this.toListId) {
        return {};
      }
      return this.lists.find((list) => list.id === this.toListId);
    },

    boardItemsSizeExceedsMax() {
      return this.list.maxIssueCount > 0 && this.totalIssuesCount > this.list.maxIssueCount;
    },
    showNewIssue() {
      return this.list.type !== STATUS_CLOSED && this.showNewForm && this.isUnassignedIssuesLane;
    },
  },
  watch: {
    highlighted: {
      handler(highlighted) {
        if (highlighted) {
          this.$nextTick(() => {
            this.$el.scrollIntoView(false);
          });
        }
      },
      immediate: true,
    },
    isLoadingMoreIssues(newVal) {
      if (newVal) {
        this.fetchMoreIssues();
      }
    },
  },
  methods: {
    handleDragOnStart() {
      document.body.classList.add('is-dragging');
    },
    handleDragOnEnd(params) {
      document.body.classList.remove('is-dragging');
      const { newIndex, oldIndex, from, to, item } = params;
      const { itemIid } = item.dataset;
      const { children } = to;
      let moveBeforeId;
      let moveAfterId;

      // If issue is being moved within the same list
      if (from === to) {
        if (newIndex > oldIndex && children.length > 1) {
          // If issue is being moved down we look for the issue that ends up before
          moveBeforeId = children[newIndex].dataset.itemId;
        } else if (newIndex < oldIndex && children.length > 1) {
          // If issue is being moved up we look for the issue that ends up after
          moveAfterId = children[newIndex].dataset.itemId;
        } else {
          // If issue remains in the same list at the same position we do nothing
          return;
        }
      } else {
        // We look for the issue that ends up before the moved issue if it exists
        if (children[newIndex - 1]) {
          moveBeforeId = children[newIndex - 1].dataset.itemId;
        }
        // We look for the issue that ends up after the moved issue if it exists
        if (children[newIndex]) {
          moveAfterId = children[newIndex].dataset.itemId;
        }
      }

      this.moveBoardItem(
        {
          iid: itemIid,
          epicId: to.dataset.epicId,
          fromListId: from.dataset.listId,
          toListId: to.dataset.listId,
          moveBeforeId,
          moveAfterId,
        },
        newIndex,
      );
    },
    async fetchMoreIssues() {
      await this.$apollo.queries.currentListWithUnassignedIssues.fetchMore({
        variables: { ...this.baseVariables, id: this.list.id, after: this.pageInfo.endCursor },
      });
      this.$emit('issues-loaded');
    },
    isItemInTheList(itemIid) {
      const items = this.toList?.issues?.nodes || [];
      return items.some((item) => item.iid === itemIid);
    },
    shouldCloneCard(epicId = null) {
      return shouldCloneCard(this.list.listType, this.toList.listType) && epicId === this.epicId;
    },
    moveItemVariables({
      iid,
      epicId = null,
      fromListId,
      toListId,
      moveBeforeId,
      moveAfterId,
      itemToMove,
    }) {
      return {
        iid,
        epicId,
        boardId: this.boardId,
        projectPath: itemToMove.referencePath.split(/[#]/)[0],
        moveBeforeId: moveBeforeId ? getIdFromGraphQLId(moveBeforeId) : undefined,
        moveAfterId: moveAfterId ? getIdFromGraphQLId(moveAfterId) : undefined,
        fromListId: getIdFromGraphQLId(fromListId),
        toListId: getIdFromGraphQLId(toListId),
      };
    },
    async moveBoardItem(variables, newIndex) {
      const { fromListId, toListId, iid, epicId } = variables;
      this.toListId = toListId;

      const itemToMove = this.issuesToUse.find((item) => item.iid === iid);

      if (this.shouldCloneCard(epicId) && this.isItemInTheList(iid)) {
        return;
      }

      try {
        await this.$apollo.mutate({
          mutation: listIssuablesQueries.issue.moveMutation,
          variables: this.moveItemVariables({ ...variables, itemToMove }),
          update: (cache, { data: { issuableMoveList } }) =>
            this.updateCacheAfterMovingItem({
              cache,
              issuableMoveList,
              fromListId,
              toListId,
              epicId,
              newIndex,
            }),
          optimisticResponse: {
            issuableMoveList: {
              issuable: itemToMove,
              errors: [],
            },
          },
        });
      } catch (error) {
        setError({
          error,
          message: s__('Boards|An error occurred while moving the issue. Please try again.'),
        });
      }
    },
    updateCacheAfterMovingItem({
      cache,
      issuableMoveList,
      fromListId,
      toListId,
      newIndex,
      epicId,
    }) {
      const { issuable } = issuableMoveList;

      // Remove issue from one epic lane
      if (!this.shouldCloneCard(epicId)) {
        const variables = { ...this.baseVariables };

        if (this.isUnassignedIssuesLane) {
          variables.id = this.list.id;
        }
        removeItemFromList({
          query: listsIssuesQuery,
          variables,
          boardType: this.boardType,
          id: issuable.id,
          issuableType: 'issue',
          listId: fromListId,
          cache,
        });
      }

      // Add issue to another epic lane
      const variables = {
        ...this.baseVariables,
        filters: epicId
          ? { ...this.filterParams, epicId, includeSubepics: false }
          : { ...this.filterParams, epicWildcardId: 'NONE' },
      };
      if (!epicId) {
        variables.id = this.toListId;
      }
      addItemToList({
        query: listsIssuesQuery,
        variables,
        issuable,
        newIndex,
        boardType: this.boardType,
        issuableType: 'issue',
        listId: toListId,
        cache,
      });

      updateIssueCountAndWeight({
        fromListId,
        toListId,
        filterParams: this.filterParams,
        issuable,
        shouldClone: this.shouldCloneCard(epicId),
        cache,
      });
    },
    async addListItem(input) {
      this.$emit('toggle-new-form');
      try {
        await this.$apollo.mutate({
          mutation: listIssuablesQueries.issue.createMutation,
          variables: { input: { ...input, moveAfterId: this.issuesToUse[0]?.id } },
          update: (cache, { data: { createIssuable } }) => {
            const { issuable } = createIssuable;
            addItemToList({
              query: listsIssuesQuery,
              variables: { ...this.baseVariables, id: this.list.id },
              issuable,
              newIndex: 0,
              boardType: this.boardType,
              issuableType: 'issue',
              cache,
            });

            updateIssueCountAndWeight({
              fromListId: null,
              toListId: this.list.id,
              filterParams: this.filterParams,
              issuable,
              shouldClone: true,
              cache,
            });
          },
          optimisticResponse: {
            createIssuable: {
              errors: [],
              issuable: {
                ...listIssuablesQueries.issue.optimisticResponse,
                title: input.title,
              },
            },
          },
        });
      } catch (error) {
        setError({
          message: __('An error occurred while creating the issue. Please try again.'),
          error,
        });
      }
    },
  },
};
</script>

<template>
  <div
    class="board gl-flex gl-shrink-0 gl-whitespace-normal gl-px-3 gl-align-top"
    :class="{ 'is-collapsed gl-w-10': list.collapsed }"
  >
    <div class="gl-relative gl-w-full gl-rounded-lg gl-bg-strong dark:gl-bg-subtle">
      <board-new-issue
        v-if="showNewIssue"
        :list="list"
        :board-id="boardId"
        @toggle-new-form="$emit('toggle-new-form')"
        @add-new-issue="addListItem"
      />
      <component
        :is="treeRootWrapper"
        v-if="!list.collapsed"
        v-bind="treeRootOptions"
        item-key="id"
        class="board-cell gl-m-0 gl-h-full gl-list-none gl-p-2"
        :class="{
          'board-column-highlighted': highlighted,
          'gl-rounded-lg gl-bg-red-50': boardItemsSizeExceedsMax,
          'list-empty': !issuesToUse.length,
        }"
        :data-row-index="rowIndex"
        data-testid="tree-root-wrapper"
        @start="handleDragOnStart"
        @end="handleDragOnEnd"
      >
        <template v-if="!isLoading">
          <board-card
            v-for="(issue, index) in issuesToUse"
            ref="issue"
            :key="issue.id"
            :index="index"
            :list="list"
            :item="issue"
            :can-admin="canAdminEpic"
            :row-index="rowIndex"
            :column-index="columnIndex"
            @set-filters="$emit('set-filters', $event)"
          />
        </template>
        <template #footer>
          <gl-loading-icon
            v-if="(isLoading || isLoadingMoreIssues) && isUnassignedIssuesLane"
            size="sm"
            class="gl-py-3"
          />
        </template>
      </component>
    </div>
  </div>
</template>
