import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import MergeTrainsApp from './merge_trains_app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initMergeTrainsApp = () => {
  const el = document.querySelector('#js-merge-trains');

  if (!el) {
    return false;
  }

  const { fullPath, defaultBranch, projectId, projectName } = el.dataset;

  return initVueApp({
    el,
    name: 'MergeTrainsRoot',
    apolloProvider,
    provide: {
      fullPath,
      defaultBranch,
      projectId,
      projectName,
    },
    component: MergeTrainsApp,
  });
};
