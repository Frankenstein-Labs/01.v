<script>
import produce from 'immer';
import { debounce } from 'lodash-es';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import {
  GlAvatar,
  GlAvatarLabeled,
  GlButton,
  GlCollapsibleListbox,
  GlIcon,
  GlFormGroup,
  GlFormRadio,
  GlFormRadioGroup,
  GlTooltipDirective as GlTooltip,
} from '@gitlab/ui';
import BoardAddNewColumnForm from '~/boards/components/board_add_new_column_form.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { ListType, createListMutations, listsQuery, BoardType } from 'ee_else_ce/boards/constants';
import { isScopedLabel } from '~/lib/utils/common_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { __, s__ } from '~/locale';
import {
  groupOptionsByIterationCadences,
  groupByIterationCadences,
  getIterationPeriod,
} from 'ee/iterations/utils';
import IterationTitle from 'ee/iterations/components/iteration_title.vue';
import boardLabelsQuery from '~/boards/graphql/board_labels.query.graphql';
import groupBoardMilestonesQuery from '~/boards/graphql/group_board_milestones.query.graphql';
import projectBoardMilestonesQuery from '~/boards/graphql/project_board_milestones.query.graphql';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import { setError } from '~/boards/graphql/cache_updates';
import { getListByTypeId } from '~/boards/boards_util';
import usersAutocompleteQuery from '~/graphql_shared/queries/users_autocomplete.query.graphql';
import searchIterationQuery from 'ee/work_items/list/graphql/search_iterations.query.graphql';
import { getStatuses } from 'ee/work_items/utils';

export const listTypeInfo = {
  [ListType.label]: {
    listPropertyName: 'labels',
    loadingPropertyName: 'isLabelsLoading',
    noneSelected: __('Select a label'),
    searchPlaceholder: __('Search labels'),
  },
  [ListType.assignee]: {
    listPropertyName: 'assignees',
    loadingPropertyName: 'isAssigneesLoading',
    noneSelected: __('Select an assignee'),
    searchPlaceholder: __('Search assignees'),
  },
  [ListType.milestone]: {
    listPropertyName: 'milestones',
    loadingPropertyName: 'isMilestonesLoading',
    noneSelected: __('Select a milestone'),
    searchPlaceholder: __('Search milestones'),
  },
  [ListType.iteration]: {
    listPropertyName: 'iterations',
    loadingPropertyName: 'isIterationsLoading',
    noneSelected: __('Select an iteration'),
    searchPlaceholder: __('Search iterations'),
  },
  [ListType.status]: {
    listPropertyName: 'statuses',
    loadingPropertyName: 'isStatusesLoading',
    noneSelected: s__('WorkItem|Select a status'),
    searchPlaceholder: s__('WorkItem|Search status'),
  },
};

