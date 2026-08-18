import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import Translate from '~/vue_shared/translate';
import WorkItemSettings from './work_item_settings.vue';
import { getRoutes } from './routes';

Vue.use(VueApollo);
Vue.use(Translate);
Vue.use(VueRouter);

export function initWorkItemSettingsApp() {
  const el = document.querySelector('#js-work-items-settings-form');
  if (!el) return null;

  const { fullPath, basePath, isRootGroup, isSaas } = el.dataset;

  return initVueApp({
    el,
    name: 'WorkItemSettingsRoot',
    // `$toast` was previously supplied by another bundle's global `Vue.use(GlToast)`.
    // Vue 3 apps do not inherit it, so the app installs what it depends on.
    plugins: [GlToast],
    apolloProvider: new VueApollo({
      defaultClient: createDefaultClient(),
    }),
    router: new VueRouter({
      mode: 'history',
      base: basePath,
      routes: getRoutes(fullPath, parseBoolean(isRootGroup), parseBoolean(isSaas)),
    }),
    component: WorkItemSettings,
    props: {
      fullPath,
    },
  });
}
