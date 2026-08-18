<script>
import { GlButton, GlIcon, GlIntersectionObserver, GlTooltipDirective } from '@gitlab/ui';
import VirtualList from 'vue-virtual-scroll-list';
import Draggable from '~/lib/utils/vue3compat/draggable_compat.vue';
import BoardListHeader from 'ee_else_ce/boards/components/board_list_header.vue';
import { isListDraggable } from '~/boards/boards_util';
import { setError } from '~/boards/graphql/cache_updates';
import { s__, __ } from '~/locale';
import { defaultSortableOptions } from '~/sortable/constants';
import {
  BoardType,
  DRAGGABLE_TAG,
  EPIC_LANE_BASE_HEIGHT,
  DraggableItemTypes,
} from 'ee/boards/constants';
import { calculateSwimlanesBufferSize } from '../boards_util';
import epicsSwimlanesQuery from '../graphql/epics_swimlanes.query.graphql';
import EpicLane from './epic_lane.vue';
import IssuesLaneList from './issues_lane_list.vue';
import SwimlanesLoadingSkeleton from './swimlanes_loading_skeleton.vue';

export default {
  name: 'EpicsSwimlanes',
  epicLaneBaseHeight: EPIC_LANE_BASE_HEIGHT,
  draggableItemTypes: DraggableItemTypes,
  components: {
    BoardListHeader,
    EpicLane,
    IssuesLaneList,
    GlButton,
    GlIcon,
    GlIntersectionObserver,
    SwimlanesLoadingSkeleton,
    VirtualList,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['boardType', 'disabled', 'fullPath'],
  props: {
    lists: {
      type: Array,
      required: true,
    },
    canAdminList: {
      type: Boolean,
      required: false,
      default: false,
    },
    filters: {
      type: Object,
      required: true,
    },
    boardId: {
      type: String,
      required: true,
    },
    highlightedLists: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['move-list', 'set-active-list', 'set-filters'],
  data() {
    return {
      bufferSize: 0,
      isUnassignedCollapsed: true,
      rawEpics: {},
      isLoadingMore: false,
      hasMoreUnassignedIssuables: {},
      isLoadingMoreIssues: false,
      totalIssuesCountByListId: {},
      showNewForm: [],
      showShadow: false,
      laneScrollOffset: 0,
    };
  },
  apollo: {
    rawEpics: {
      query: epicsSwimlanesQuery,
      variables() {
        return {
          ...this.baseVariables,
          issueFilters: { ...this.filters, includeSubepics: false },
          sort: 'TITLE_ASC',
        };
      },
      update(data) {
        return data[this.boardType].board.epics;
      },
      error(error) {
        setError({
          error,
          message: s__('Boards|An error occurred while fetching epics. Please try again.'),
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
      };
    },
    epics() {
      return this.rawEpics?.nodes || [];
    },
    pageInfo() {
      return this.rawEpics.pageInfo;
    },
    hasMoreEpicsToLoad() {
      return this.pageInfo?.hasNextPage;
    },
    isLoadingMoreEpics() {
      return this.isLoadingMore;
    },
    canAdminEpic() {
      return this.epics[0]?.userPermissions?.adminEpic;
    },
    treeRootWrapper() {
      return this.canAdminList ? Draggable : DRAGGABLE_TAG;
    },
    treeRootOptions() {
      const options = {
        ...defaultSortableOptions,
        fallbackOnBody: false,
        group: 'board-swimlanes',
        tag: DRAGGABLE_TAG,
        draggable: '.is-draggable',
        'ghost-class': 'swimlane-header-drag-active',
        value: this.lists,
      };

      return this.canAdminList ? options : {};
    },
    hasMoreUnassignedIssues() {
      return this.lists.some((list) => this.hasMoreUnassignedIssuables[list.id]);
    },
    isLoading() {
      return this.$apollo.queries.rawEpics.loading && !this.isLoadingMoreEpics;
    },
    chevronTooltip() {
      return this.isUnassignedCollapsed ? __('Expand') : __('Collapse');
    },
    chevronIcon() {
      return this.isUnassignedCollapsed ? 'chevron-right' : 'chevron-down';
    },
    epicButtonLabel() {
      return this.isLoadingMoreEpics ? s__('Boards|Loading epics') : s__('Boards|Load more epics');
    },
    shouldShowLoadMoreUnassignedIssues() {
      return !this.isUnassignedCollapsed && this.hasMoreUnassignedIssues;
    },
  },
  watch: {
    isUnassignedCollapsed() {
      this.setLaneScrollOffset();
    },
  },
  mounted() {
    this.bufferSize = calculateSwimlanesBufferSize(this.$el.offsetTop);
  },
  methods: {
    async fetchMoreEpics() {
      this.isLoadingMore = true;
      await this.$apollo.queries.rawEpics.fetchMore({
        variables: {
          ...this.baseVariables,
          issueFilters: { ...this.filters, includeSubepics: false },
          sort: 'TITLE_ASC',
          after: this.pageInfo.endCursor,
        },
      });
      this.isLoadingMore = false;
    },
    fetchMoreUnassignedIssues() {
      this.isLoadingMoreIssues = true;
    },
    isListDraggable(list) {
      return isListDraggable(list);
    },
    afterFormEnters() {
      const container = this.$refs.scrollableContainer;
      container.scrollTo({
        left: container.scrollWidth,
        behavior: 'smooth',
      });
    },
    toggleUnassignedLane() {
      this.isUnassignedCollapsed = !this.isUnassignedCollapsed;
    },
    openUnassignedLane() {
      this.isUnassignedCollapsed = false;
    },
    updatePageInfo(pageInfo, listId) {
      this.hasMoreUnassignedIssuables = {
        ...this.hasMoreUnassignedIssuables,
        [listId]: pageInfo.hasNextPage,
      };
    },
    setTotalIssuesCount(listId, count) {
      this.totalIssuesCountByListId[listId] = count;
    },
    toggleNewForm(listId) {
      if (this.showNewForm.includes(listId)) {
        this.showNewForm.splice(this.showNewForm.indexOf(listId), 1);
      } else {
        this.showNewForm = [...this.showNewForm, listId];
      }
    },
    setLaneScrollOffset() {
      this.laneScrollOffset = document
        .querySelector('[data-testid="board-swimlanes-headers"]')
        ?.getBoundingClientRect().height;
    },
    setShowShadow() {
      this.showShadow = true;
    },
    setHideShadow() {
      this.showShadow = false;
    },
  },
};
</script>

<template>
  <div
    ref="scrollableContainer"
    class="board-swimlanes gl-flex gl-grow gl-whitespace-nowrap @xl/panel:gl-pl-3 @xl/panel:gl-pr-6"
    data-testid="board-swimlanes"
  >
    <swimlanes-loading-skeleton v-if="isLoading" />
    <div v-else class="board-swimlanes-content">
      <component
        :is="treeRootWrapper"
        v-bind="treeRootOptions"
        item-key="id"
        class="board-swimlanes-headers gl-sticky gl-top-0 gl-z-3 gl-table"
        data-testid="board-swimlanes-headers"
        @end="$emit('move-list', $event)"
      >
        <div
          v-for="list in lists"
          :key="list.id"
          :class="{
            'is-collapsed gl-w-10': list.collapsed,
            'is-draggable': isListDraggable(list),
          }"
          class="board gl-inline-block gl-whitespace-normal gl-px-3 gl-align-top"
          :data-list-id="list.id"
          data-testid="board-header-container"
          :data-draggable-item-type="$options.draggableItemTypes.list"
        >
          <board-list-header
            :can-admin-list="canAdminList"
            :list="list"
            :filter-params="filters"
            :is-swimlanes-header="true"
            :board-id="boardId"
            class="gl-rounded-base"
            @toggle-new-form="toggleNewForm(list.id)"
            @set-active-list="$emit('set-active-list', $event)"
            @open-unassigned-lane="openUnassignedLane"
            @set-total-issues-count="setTotalIssuesCount"
          />
        </div>
      </component>
      <div class="board-epics-swimlanes gl-table">
        <virtual-list
          v-if="epics.length"
          :size="$options.epicLaneBaseHeight"
          :remain="bufferSize"
          :bench="bufferSize"
          :scrollelement="$refs.scrollableContainer"
        >
          <epic-lane
            v-for="(epic, index) in epics"
            :key="epic.id"
            :epic="epic"
            :lists="lists"
            :disabled="disabled"
            :can-admin-list="canAdminList"
            :board-id="boardId"
            :filter-params="filters"
            :highlighted-lists="highlightedLists"
            :can-admin-epic="canAdminEpic"
            :total-issues-count-by-list-id="totalIssuesCountByListId"
            :row-index="index"
            @set-filters="$emit('set-filters', $event)"
          />
        </virtual-list>
        <div
          v-if="hasMoreEpicsToLoad || isLoadingMoreEpics"
          class="swimlanes-button gl-sticky gl-pb-3 gl-pl-3"
        >
          <gl-button
            category="tertiary"
            variant="confirm"
            class="gl-w-full"
            :loading="isLoadingMoreEpics"
            :disabled="isLoadingMoreEpics"
            data-testid="load-more-epics"
            data-track-action="click_button"
            data-track-label="toggle_swimlanes"
            data-track-property="click_load_more_epics"
            @click="fetchMoreEpics"
          >
            {{ epicButtonLabel }}
          </gl-button>
        </div>
        <div>
          <div class="gl-relative">
            <div :style="`top: -${laneScrollOffset}px`" class="gl-absolute gl-w-full">
              <gl-intersection-observer @appear="setHideShadow" @disappear="setShowShadow">
                <div></div>
              </gl-intersection-observer>
            </div>
          </div>
          <div
            class="board-lane-unassigned-issues-title gl-sticky gl-left-0 gl-inline-block gl-w-full gl-max-w-full"
            :class="{
              'board-epic-lane-shadow': !isUnassignedCollapsed,
              show: showShadow,
            }"
            data-testid="board-lane-unassigned-issues-title"
          >
            <div class="gl-flex gl-items-center gl-px-3 gl-py-3">
              <div class="gl-sticky gl-left-4">
                <gl-button
                  v-gl-tooltip.hover.right
                  :aria-label="chevronTooltip"
                  :title="chevronTooltip"
                  :icon="chevronIcon"
                  class="gl-mr-2 gl-cursor-pointer"
                  category="tertiary"
                  size="small"
                  data-testid="unassigned-lane-toggle"
                  @click="toggleUnassignedLane"
                />
                <span
                  class="gl-mr-3 gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap gl-font-bold"
                >
                  {{ __('Issues with no epic assigned') }}
                </span>
              </div>
            </div>
          </div>
          <div v-if="!isUnassignedCollapsed" data-testid="board-lane-unassigned-issues">
            <div class="gl-flex gl-pt-3">
              <issues-lane-list
                v-for="(list, index) in lists"
                :key="`${list.id}-issues`"
                :list="list"
                :is-unassigned-issues-lane="true"
                :can-admin-list="canAdminList"
                :board-id="boardId"
                :filter-params="filters"
                :is-loading-more-issues="isLoadingMoreIssues"
                :highlighted-lists="highlightedLists"
                :can-admin-epic="canAdminEpic"
                :lists="lists"
                :row-index="epics.length"
                :column-index="index"
                :total-issues-count="totalIssuesCountByListId[list.id]"
                :show-new-form="showNewForm.indexOf(list.id) > -1"
                @toggle-new-form="toggleNewForm(list.id)"
                @update-page-info="updatePageInfo"
                @issues-loaded="isLoadingMoreIssues = false"
                @set-filters="$emit('set-filters', $event)"
              />
            </div>
          </div>
        </div>
      </div>
      <div
        v-if="shouldShowLoadMoreUnassignedIssues"
        class="swimlanes-button gl-sticky gl-left-0 gl-p-3 gl-pr-0"
      >
        <gl-button
          category="tertiary"
          variant="confirm"
          class="gl-w-full"
          data-testid="board-lane-load-more-issues-button"
          @click="fetchMoreUnassignedIssues()"
        >
          {{ s__('Boards|Load more issues') }}
        </gl-button>
      </div>
      <!-- placeholder for some space below lane lists -->
      <div v-else class="gl-pb-5"></div>
    </div>

    <slot name="create-list-button"></slot>

    <transition name="slide" @after-enter="afterFormEnters">
      <slot></slot>
    </transition>
  </div>
</template>
