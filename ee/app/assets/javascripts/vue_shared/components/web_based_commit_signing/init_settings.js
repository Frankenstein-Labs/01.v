import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import WebBasedCommitSigningSettings from './settings.vue';

export const initWebBasedCommitSigningSettings = (el, dataset, isGroupLevel) => {
  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const provide = {
    groupSettingsRepositoryPath: dataset.groupSettingsRepositoryPath,
    fullPath: dataset.fullPath,
    levelId: parseInt(dataset.levelId, 10),
  };

  const props = {
    canAdminGroup: parseBoolean(dataset.canAdminGroup),
    isGroupLevel,
  };

  return initVueApp({
    el,
    name: 'WebBasedCommitSigningSettings',
    apolloProvider,
    provide,
    component: WebBasedCommitSigningSettings,
    props,
  });
};
