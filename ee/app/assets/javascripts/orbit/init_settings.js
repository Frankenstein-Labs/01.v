import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import OrbitSettingsPage from './components/orbit_settings_page.vue';

Vue.use(VueApollo);

export default function initOrbitSettings() {
  const el = document.getElementById('js-orbit-settings');

  if (!el) return null;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const { groupFullPath, explorePath, schemaPath } = el.dataset;

  return initVueApp({
    el,
    name: 'OrbitSettingsRoot',
    apolloProvider,
    component: OrbitSettingsPage,
    props: {
      groupFullPath,
      explorePath,
      schemaPath,
    },
  });
}