export default {
  name: 'BoardAddNewColumn',
  i18n: {
    value: __('Value'),
    noResults: __('No matching results'),
  },
  components: {
    BoardAddNewColumnForm,
    GlAvatar,
    GlAvatarLabeled,
    GlButton,
    GlCollapsibleListbox,
    GlIcon,
    GlFormGroup,
    GlFormRadio,
    GlFormRadioGroup,
    IterationTitle,
  },
  directives: {
    GlTooltip,
  },
  mixins: [glFeatureFlagMixin()],
  inject: [
    'scopedLabelsAvailable',
    'milestoneListsAvailable',
    'assigneeListsAvailable',
    'iterationListsAvailable',
    'boardType',
    'issuableType',
    'fullPath',
    'isEpicBoard',
    'statusListsAvailable',
  ],
  props: {
    boardId: {
      type: String,
      required: true,
    },
    listQueryVariables: {
      type: Object,
      required: true,
    },
    lists: {
      type: Object,
      required: true,
    },
    position: {
      type: Number,
      required: false,
      default: null,
    },
  },
  emits: ['filter-items', 'hide', 'highlight-list', 'set-add-column-form-visibility'],
  data() {
    return {
      selectedId: null,
      selectedItem: null,
      columnType: ListType.label,
      selectedIdValid: true,
      labels: [],
      milestones: [],
      assignees: [],
      iterations: [],
      searchTerm: '',
      statuses: [],
    };
  },
  apollo: {
    labels: {
      query: boardLabelsQuery,
      variables() {
        return {
          ...this.baseVariables,
          isGroup: this.boardType === BoardType.group,
          isProject: this.boardType === BoardType.project,
        };
      },
      skip() {
        return this.columnType !== ListType.label;
      },
      update(data) {
        return data[this.boardType].labels.nodes;
      },
      error(error) {
        setError({
          error,
          message: s__('Boards|An error occurred while fetching labels. Please try again.'),
        });
      },
    },
    milestones: {
      query() {
        if (this.boardType === BoardType.project) {
          return projectBoardMilestonesQuery;
        }
        return groupBoardMilestonesQuery;
      },
      variables() {
        return this.baseVariables;
      },
      update(data) {
        return data.namespace.milestones.nodes;
      },
      skip() {
        return this.columnType !== ListType.milestone;
      },
      error(error) {
        setError({
          error,
          message: s__('Boards|An error occurred while fetching milestones. Please try again.'),
        });
      },
    },
    assignees: {
      query() {
        return usersAutocompleteQuery;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          search: this.searchTerm,
          isProject: this.boardType === BoardType.project,
        };
      },
      update(data) {
        return data[this.boardType]?.autocompleteUsers;
      },
      skip() {
        return this.columnType !== ListType.assignee;
      },
      error(error) {
        setError({
          error,
          message: s__('Boards|An error occurred while fetching users. Please try again.'),
        });
      },
    },
    iterations: {
      query: searchIterationQuery,
      variables() {
        return {
          ...this.baseVariables,
          search: this.searchTerm,
          isProject: this.boardType === BoardType.project,
        };
      },
      update(data) {
        return data[this.boardType].iterations.nodes;
      },
      skip() {
        return this.columnType !== ListType.iteration;
      },
      error(error) {
        setError({
          error,
          message: s__('Boards|An error occurred while fetching iterations. Please try again.'),
        });
      },
    },
    statuses: {
      query: namespaceWorkItemTypesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return getStatuses(data.namespace?.workItemTypes?.nodes);
      },
      skip() {
        return this.columnType !== ListType.status;
      },
      error(error) {
        setError({
          error,
          message: s__('Boards|An error occurred while fetching statuses. Please try again.'),
        });
      },
    },
  },
  computed: {
    isLabelsLoading() {
      return this.$apollo.queries.labels.loading;
    },
    isMilestonesLoading() {
      return this.$apollo.queries.milestones.loading;
    },
    isAssigneesLoading() {
      return this.$apollo.queries.assignees.loading;
    },
    isIterationsLoading() {
      return this.$apollo.queries.iterations.loading;
    },
    isStatusesLoading() {
      return this.$apollo.queries.statuses.loading;
    },
    baseVariables() {
      return {
        fullPath: this.fullPath,
        searchTerm: this.searchTerm,
      };
    },
    info() {
      return listTypeInfo[this.columnType] || {};
    },

    iterationCadences() {
      return groupByIterationCadences(this.items);
    },

    filteredStatuses() {
      // frontend fuzzaldrin search
      if (this.searchTerm) {
        return fuzzaldrinPlus.filter(this.items, this.searchTerm, {
          key: ['text'],
        });
      }
      return this.items;
    },
    items() {
      return (this[this.info.listPropertyName] || []).map((i) => ({
        ...i,
        text: i.title || i.name,
        value: i.id,
      }));
    },

    listboxItems() {
      if (this.iterationTypeSelected) {
        return groupOptionsByIterationCadences(this.items);
      }

      if (this.statusTypeSelected) {
        return this.filteredStatuses;
      }

      return this.items;
    },

    labelTypeSelected() {
      return this.columnType === ListType.label;
    },
    assigneeTypeSelected() {
      return this.columnType === ListType.assignee;
    },
    milestoneTypeSelected() {
      return this.columnType === ListType.milestone;
    },
    iterationTypeSelected() {
      return this.columnType === ListType.iteration;
    },
    statusTypeSelected() {
      return this.columnType === ListType.status;
    },
    hasLabelSelection() {
      return this.labelTypeSelected && this.selectedItem;
    },
    hasMilestoneSelection() {
      return this.milestoneTypeSelected && this.selectedItem;
    },
    hasIterationSelection() {
      return this.iterationTypeSelected && this.selectedItem;
    },
    hasAssigneeSelection() {
      return this.assigneeTypeSelected && this.selectedItem;
    },
    hasStatusSelection() {
      return this.statusTypeSelected && this.selectedItem;
    },
    columnForSelected() {
      if (!this.columnType || !this.selectedId) {
        return false;
      }
      return getListByTypeId(this.lists, this.columnType, this.selectedId);
    },

    loading() {
      return this[this.info.loadingPropertyName];
    },

    columnTypes() {
      const types = [{ value: ListType.label, text: __('Label') }];

      if (this.assigneeListsAvailable) {
        types.push({ value: ListType.assignee, text: __('Assignee') });
      }

      if (this.milestoneListsAvailable) {
        types.push({ value: ListType.milestone, text: __('Milestone') });
      }

      if (this.iterationListsAvailable) {
        types.push({ value: ListType.iteration, text: __('Iteration') });
      }

      if (this.statusListsAvailable) {
        types.push({ value: ListType.status, text: __('Status') });
      }

      return types;
    },

    searchLabel() {
      return this.showListTypeSelector ? this.$options.i18n.value : null;
    },

    showListTypeSelector() {
      return !this.isEpicBoard && this.columnTypes.length > 1;
    },
  },
  watch: {
    selectedId(val) {
      if (val) {
        this.selectedIdValid = true;
      }
    },
  },
  methods: {
    async createList({
      backlog,
      labelId,
      milestoneId,
      assigneeId,
      iterationId,
      statusId,
      position,
    }) {
      try {
        await this.$apollo.mutate({
          mutation: createListMutations[this.issuableType].mutation,
          variables: {
            labelId,
            backlog,
            milestoneId,
            assigneeId,
            iterationId,
            statusId,
            boardId: this.boardId,
            position,
          },
          update: (
            store,
            {
              data: {
                boardListCreate: { list },
              },
            },
          ) => {
            const sourceData = store.readQuery({
              query: listsQuery[this.issuableType].query,
              variables: this.listQueryVariables,
            });
            const data = produce(sourceData, (draft) => {
              const lists = draft[this.boardType].board.lists.nodes;
              if (position === null) {
                lists.push({ ...list, position: lists.length });
              } else {
                const updatedLists = lists.map((l) => {
                  if (l.position >= position) {
                    return { ...l, position: l.position + 1 };
                  }
                  return l;
                });
                updatedLists.splice(position, 0, list);
                draft[this.boardType].board.lists.nodes = updatedLists;
              }
            });
            store.writeQuery({
              query: listsQuery[this.issuableType].query,
              variables: this.listQueryVariables,
              data,
            });
            this.$emit('highlight-list', list.id);
          },
        });
      } catch (error) {
        setError({
          error,
          message: s__('Boards|An error occurred while creating the list. Please try again.'),
        });
      }
    },
    async addList() {
      if (!this.selectedItem) {
        this.selectedIdValid = false;
        return;
      }

      if (this.columnForSelected) {
        const listId = this.columnForSelected.id;
        this.$emit('highlight-list', listId);
        return;
      }

      // eslint-disable-next-line @gitlab/require-i18n-strings
      await this.createList({ [`${this.columnType}Id`]: this.selectedId, position: this.position });
      this.$emit('set-add-column-form-visibility', false);
    },

    onSearch: debounce(function debouncedSearch(searchTerm) {
      this.searchTerm = searchTerm;
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),

    showScopedLabels(label) {
      return this.scopedLabelsAvailable && isScopedLabel(label);
    },

    setColumnType(type) {
      this.columnType = type;
      this.selectedId = null;
      this.setSelectedItem(null);
    },

    setSelectedItem(selectedId) {
      this.selectedId = selectedId;

      const item = this.items.find(({ id }) => id === selectedId);
      if (!selectedId || !item) {
        this.selectedItem = null;
      } else {
        this.selectedItem = { ...item };
      }
    },
    onHide() {
      this.searchValue = '';
      this.$emit('filter-items', '');
      this.$emit('hide');
    },

    getIterationPeriod,
  },
};
</script>

