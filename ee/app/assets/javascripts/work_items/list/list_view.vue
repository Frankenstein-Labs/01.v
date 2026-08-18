<script>
import { GlEmptyState } from '@gitlab/ui';
import emptyStateSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-epic-md.svg';
import { findStatusWidget } from '~/work_items/utils';
import { DEFAULT_PAGE_SIZE } from '~/vue_shared/issuable/list/constants';
import ListView from '~/work_items/list/list_view.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import EmptyStateWithAnyIssues from '~/work_items/list/components/empty_state_with_any_issues.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import { NAMESPACE_GROUP, NAMESPACE_PROJECT } from '~/issues/constants';
import { WORK_ITEM_TYPE_NAME_EPIC, CREATION_CONTEXT_LIST_ROUTE } from '~/work_items/constants';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  name: 'ListViewEE',
  CREATION_CONTEXT_LIST_ROUTE,
  emptyStateSvg,
  WORK_ITEM_TYPE_NAME_EPIC,
  components: {
    GlEmptyState,
    ListView,
    WorkItemStatusBadge,
    EmptyStateWithAnyIssues,
    CreateWorkItemModal,
  },
  mixins: [glListenersMixin],
  inject: [
    'hasEpicsFeature',
    'isGroup',
    'showNewWorkItem',
    'workItemType',
    'hasCustomFieldsFeature',
    'hasIssueWeightsFeature',
    'hasIssuableHealthStatusFeature',
    'hasStatusFeature',
    'hasIterationsFeature',
  ],
  props: {
    rootPageFullPath: {
      type: String,
      required: true,
    },
    queryVariables: {
      type: Object,
      required: true,
    },
    skipQuery: {
      type: Boolean,
      required: false,
      default: false,
    },
    withTabs: {
      type: Boolean,
      required: false,
      default: true,
    },
    hasWorkItems: {
      type: Boolean,
      required: true,
    },
    error: {
      type: String,
      required: false,
      default: undefined,
    },
    initialLoadWasFiltered: {
      type: Boolean,
      required: true,
    },
    showBulkEditSidebar: {
      type: Boolean,
      required: true,
    },
    checkedIssuableIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    displaySettings: {
      type: Object,
      required: false,
      default: () => {},
    },
    pageSize: {
      type: Number,
      required: false,
      default: DEFAULT_PAGE_SIZE,
    },
    filterTokens: {
      type: Array,
      required: false,
      default: () => [],
    },
    apiFilterParams: {
      type: Object,
      required: false,
      default: () => {},
    },
    sortKey: {
      type: String,
      required: true,
    },
    isSortKeyInitialized: {
      type: Boolean,
      required: true,
    },
    state: {
      type: String,
      required: true,
    },
    activeItem: {
      type: Object,
      required: false,
      default: null,
    },
    workItemsCount: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  emits: [
    'refetch-data',
    'dismiss-alert',
    'set-error',
    'set-active-item',
    'work-items-changed',
    'namespace-data-loaded',
  ],
  computed: {
    namespace() {
      return !this.isGroup ? NAMESPACE_PROJECT : NAMESPACE_GROUP;
    },
    isEpicsList() {
      return this.workItemType === WORK_ITEM_TYPE_NAME_EPIC;
    },
  },
  methods: {
    hasStatus(issuable) {
      return Boolean(findStatusWidget(issuable)?.status);
    },
    issuableStatusItem(issuable) {
      return findStatusWidget(issuable)?.status || {};
    },
  },
};
</script>

<template>
  <list-view v-bind="$props" v-on="glListeners()">
    <template
      v-if="isEpicsList && hasEpicsFeature"
      #list-empty-state="{ hasSearch, isOpenTab, withTabs: showTabs }"
    >
      <empty-state-with-any-issues
        :has-search="hasSearch"
        :is-epic="isEpicsList"
        :is-open-tab="isOpenTab"
        :with-tabs="showTabs"
      >
        <template v-if="showNewWorkItem" #new-issue-button>
          <create-work-item-modal
            class="gl-grow"
            :creation-context="$options.CREATION_CONTEXT_LIST_ROUTE"
            :full-path="rootPageFullPath"
            :is-group="isGroup"
            :preselected-work-item-type="$options.WORK_ITEM_TYPE_NAME_EPIC"
          />
        </template>
      </empty-state-with-any-issues>
    </template>
    <template v-else #list-empty-state="{ hasSearch, isOpenTab, withTabs: showTabs }">
      <slot
        name="list-empty-state"
        :has-search="hasSearch"
        :is-open-tab="isOpenTab"
        :with-tabs="showTabs"
      ></slot>
    </template>

    <template v-if="isEpicsList && hasEpicsFeature" #page-empty-state>
      <gl-empty-state
        :description="
          __('Track groups of issues that share a theme, across projects and milestones')
        "
        :svg-path="$options.emptyStateSvg"
        :title="
          __(
            'Epics let you manage your portfolio of projects more efficiently and with less effort',
          )
        "
      >
        <template v-if="showNewWorkItem" #actions>
          <create-work-item-modal
            class="gl-grow"
            :creation-context="$options.CREATION_CONTEXT_LIST_ROUTE"
            :full-path="rootPageFullPath"
            :is-group="isGroup"
            :preselected-work-item-type="$options.WORK_ITEM_TYPE_NAME_EPIC"
          />
        </template>
      </gl-empty-state>
    </template>
    <template #custom-status="{ issuable = {} }">
      <work-item-status-badge v-if="hasStatus(issuable)" :item="issuableStatusItem(issuable)" />
    </template>
  </list-view>
</template>
