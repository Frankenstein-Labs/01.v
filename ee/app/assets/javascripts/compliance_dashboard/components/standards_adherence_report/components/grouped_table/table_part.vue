<script>
import { GlTable, GlLink, GlButton } from '@gitlab/ui';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { s__ } from '~/locale';
import FrameworkBadge from '../../../shared/framework_badge.vue';
import RequirementStatusWithTooltip from './requirement_status_with_tooltip.vue';

export default {
  components: {
    GlTable,
    GlButton,
    GlLink,
    TimeAgoTooltip,

    FrameworkBadge,
    RequirementStatusWithTooltip,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    fields: {
      type: Array,
      required: true,
    },
    theadClass: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['row-selected'],
  i18n: {
    viewDetails: s__('ComplianceStandardsAdherence|View details'),
  },
};
</script>

<template>
  <gl-table
    :items="items"
    :fields="fields"
    :thead-class="theadClass"
    stacked="md"
    selectable
    select-mode="single"
    selected-variant
    hover
    @row-selected="$emit('row-selected', $event[0])"
  >
    <template #cell(status)="{ item }">
      <requirement-status-with-tooltip :status="item" />
    </template>
    <template #cell(requirement)="{ item: { complianceRequirement: requirement } }">
      {{ requirement.name }}
    </template>
    <template #cell(framework)="{ item: { complianceFramework: framework } }">
      <framework-badge popover-mode="details" :framework="framework" />
    </template>
    <template #cell(project)="{ value: project }">
      <gl-link :href="project.webUrl">{{ project.name }}</gl-link>
    </template>
    <template #cell(lastScanned)="{ item: { updatedAt } }">
      <time-ago-tooltip :time="updatedAt" />
    </template>
    <template #cell(fixSuggestions)="{ item }">
      <gl-button variant="link" @click="$emit('row-selected', item)">
        {{ $options.i18n.viewDetails }}
      </gl-button>
    </template>
  </gl-table>
</template>
