import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import SASTConfigurationApp from './components/app.vue';

export default function init() {
  const el = document.querySelector('.js-sast-configuration');

  if (!el) {
    return undefined;
  }

  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const { securityConfigurationPath, projectPath, sastDocumentationPath } = el.dataset;

  return initVueApp({
    el,
    name: 'SASTConfigurationAppRoot',
    apolloProvider,
    provide: {
      securityConfigurationPath,
      projectPath,
      sastDocumentationPath,
    },
    component: SASTConfigurationApp,
  });
}
