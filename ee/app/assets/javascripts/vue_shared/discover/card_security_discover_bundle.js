import SecurityDiscoverApp from 'ee/vue_shared/discover/card_security_discover_app.vue';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';

export default () => {
  const securityTab = document.getElementById('js-security-discover-app');
  if (!securityTab) {
    return null;
  }

  const { projectId, projectName, projectPersonal, linkMain, linkSecondary } = securityTab.dataset;

  const props = {
    project: {
      id: projectId,
      name: projectName,
      isPersonal: parseBoolean(projectPersonal),
    },
    linkMain,
    linkSecondary,
  };

  return initVueApp({
    el: securityTab,
    name: 'SecurityDiscoverRoot',
    component: SecurityDiscoverApp,
    props,
  });
};
