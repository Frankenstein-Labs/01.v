<script>
import ProjectsSection from '../components/projects_section.vue';

export default {
  name: 'ProjectsStep',
  components: { ProjectsSection },
  props: {
    complianceFramework: {
      type: Object,
      required: true,
    },
    groupPath: {
      type: String,
      required: true,
    },
  },
  emits: ['update:projects'],
};
</script>

<template>
  <projects-section
    :compliance-framework="complianceFramework"
    :group-path="groupPath"
    @update:projects="$emit('update:projects', $event)"
  />
</template>
