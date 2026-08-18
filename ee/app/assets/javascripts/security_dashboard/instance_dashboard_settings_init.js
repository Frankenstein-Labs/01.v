import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import ProjectManager from './components/instance/project_manager.vue';
import apolloProvider from './graphql/provider';

export default (el) => {
  if (!el) {
    return null;
  }

  const { isAuditor } = el.dataset;

  return initVueApp({
    el,
    name: 'SecurityDashboardSettingsRoot',
    apolloProvider,
    component: ProjectManager,
    props: {
      isAuditor: parseBoolean(isAuditor),
    },
  });
};
