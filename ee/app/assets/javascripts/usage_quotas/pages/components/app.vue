<script>
import ProjectList from './project_list.vue';
import PagesDeploymentStats from './stats.vue';

export default {
  name: 'PagesDeploymentsEE',
  components: { ProjectList, PagesDeploymentStats },
};
</script>

<template>
  <div class="gl-py-3">
    <div class="gl-mb-8">
      <pages-deployment-stats :title="s__('Pages|Parallel deployments')" />
    </div>
    <project-list />
  </div>
</template>
