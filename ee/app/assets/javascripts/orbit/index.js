import Vue from 'vue';
import { GlToast } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import OrbitApp from './components/app.vue';
import createRouter from './router';

Vue.use(GlToast);
Vue.use(VueApollo);
Vue.use(VueRouter);

export default function initOrbit() {
  const el = document.getElementById('js-orbit-app');

  if (!el) return null;

  const { routerBase, configureMode, adminConfigurationPath, duoAccessible, orbitSettingsEnabled } =
    el.dataset;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const router = createRouter(routerBase);

  return initVueApp({
    el,
    name: 'OrbitRoot',
    apolloProvider,
    router,
    component: OrbitApp,
    props: {
      configureMode,
      adminConfigurationPath,
      duoAccessible: parseBoolean(duoAccessible),
      orbitSettingsEnabled: parseBoolean(orbitSettingsEnabled),
    },
  });
}
