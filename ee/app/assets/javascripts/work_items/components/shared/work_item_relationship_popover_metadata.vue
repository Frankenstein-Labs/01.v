<script>
import { GlTooltipDirective, GlIcon, GlTooltip } from '@gitlab/ui';
import { humanTimeframe, newDate } from '~/lib/utils/datetime_utility';
import { getIterationPeriod } from 'ee/iterations/utils';
import WorkItemRelationshipPopoverMetadata from '~/work_items/components/shared/work_item_relationship_popover_metadata.vue';
import {
  findIterationWidget,
  findStartAndDueDateWidget,
  findWeightWidget,
} from '~/work_items/utils';

export default {
  name: 'WorkItemRelationshipPopoverMetadataEE',
  components: {
    GlIcon,
    GlTooltip,
    WorkItemRelationshipPopoverMetadata,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    workItem: {
      type: Object,
      required: true,
    },
    workItemFullPath: {
      type: String,
      required: true,
    },
  },
  computed: {
    workItemWeight() {
      return findWeightWidget(this.workItem)?.weight;
    },
    workItemIteration() {
      return findIterationWidget(this.workItem)?.iteration;
    },
    workItemStartDate() {
      return findStartAndDueDateWidget(this.workItem)?.startDate;
    },
    workItemDueDate() {
      return findStartAndDueDateWidget(this.workItem)?.dueDate;
    },
    showDate() {
      return this.workItemStartDate || this.workItemDueDate;
    },
    workItemTimeframe() {
      return humanTimeframe(newDate(this.workItemStartDate), newDate(this.workItemDueDate));
    },
    iterationPeriod() {
      return getIterationPeriod(this.workItemIteration);
    },
    iterationTitle() {
      return this.workItemIteration?.title;
    },
    iterationCadenceTitle() {
      return this.workItemIteration?.iterationCadence?.title;
    },
  },
};
</script>

<template>
  <work-item-relationship-popover-metadata
    :work-item="workItem"
    :work-item-full-path="workItemFullPath"
  >
    <template #weight-metadata>
      <span
        v-if="workItemWeight"
        v-gl-tooltip
        :title="__('Weight')"
        data-testid="item-weight"
        class="gl-flex gl-cursor-help gl-items-center gl-gap-2"
      >
        <gl-icon name="weight" />
        <span data-testid="weight-value">{{ workItemWeight }}</span>
      </span>
    </template>
    <template #additional-metadata>
      <div
        v-if="workItemIteration"
        ref="iterationInfo"
        data-testid="item-iteration"
        class="gl-flex gl-cursor-help gl-items-center gl-gap-2"
      >
        <gl-icon name="iteration" />
        <span data-testid="iteration-period">{{ iterationPeriod }}</span>
        <gl-tooltip :target="() => $refs.iterationInfo">
          <div class="gl-flex gl-flex-col">
            <span data-testid="iteration-title" class="gl-font-bold">{{ __('Iteration') }}</span>
            <span v-if="iterationCadenceTitle" data-testid="iteration-cadence">
              {{ iterationCadenceTitle }}
            </span>
            <span v-if="iterationPeriod" data-testid="iteration-value">
              {{ iterationPeriod }}
            </span>
            <span v-if="iterationTitle" data-testid="iteration-name">
              {{ iterationTitle }}
            </span>
          </div>
        </gl-tooltip>
      </div>
      <div
        v-if="showDate"
        v-gl-tooltip
        data-testid="item-dates"
        :title="__('Dates')"
        class="gl-flex gl-min-w-10 gl-max-w-26 gl-cursor-help gl-flex-wrap gl-gap-2"
      >
        <gl-icon name="calendar" />
        <span data-testid="dates-value">{{ workItemTimeframe }}</span>
      </div>
    </template>
  </work-item-relationship-popover-metadata>
</template>