<template>
  <board-add-new-column-form
    :search-label="searchLabel"
    :selected-id-valid="selectedIdValid"
    @add-list="addList"
    @set-add-column-form-visibility="$emit('set-add-column-form-visibility', $event)"
  >
    <template #select-list-type>
      <gl-form-group
        v-if="showListTypeSelector"
        :description="$options.i18n.scopeDescription"
        class="gl-mb-3 gl-px-5 gl-py-0"
        label-for="list-type"
      >
        <gl-form-radio-group v-model="columnType">
          <gl-form-radio
            v-for="{ text, value } in columnTypes"
            :key="value"
            :value="value"
            class="gl-mb-0 gl-self-center"
            @change="setColumnType"
          >
            {{ text }}
          </gl-form-radio>
        </gl-form-radio-group>
      </gl-form-group>
    </template>

    <template #dropdown>
      <gl-collapsible-listbox
        block
        class="gl-mb-3 gl-max-w-full"
        :items="listboxItems"
        searchable
        :search-placeholder="info.searchPlaceholder"
        :searching="loading"
        :selected="selectedId"
        :no-results-text="$options.i18n.noResults"
        @select="setSelectedItem"
        @search="onSearch"
        @hidden="onHide"
      >
        <template #toggle="{ accessibilityAttributes }">
          <gl-button
            id="board-value-dropdown"
            v-bind="accessibilityAttributes"
            class="gl-flex gl-max-w-full gl-items-center gl-truncate"
            :class="{ '!gl-shadow-inner-1-red-400': !selectedIdValid }"
            button-text-classes="gl-flex"
          >
            <template v-if="hasLabelSelection">
              <span
                class="dropdown-label-box gl-top-0 gl-shrink-0"
                :style="{
                  backgroundColor: selectedItem.color,
                }"
              ></span>
              <div class="gl-truncate">{{ selectedItem.title }}</div>
            </template>

            <template v-else-if="hasMilestoneSelection">
              <gl-icon class="gl-shrink-0" name="milestone" />
              <span class="gl-truncate">{{ selectedItem.title }}</span>
            </template>

            <template v-else-if="hasIterationSelection">
              <gl-icon class="gl-shrink-0" name="iteration" />
              <span class="gl-truncate">{{
                selectedItem.title || getIterationPeriod(selectedItem, null, true)
              }}</span>
            </template>

            <template v-else-if="hasAssigneeSelection">
              <gl-avatar class="gl-mr-2 gl-shrink-0" :size="16" :src="selectedItem.avatarUrl" />
              <div class="gl-truncate">
                <b class="gl-mr-2">{{ selectedItem.name }}</b>
                <span class="gl-text-subtle">@{{ selectedItem.username }}</span>
              </div>
            </template>

            <template v-else-if="hasStatusSelection">
              <gl-icon
                :size="12"
                :name="selectedItem.iconName"
                class="gl-mr-1 gl-mt-1 gl-shrink-0"
                :style="{ color: selectedItem.color }"
              />
              <span class="gl-truncate">{{ selectedItem.name }}</span>
            </template>

            <template v-else>{{ info.noneSelected }}</template>
            <gl-icon class="dropdown-chevron gl-ml-2" name="chevron-down" />
          </gl-button>
        </template>

        <template #group-label="{ group }">
          {{ group.text }}
        </template>

        <template #list-item="{ item }">
          <label class="gl-mb-0 gl-flex gl-hyphens-auto gl-break-words gl-font-normal">
            <span
              v-if="labelTypeSelected"
              class="dropdown-label-box gl-top-0 gl-shrink-0"
              :style="{
                backgroundColor: item.color,
              }"
            ></span>

            <gl-avatar-labeled
              v-if="assigneeTypeSelected"
              class="gl-flex gl-items-center"
              :size="32"
              :label="item.name"
              :sub-label="`@${item.username}`"
              :src="item.avatarUrl"
            />
            <div
              v-else-if="iterationTypeSelected"
              class="gl-inline-block"
              data-testid="new-column-iteration-item"
            >
              {{ item.text }}
              <iteration-title v-if="item.title" :title="item.title" />
            </div>
            <div
              v-else-if="statusTypeSelected"
              class="gl-flex gl-gap-3"
              data-testid="status-list-item"
            >
              <gl-icon
                :name="item.iconName"
                :size="12"
                class="gl-mt-1 gl-shrink-0"
                :style="{ color: item.color }"
              />
              <span>{{ item.text }}</span>
            </div>
            <div v-else class="gl-inline-block">
              {{ item.text }}
            </div>
          </label>
        </template>
      </gl-collapsible-listbox>
    </template>
  </board-add-new-column-form>
</template>
