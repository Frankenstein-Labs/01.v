import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import App from './components/editor/app.vue';
import createApolloProvider from './apollo';

export default (el) => {
  if (!el) return null;

  const { namespacePath, organizationId, policyId, listPath } = el.dataset;

  return initVueApp({
    el,
    apolloProvider: createApolloProvider(),
    name: 'PolicyStoreEditorRoot',
    provide: {
      namespacePath,
      organizationId,
      policyId: policyId || '',
      listPath: listPath || '',
    },
    component: App,
  });
};
