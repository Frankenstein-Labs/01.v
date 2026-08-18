import Vue from 'vue';
import { GlToast } from '@gitlab/ui';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from 'ee/usage_quotas/shared/provider';
import GitlabDuoHome from 'ee/ai/settings/pages/gitlab_duo_home.vue';

Vue.use(GlToast);

export function initGitLabDuoHomeAdmin() {
  const el = document.getElementById('js-gitlab-duo-admin-page');

  if (!el) {
    return null;
  }

  const {
    addDuoProSeatsUrl,
    exposeDuoAgentPlatformServiceUrl,
    duoSeatUtilizationPath,
    enabledExpandedLogging,
    isBulkAddOnAssignmentEnabled,
    subscriptionName,
    duoConfigurationPath,
    duoInstanceModelSelectionPath,
    duoAvailability,
    areDuoCoreFeaturesEnabled,
    directCodeSuggestionsEnabled,
    experimentFeaturesEnabled,
    promptCacheEnabled,
    betaSelfHostedModelsEnabled,
    areExperimentSettingsAllowed,
    arePromptCacheSettingsAllowed,
    duoAddOnStartDate,
    duoAddOnEndDate,
    amazonQReady,
    amazonQAutoReviewEnabled,
    amazonQConfigurationPath,
    canManageSelfHostedModels,
    canManageInstanceModelSelection,
    duoRemoteFlowsAvailability,
    duoFoundationalFlowsAvailability,
    isSaas,
    showSmPurchaseButton,
    isSmTrial,
    redirectPath,
    gitlabCreditsDashboardPath,
    selfManagedPurchaseCreditsPath,
  } = el.dataset;

  return initVueApp({
    el,
    name: 'GitlabDuoHome',
    apolloProvider,
    provide: {
      exposeDuoAgentPlatformServiceUrl: parseBoolean(exposeDuoAgentPlatformServiceUrl),
      isSaaS: parseBoolean(isSaas),
      isAdminInstanceDuoHome: true,
      showSmPurchaseButton: parseBoolean(showSmPurchaseButton),
      isSmTrial: parseBoolean(isSmTrial),
      selfManagedPurchaseCreditsPath,
      addDuoProHref: addDuoProSeatsUrl,
      duoSeatUtilizationPath,
      isBulkAddOnAssignmentEnabled: parseBoolean(isBulkAddOnAssignmentEnabled),
      subscriptionName,
      duoConfigurationPath,
      duoInstanceModelSelectionPath,
      duoAvailability,
      areDuoCoreFeaturesEnabled: parseBoolean(areDuoCoreFeaturesEnabled),
      directCodeSuggestionsEnabled: parseBoolean(directCodeSuggestionsEnabled),
      expandedLoggingEnabled: parseBoolean(enabledExpandedLogging),
      experimentFeaturesEnabled: parseBoolean(experimentFeaturesEnabled),
      promptCacheEnabled: parseBoolean(promptCacheEnabled),
      betaSelfHostedModelsEnabled: parseBoolean(betaSelfHostedModelsEnabled),
      areExperimentSettingsAllowed: parseBoolean(areExperimentSettingsAllowed),
      arePromptCacheSettingsAllowed: parseBoolean(arePromptCacheSettingsAllowed),
      duoAddOnStartDate,
      duoAddOnEndDate,
      amazonQReady: parseBoolean(amazonQReady),
      amazonQAutoReviewEnabled: parseBoolean(amazonQAutoReviewEnabled),
      amazonQConfigurationPath,
      canManageSelfHostedModels: parseBoolean(canManageSelfHostedModels),
      canManageInstanceModelSelection: parseBoolean(canManageInstanceModelSelection),
      initialDuoRemoteFlowsAvailability: parseBoolean(duoRemoteFlowsAvailability),
      initialDuoFoundationalFlowsAvailability: parseBoolean(duoFoundationalFlowsAvailability),
      redirectPath,
      gitlabCreditsDashboardPath,
    },
    component: GitlabDuoHome,
  });
}
