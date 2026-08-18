import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import ProjectComplianceFrameworkEmptyState from './components/project_compliance_framework_empty_state.vue';

export default (selector = '#js-project-compliance-framework-empty-state') => {
  const el = document.querySelector(selector);

  if (!el) return;

  const { groupName, groupPath, addFrameworkPath, emptyStateSvgPath } = el.dataset;

  initVueApp({
    el,
    name: 'ProjectComplianceFrameworkEmptyStateRoot',
    component: ProjectComplianceFrameworkEmptyState,
    props: {
      groupName,
      groupPath,
      addFrameworkPath,
      emptyStateSvgPath,
    },
  });
};
