<script>
import { getIterationPeriod } from 'ee/iterations/utils';
import { formatDateRangeLongMonthDay } from '~/lib/utils/datetime_utility';
import { sprintf, __ } from '~/locale';
import WorkItemAttribute from '~/vue_shared/components/work_item_attribute.vue';

export default {
  name: 'IssueIteration',
  components: {
    WorkItemAttribute,
  },
  props: {
    iteration: {
      type: Object,
      required: true,
    },
  },
  computed: {
    iterationPeriod() {
      return getIterationPeriod(this.iteration, true);
    },
    showIterationCadenceTitle() {
      return this.iteration.iterationCadence?.title !== undefined;
    },
  },
  methods: {
    createAriaLabel() {
      const formattedIterationDate = formatDateRangeLongMonthDay(
        this.iteration.startDate,
        this.iteration.dueDate,
      );
      return sprintf(__(`Iteration: %{iterationDate}`), {
        iterationDate: formattedIterationDate,
      });
    },
  },
};
</script>

<template>
  <work-item-attribute
    anchor-id="issue-iteration-body"
    wrapper-component="button"
    wrapper-component-class="board-card-info gl-text-sm gl-text-subtle !gl-cursor-help gl-bg-transparent gl-border-0 gl-p-0 focus-visible:gl-focus-inset"
    icon-name="iteration"
    icon-class="gl-shrink-0"
    :title="iterationPeriod"
    title-component-class="board-card-info"
    tooltip-placement="top"
    :aria-label="createAriaLabel()"
  >
    <template #tooltip-text>
      <div class="gl-font-bold">{{ __('Iteration') }}</div>
      <div v-if="showIterationCadenceTitle" data-testid="issue-iteration-cadence-title">
        {{ iteration.iterationCadence.title }}
      </div>
      <div data-testid="issue-iteration-period">{{ iterationPeriod }}</div>
      <div v-if="iteration.title" data-testid="issue-iteration-title">{{ iteration.title }}</div>
    </template>
  </work-item-attribute>
</template>
