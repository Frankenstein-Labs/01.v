import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import App from './components/list/app.vue';

export default (el) => {
  if (!el) return null;

  const { namespacePath, organizationId, emptyListSvgPath, newPolicyPath, listPath } = el.dataset;

  return initVueApp({
    el,
    name: 'PolicyStoreListRoot',
    provide: {
      namespacePath,
      organizationId,
      emptyListSvgPath,
      newPolicyPath: newPolicyPath || '',
      listPath: listPath || '',
    },
    component: App,
  });
};
