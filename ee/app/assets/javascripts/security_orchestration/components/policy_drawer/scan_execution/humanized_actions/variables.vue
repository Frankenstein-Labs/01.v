<script>
export default {
  name: 'HumanizedActionsVariables',
  props: {
    criteria: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <ul v-if="criteria.variables.length" class="gl-mt-2 gl-list-none gl-pl-0">
    <li v-for="{ variable, value } in criteria.variables" :key="variable">
      {{ variable }}: {{ value }}
    </li>
  </ul>
</template>
