import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import ModelSelectionApp from 'ee/ai/model_selection/app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

function mountModelSelectionApp() {
  const el = document.getElementById('js-gitlab-duo-model-selection');

  if (!el) {
    return null;
  }

  const { groupId, modelSelectionAllowlistAvailable } = JSON.parse(el.dataset.viewModel);

  return initVueApp({
    el,
    name: 'ModelSelectionApp',
    apolloProvider,
    provide: {
      groupId,
      modelSelectionAllowlistAvailable,
    },
    component: ModelSelectionApp,
  });
}

mountModelSelectionApp();
