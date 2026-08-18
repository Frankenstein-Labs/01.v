import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import WorkspacesBreadcrumbs from './components/workspaces_breadcrumbs.vue';
import App from './pages/app.vue';
import createRouter from './router/index';

Vue.use(VueApollo);
Vue.use(GlToast);

const createApolloProvider = () => {
  const defaultClient = createDefaultClient();

  return new VueApollo({ defaultClient });
};

const initUserWorkspacesApp = () => {
  const el = document.querySelector('#js-workspaces');

  if (!el) {
    return null;
  }

  const { workspacesListPath, ...options } = convertObjectPropsToCamelCase(
    JSON.parse(el.dataset.options),
  );
  // noinspection JSUnresolvedReference -- Avoids error on options property access. Adding `@returns {Object|Array}` to convertObjectPropsToCamelCase didn't help. TODO: Report and add to https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/
  const router = createRouter({
    base: workspacesListPath,
  });
  injectVueAppBreadcrumbs(router, WorkspacesBreadcrumbs);
  return initVueApp({
    el,
    name: 'WorkspacesRoot',
    router,
    apolloProvider: createApolloProvider(),
    provide: options,
    component: App,
  });
};

export { initUserWorkspacesApp };
