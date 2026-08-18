<script>
import { GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { getDayDifference, localeDateFormat, newDate } from '~/lib/utils/datetime_utility';
import { __ } from '~/locale';

export default {
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlIcon,
  },
  props: {
    dueDate: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    dueDateInWords() {
      return localeDateFormat.asDate.format(newDate(this.dueDate));
    },
    formattedDueDate() {
      const today = new Date();
      const date = newDate(this.dueDate);
      const isOverdue = getDayDifference(today, date) < 0;

      let formattedDate = this.dueDateInWords;

      if (isOverdue) {
        formattedDate += ` (${__('overdue')})`;
      }

      return formattedDate;
    },
    dueDateTooltipProps() {
      return {
        boundary: 'viewport',
        placement: 'left',
        title: this.dueDate
          ? `${this.$options.i18n.dueDateTitle}<br>${this.formattedDueDate}`
          : this.$options.i18n.dueDateTitle,
      };
    },
  },
  i18n: {
    dueDateTitle: __('Due date'),
    none: __('None'),
  },
};
</script>

<template>
  <div class="block">
    <div
      v-gl-tooltip.html="dueDateTooltipProps"
      class="sidebar-collapsed-icon"
      data-testid="due-date-collapsed"
    >
      <gl-icon name="calendar" />
      <span v-if="dueDate">{{ dueDateInWords }}</span>
      <span v-else>{{ $options.i18n.none }}</span>
    </div>

    <div class="hide-collapsed">
      <div class="gl-mb-2 gl-font-bold gl-leading-20 gl-text-default">
        {{ $options.i18n.dueDateTitle }}
      </div>
      <div class="gl-leading-1" data-testid="due-date-value">
        <span v-if="dueDate" class="gl-font-bold">{{ formattedDueDate }}</span>
        <span v-else class="gl-text-subtle">{{ $options.i18n.none }}</span>
      </div>
    </div>
  </div>
</template>
