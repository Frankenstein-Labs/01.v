<script>
import { GlButton, GlIcon, GlLabel, GlTooltip } from '@gitlab/ui';
import { isEmpty } from 'lodash-es';

import { getIdFromGraphQLId, getNodesOrDefault } from '~/graphql_shared/utils';
import { convertObjectPropsToCamelCase, isScopedLabel } from '~/lib/utils/common_utils';
import { queryToObject, updateHistory } from '~/lib/utils/url_utility';
import { __, n__ } from '~/locale';
import WorkItemRelationshipIcons from '~/work_items/components/shared/work_item_relationship_icons.vue';
import { EPIC_LEVEL_MARGIN, UNSUPPORTED_ROADMAP_PARAMS } from '../constants';
import updateLocalRoadmapSettingsMutation from '../queries/update_local_roadmap_settings.mutation.graphql';

export default {
  name: 'EpicItemDetails',
  components: {
    GlButton,
    GlIcon,
    GlLabel,
    GlTooltip,
    WorkItemRelationshipIcons,
  },
  epicSymbol: '&',
  inject: ['allowSubEpics', 'allowScopedLabels', 'currentGroupId'],
  props: {
    epic: {
      type: Object,
      required: true,
    },
    epicsHaveChildren: {
      type: Boolean,
      required: false,
      default: false,
    },
    timeframeString: {
      type: String,
      required: true,
    },
    childLevel: {
      type: Number,
      required: true,
    },
    isChildrenEmpty: {
      type: Boolean,
      required: false,
      default: false,
    },
    isExpanded: {
      type: Boolean,
      required: true,
    },
    isFetchingChildren: {
      type: Boolean,
      required: true,
    },
    filterParams: {
      type: Object,
      required: true,
    },
    isShowingLabels: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['toggle-epic'],
  computed: {
    hasFiltersApplied() {
      return !isEmpty(this.filterParams);
    },
    epicIid() {
      return this.epic.iid;
    },
    epicGroupId() {
      return getIdFromGraphQLId(this.epic.group.id);
    },
    epicWebUrl() {
      return this.epic.webUrl || this.epic.webPath;
    },
    workItemFullPath() {
      return (
        this.epic.namespace?.fullPath || this.epic.reference?.split(this.$options.epicSymbol)[0]
      );
    },
    isEpicGroupDifferent() {
      return this.currentGroupId !== this.epicGroupId;
    },
    isExpandIconHidden() {
      return !this.epic.hasChildrenWithinTimeframe;
    },
    isEmptyChildrenWithFilter() {
      return this.isExpanded && this.hasFiltersApplied && this.isChildrenEmpty;
    },
    expandIconName() {
      if (this.isEmptyChildrenWithFilter) {
        return 'information-o';
      }
      return this.isExpanded ? 'chevron-down' : 'chevron-right';
    },
    infoSearchLabel() {
      return __('No child epics match applied filters');
    },
    expandIconLabel() {
      if (this.isEmptyChildrenWithFilter) {
        return this.infoSearchLabel;
      }
      return this.isExpanded ? __('Collapse') : __('Expand');
    },
    childEpicsCount() {
      const { openedEpics = 0, closedEpics = 0 } = this.epic.descendantCounts;
      return openedEpics + closedEpics;
    },
    childEpicsCountText() {
      return Number.isInteger(this.childEpicsCount)
        ? n__(`%d child epic`, `%d child epics`, this.childEpicsCount)
        : '';
    },
    childEpicsSearchText() {
      return __('Some child epics may be hidden due to applied filters');
    },
    childMarginClassname() {
      return EPIC_LEVEL_MARGIN[this.childLevel];
    },
    epicLabels() {
      return getNodesOrDefault(this.epic.labels);
    },
    hasLabels() {
      return this.epicLabels.length > 0;
    },
    blockingCount() {
      return this.epic?.blockingCount || 0;
    },
    blockedByCount() {
      return this.epic?.blockedByCount || 0;
    },
    hasBlockingRelationships() {
      return this.blockingCount > 0 || this.blockedByCount > 0;
    },
  },
  methods: {
    toggleEpic() {
      if (!this.isEmptyChildrenWithFilter) {
        this.$emit('toggle-epic');
      }
    },
    filterByLabelUrl(label) {
      const filterPath = window.location.search ? `${window.location.search}&` : '?';
      const filter = `label_name[]=${encodeURIComponent(label.title)}`;
      return `${filterPath}${filter}`;
    },
    filterByLabel(label) {
      const alreadySelected = this.filterParams?.labelName?.includes(label.title);

      if (!alreadySelected) {
        updateHistory({
          url: this.filterByLabelUrl(label),
        });
        this.setFilterParams(
          convertObjectPropsToCamelCase(
            queryToObject(window.location.search, { gatherArrays: true }),
            { dropKeys: UNSUPPORTED_ROADMAP_PARAMS },
          ),
        );
      }
    },
    scopedLabel(label) {
      return this.allowScopedLabels && isScopedLabel(label);
    },
    setFilterParams(filterParams) {
      this.$apollo.mutate({
        mutation: updateLocalRoadmapSettingsMutation,
        variables: {
          input: {
            filterParams,
          },
        },
      });
    },
  },
};
</script>

<template>
  <div
    class="epic-details-cell gl-flex gl-flex-col gl-justify-center"
    data-testid="epic-details-cell"
  >
    <div
      class="gl-flex !gl-items-start gl-p-3 gl-pl-5 @xl/panel:gl-pl-6"
      :class="[epic.isChildEpic ? childMarginClassname : '']"
      data-testid="epic-container"
    >
      <span ref="expandCollapseInfo">
        <gl-button
          :class="{
            'gl-invisible': isExpandIconHidden,
            'gl-hidden': !epicsHaveChildren,
          }"
          :aria-label="expandIconLabel"
          category="tertiary"
          size="small"
          :icon="expandIconName"
          :loading="isFetchingChildren"
          @click="toggleEpic"
        />
      </span>
      <gl-tooltip
        v-if="!isExpandIconHidden"
        ref="expandIconTooltip"
        triggers="hover"
        :target="() => $refs.expandCollapseInfo"
        boundary="viewport"
        offset="15"
        placement="topright"
        data-testid="expand-icon-tooltip"
      >
        {{ expandIconLabel }}
      </gl-tooltip>
      <div class="!gl-mx-2 gl-w-13 gl-grow">
        <a
          :href="epic.webUrl"
          :title="epic.title"
          class="epic-title gl-mt-1 gl-text-wrap gl-font-bold gl-text-default"
          data-testid="epic-title"
        >
          {{ epic.title }}
        </a>
        <div class="epic-group-timeframe gl-mt-2 gl-flex gl-text-subtle">
          <span
            v-if="isEpicGroupDifferent && !epic.hasParent"
            :title="epic.group.fullName"
            class="epic-group"
            data-testid="epic-group"
          >
            {{ epic.group.name }}
          </span>
          <span v-if="isEpicGroupDifferent && !epic.hasParent" class="!gl-mx-2" aria-hidden="true"
            >&middot;</span
          >
          <span class="epic-timeframe" :title="timeframeString">{{ timeframeString }}</span>
        </div>
        <div v-if="hasLabels && isShowingLabels" data-testid="epic-labels" class="gl-mt-2">
          <gl-label
            v-for="label in epicLabels"
            :key="label.id"
            class="js-no-trigger gl-mr-2 gl-mt-2"
            :background-color="label.color"
            :title="label.title"
            :target="filterByLabelUrl(label)"
            :description="label.description"
            :scoped="scopedLabel(label)"
            @click.prevent="filterByLabel(label)"
          />
        </div>
      </div>
      <div class="gl-flex gl-flex-col gl-items-end gl-text-subtle">
        <div v-if="allowSubEpics">
          <div
            ref="childEpicsCount"
            class="gl-mb-2 gl-flex gl-justify-end !gl-whitespace-nowrap"
            data-testid="child-epics-count"
          >
            <gl-icon name="epic" class="!gl-mr-2 !gl-align-text-bottom" />
            <p class="!gl-m-0" :aria-label="childEpicsCountText">{{ childEpicsCount }}</p>
          </div>
          <gl-tooltip
            ref="childEpicsCountTooltip"
            :target="() => $refs.childEpicsCount"
            data-testid="child-epics-count-tooltip"
          >
            <span :class="{ 'gl-font-bold': hasFiltersApplied }">{{ childEpicsCountText }}</span>
            <span v-if="hasFiltersApplied" class="gl-block">{{ childEpicsSearchText }}</span>
          </gl-tooltip>
        </div>
        <work-item-relationship-icons
          v-if="hasBlockingRelationships"
          work-item-type="epic"
          :work-item-full-path="workItemFullPath"
          :work-item-iid="epicIid"
          :work-item-web-url="epicWebUrl"
          :blocking-count="blockingCount"
          :blocked-by-count="blockedByCount"
        />
      </div>
    </div>
  </div>
</template>
