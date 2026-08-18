<script>
import RequirementsSection from '../components/requirements_section.vue';
import { requirementEvents } from '../constants';

export default {
  name: 'RequirementsStep',
  components: { RequirementsSection },
  props: {
    requirements: {
      type: Array,
      required: true,
    },
    isNewFramework: {
      type: Boolean,
      required: true,
    },
    isInherited: {
      type: Boolean,
      required: false,
      default: false,
    },
    readonly: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: [requirementEvents.create, requirementEvents.update, requirementEvents.delete],
  requirementEvents,
};
</script>

<template>
  <requirements-section
    :requirements="requirements"
    :is-new-framework="isNewFramework"
    :is-inherited="isInherited"
    :readonly="readonly"
    @[$options.requirementEvents.create]="$emit($options.requirementEvents.create, $event)"
    @[$options.requirementEvents.update]="$emit($options.requirementEvents.update, $event)"
    @[$options.requirementEvents.delete]="$emit($options.requirementEvents.delete, $event)"
  />
</template>
