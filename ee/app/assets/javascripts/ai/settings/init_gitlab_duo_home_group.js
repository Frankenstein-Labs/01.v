import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import GitlabDuoHome from 'ee/ai/settings/pages/gitlab_duo_home.vue';
import apolloProvider from 'ee/usage_quotas/shared/provider';
import { parseProvideData } from 'ee/usage_quotas/code_suggestions/utils';

export function initGitLabDuoHomeGroup() {
  const el = document.getElementById('js-gitlab-duo-home');

  if (!el) return false;

  return initVueApp({
    el,
    name: 'GitlabDuoHomePage',
    apolloProvider,
    provide() {
      const data = el.dataset;

      return {
        ...parseProvideData(el),
        modelSwitchingEnabled: parseBoolean(data.modelSwitchingEnabled),
        modelSwitchingPath: data.modelSwitchingPath,
        duoSeatUtilizationPath: data.duoSeatUtilizationPath,
        duoConfigurationPath: data.duoConfigurationPath,
        duoGovernancePath: data.duoGovernancePath,
        duoAvailability: data.duoAvailability,
        experimentFeaturesEnabled: parseBoolean(data.experimentFeaturesEnabled),
        promptCacheEnabled: parseBoolean(data.promptCacheEnabled),
        areExperimentSettingsAllowed: parseBoolean(data.areExperimentSettingsAllowed),
        arePromptCacheSettingsAllowed: parseBoolean(data.arePromptCacheSettingsAllowed),
        areDuoCoreFeaturesEnabled: parseBoolean(data.areDuoCoreFeaturesEnabled),
        initialDuoRemoteFlowsAvailability: parseBoolean(data.duoRemoteFlowsAvailability),
        gitlabCreditsDashboardPath: data.gitlabCreditsDashboardPath,
        gitlabComPurchaseCreditsPath: data.gitlabComPurchaseCreditsPath,
        namespaceIsOnTrial: parseBoolean(data.namespaceIsOnTrial),
        creditsGeneralizationUi: parseBoolean(data.creditsGeneralizationUi),
      };
    },
    component: GitlabDuoHome,
  });
}
