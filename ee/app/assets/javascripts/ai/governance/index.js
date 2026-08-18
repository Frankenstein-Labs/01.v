import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import GovernanceApp from './components/governance_app.vue';

Vue.use(VueApollo);

export const initGovernanceApp = () => {
  const el = document.querySelector('#js-governance');

  if (!el) {
    return false;
  }

  const {
    groupId,
    groupFullPath,
    projectId,
    projectFullPath,
    editable,
    aiAuditEventsStorageEnabled,
    aiAuditEventsSettingsPath,
  } = el.dataset;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return initVueApp({
    el,
    name: 'GovernanceRoot',
    apolloProvider,
    provide: {
      groupId,
      groupFullPath,
      projectId: projectId || null,
      projectFullPath: projectFullPath || '',
      aiToolRulesEditable: editable === undefined ? true : parseBoolean(editable),
      aiAuditEventsStorageEnabled:
        aiAuditEventsStorageEnabled === undefined
          ? true
          : parseBoolean(aiAuditEventsStorageEnabled),
      aiAuditEventsSettingsPath: aiAuditEventsSettingsPath || '',
      glFeatures: gon.features || {},
    },
    component: GovernanceApp,
  });
};
