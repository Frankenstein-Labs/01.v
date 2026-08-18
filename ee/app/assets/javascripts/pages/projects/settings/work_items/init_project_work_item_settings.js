import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { getRoutes } from 'ee/groups/settings/work_items/routes';
import createDefaultClient from '~/lib/graphql';
import ProjectWorkItemSettings from './project_work_item_settings.vue';

Vue.use(VueApollo);

export const initProjectWorkItemSettings = () => {
  const el = document.querySelector('#js-project-work-item-settings');

  if (!el) {
    return null;
  }

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const { basePath, fullPath } = el.dataset;

  return initVueApp({
    el,
    router: new VueRouter({
      mode: 'history',
      base: basePath,
      routes: getRoutes(fullPath),
    }),
    apolloProvider,
    name: 'ProjectWorkItemSettings',
    // `$toast` was previously supplied by another bundle's global `Vue.use(GlToast)`.
    // Vue 3 apps do not inherit it, so the app installs what it depends on.
    plugins: [GlToast],
    component: ProjectWorkItemSettings,
    props: {
      fullPath,
    },
  });
};
