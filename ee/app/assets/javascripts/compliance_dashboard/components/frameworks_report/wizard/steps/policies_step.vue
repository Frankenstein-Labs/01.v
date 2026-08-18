<script>
import PoliciesSection from '../components/policies_section.vue';

export default {
  name: 'PoliciesStep',
  components: { PoliciesSection },
  props: {
    count: {
      type: Number,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
    graphqlId: {
      type: String,
      required: true,
    },
    isInherited: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['policies-count-loaded'],
};
</script>

<template>
  <policies-section
    :count="count"
    :full-path="fullPath"
    :graphql-id="graphqlId"
    :is-inherited="isInherited"
    @policies-count-loaded="$emit('policies-count-loaded', $event)"
  />
</template>
