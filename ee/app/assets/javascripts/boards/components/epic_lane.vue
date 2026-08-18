<script>
import {
  GlButton,
  GlIcon,
  GlIntersectionObserver,
  GlLink,
  GlLoadingIcon,
  GlPopover,
  GlTooltipDirective,
} from '@gitlab/ui';
import { STATUS_OPEN } from '~/issues/constants';
import { localeDateFormat, newDate } from '~/lib/utils/datetime_utility';
import { __, n__, sprintf, s__ } from '~/locale';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import { formatListIssuesForLanes } from 'ee/boards/boards_util';
import listsIssuesQuery from '~/boards/graphql/lists_issues.query.graphql';
import { setError } from '~/boards/graphql/cache_updates';
import { BoardType } from 'ee_else_ce/boards/constants';
import updateBoardEpicUserPreferencesMutation from '../graphql/update_board_epic_user_preferences.mutation.graphql';
import IssuesLaneList from './issues_lane_list.vue';

export default {
  name: 'EpicLane',
  components: {
    GlButton,
    GlIcon,
    GlIntersectionObserver,
    GlLink,
    GlLoadingIcon,
    GlPopover,
    IssuesLaneList,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [timeagoMixin],
  inject: ['fullPath', 'boardType'],
  props: {
    epic: {
      type: Object,
      required: true,
    },
    lists: {
      type: Array,
      required: true,
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
    boardId: {
      type: String,
      required: true,
    },
    filterParams: {
      type: Object,
      required: true,
    },
    highlightedLists: {
      type: Array,
      required: false,
      default: () => [],
    },
    totalIssuesCountByListId: {
      type: Object,
      required: true,
    },
    rowIndex: {
      type: Number,
      required: true,
    },
  },
  emits: ['set-filters'],
  data() {
    const { userPreferences } = this.epic;

    const { collapsed = false } = userPreferences || {};

    return {
      isCollapsed: collapsed,
      listsWithIssues: [],
      showShadow: false,
      laneScrollOffset: 0,
    };
  },
  apollo: {
    listsWithIssues: {
      query: listsIssuesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          boardId: this.boardId,
          filters: { ...this.filterParams, epicId: this.epic.id, includeSubepics: false },
          isGroup: this.boardType === BoardType.group,
          isProject: this.boardType === BoardType.project,
        };
      },
      update(data) {
        return data[this.boardType]?.board.lists.nodes;
      },
      error(error) {
        setError({
          error,
          message: s__('Boards|An error occurred while fetching issues. Please try again.'),
        });
      },
    },
  },
  computed: {
    isOpen() {
      return this.epic.state === STATUS_OPEN;
    },
    chevronTooltip() {
      return this.isCollapsed ? __('Expand') : __('Collapse');
    },
    chevronIcon() {
      return this.isCollapsed ? 'chevron-right' : 'chevron-down';
    },
    issuesCount() {
      return this.listsWithIssues.reduce((total, list) => total + list.issues.nodes.length, 0);
    },
    issuesCountTooltipText() {
      return n__(`%d issue in this group`, `%d issues in this group`, this.issuesCount);
    },
    epicTimeAgoString() {
      return this.isOpen
        ? sprintf(__(`Created %{epicTimeagoDate}`), {
            epicTimeagoDate: this.timeFormatted(this.epic.createdAt),
          })
        : sprintf(__(`Closed %{epicTimeagoDate}`), {
            epicTimeagoDate: this.timeFormatted(this.epic.closedAt),
          });
    },
    epicDateString() {
      return localeDateFormat.asDateTimeFull.format(newDate(this.epic.createdAt));
    },
    isLoading() {
      return this.$apollo.queries.listsWithIssues.loading;
    },
    shouldDisplay() {
      return this.issuesCount > 0 || this.isLoading;
    },
    showIssuesLane() {
      return !this.isCollapsed && this.issuesCount > 0;
    },
    issuesByList() {
      return formatListIssuesForLanes(this.listsWithIssues);
    },
  },
  watch: {
    listsWithIssues() {
      this.setLaneScrollOffset();
    },
  },
  methods: {
    async toggleCollapsed() {
      this.isCollapsed = !this.isCollapsed;

      try {
        await this.$apollo.mutate({
          mutation: updateBoardEpicUserPreferencesMutation,
          variables: {
            boardId: this.boardId,
            epicId: this.epic.id,
            collapsed: this.isCollapsed,
          },
        });
      } catch (error) {
        setError({ error, message: __('Unable to save your preference') });
      }
    },
    getIssuesByList(listId) {
      return this.issuesByList[listId];
    },
    setLaneScrollOffset() {
      this.laneScrollOffset =
        document.querySelector('[data-testid="board-swimlanes-headers"]')?.getBoundingClientRect()
          .height || 0 + this.$refs.header.getBoundingClientRect().height;
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
  <div v-if="shouldDisplay" class="board-epic-lane-container">
    <div
      ref="header"
      class="board-epic-lane gl-sticky gl-inline-block gl-w-full gl-max-w-full"
      :class="{
        'board-epic-lane-shadow': !isCollapsed,
        show: showShadow,
      }"
      data-testid="board-epic-lane"
    >
      <div class="gl-flex gl-items-center gl-px-3 gl-py-3">
        <div class="gl-sticky gl-left-4 gl-flex gl-items-center">
          <gl-button
            v-gl-tooltip.hover.right
            :aria-label="chevronTooltip"
            :title="chevronTooltip"
            :icon="chevronIcon"
            class="gl-mr-2 gl-cursor-pointer"
            category="tertiary"
            size="small"
            @click="toggleCollapsed"
          />
          <h4
            ref="epicTitle"
            class="gl-my-0 gl-mr-3 gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap gl-text-base gl-font-bold"
          >
            {{ epic.title }}
          </h4>
          <gl-popover :target="() => $refs.epicTitle" placement="top">
            <template #title>{{ epic.title }} &middot; {{ epic.reference }}</template>
            <div>{{ epicTimeAgoString }}</div>
            <div class="gl-mb-2">{{ epicDateString }}</div>
            <gl-link :href="epic.webUrl" class="gl-text-sm">{{ __('Go to epic') }}</gl-link>
          </gl-popover>
          <span
            v-if="!isLoading"
            v-gl-tooltip.hover
            :title="issuesCountTooltipText"
            class="gl-flex gl-items-center gl-text-subtle"
            tabindex="0"
            :aria-label="issuesCountTooltipText"
            data-testid="epic-lane-issue-count"
          >
            <gl-icon class="gl-mr-2 gl-shrink-0" name="issues" />
            <span aria-hidden="true">{{ issuesCount }}</span>
          </span>
          <gl-loading-icon v-else class="gl-p-2" />
        </div>
      </div>
    </div>
    <div class="gl-relative">
      <div :style="`top: -${laneScrollOffset}px`" class="gl-absolute gl-w-full">
        <gl-intersection-observer @appear="setHideShadow" @disappear="setShowShadow">
          <div></div>
        </gl-intersection-observer>
      </div>
    </div>
    <div
      v-if="showIssuesLane"
      class="board-epic-lane-issues gl-flex gl-pb-5 gl-pt-3"
      data-testid="board-epic-lane-issues"
    >
      <issues-lane-list
        v-for="(list, index) in lists"
        :key="`${list.id}-issues`"
        :list="list"
        :issues="getIssuesByList(list.id)"
        :epic-id="epic.id"
        :epic-is-confidential="epic.confidential"
        :can-admin-list="canAdminList"
        :board-id="boardId"
        :filter-params="filterParams"
        :highlighted-lists="highlightedLists"
        :can-admin-epic="canAdminEpic"
        :lists="lists"
        :total-issues-count="totalIssuesCountByListId[list.id]"
        :row-index="rowIndex"
        :column-index="index"
        @set-filters="$emit('set-filters', $event)"
      />
    </div>
  </div>
</template>
