import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import createRouter from './router';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export function initInstanceModelSelection() {
  const el = document.getElementById('js-duo-instance-model-selection');

  if (!el) {
    return null;
  }

  const {
    basePath,
    modelOptions,
    betaModelsEnabled,
    duoConfigurationSettingsPath,
    canManageInstanceModelSelection,
    canManageSelfHostedModels,
    isDedicatedInstance,
    canManageDapSelfHostedModels,
    modelSelectionAllowlistAvailable,
  } = JSON.parse(el.dataset.viewModel);

  const router = createRouter(basePath);

  return new Vue({
    el,
    name: 'InstanceModelSelectionRootApp',
    apolloProvider,
    router,
    provide: {
      basePath,
      modelOptions,
      betaModelsEnabled,
      duoConfigurationSettingsPath,
      canManageInstanceModelSelection,
      canManageSelfHostedModels,
      isDedicatedInstance,
      canManageDapSelfHostedModels,
      modelSelectionAllowlistAvailable,
    },
    render(createElement) {
      return createElement('router-view');
    },
  });
}
