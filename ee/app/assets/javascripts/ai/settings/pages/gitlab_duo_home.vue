<script>
import { __, s__ } from '~/locale';
import { DUO_CORE, DUO_PRO, DUO_ENTERPRISE } from 'ee/constants/duo';
import { GITLAB_CREDITS } from 'ee/constants/billings';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import HealthCheckList from 'ee/usage_quotas/code_suggestions/components/health_check_list.vue';
import DuoAgentPlatformBuyCreditsCard from 'ee/ai/settings/components/duo_agent_platform_buy_credits_card.vue';
import DuoSeatUtilizationInfoCard from '../components/duo_seat_utilization_info_card.vue';
import DuoConfigurationSettingsInfoCard from '../components/duo_configuration_settings_info_card.vue';
import DuoGovernanceInfoCard from '../components/duo_governance_info_card.vue';
import DuoModelsConfigurationInfoCard from '../components/duo_models_configuration_info_card.vue';
import DuoUsageAnalyticsCard from '../components/duo_usage_analytics_card.vue';
import SeedExternalAgents from '../components/seed_external_agents.vue';

export default {
  name: 'GitlabDuoHome',
  components: {
    CodeSuggestionsUsage,
    HealthCheckList,
    DuoConfigurationSettingsInfoCard,
    DuoGovernanceInfoCard,
    DuoAgentPlatformBuyCreditsCard,
    DuoSeatUtilizationInfoCard,
    DuoModelsConfigurationInfoCard,
    DuoUsageAnalyticsCard,
    SeedExternalAgents,
  },
  inject: {
    canManageSelfHostedModels: { default: false },
    canManageInstanceModelSelection: { default: false },
    duoInstanceModelSelectionPath: { default: '' },
    isSaaS: {},
    isAdminInstanceDuoHome: { default: false },
    modelSwitchingEnabled: { default: false },
    modelSwitchingPath: { default: '' },
    gitlabCreditsDashboardPath: { default: '' },
    glFeatures: { default: () => ({}) },
  },
  i18n: {
    gitlabDuoHomeTitle: __('GitLab Duo'),
    gitlabDuoHomeSubtitle: s__(
      'AiPowered|Monitor, manage, and customize AI-powered features to ensure efficient utilization and alignment.',
    ),
  },
  computed: {
    isModelSwitchingEnabled() {
      return this.isSaaS && this.modelSwitchingEnabled;
    },
    isSelfHostedModelsEnabled() {
      return !this.isSaaS && this.canManageSelfHostedModels;
    },
    isInstanceModelSelectionEnabled() {
      return this.canManageInstanceModelSelection;
    },
    showDuoModelsConfigurationCard() {
      return (
        this.isModelSwitchingEnabled ||
        this.isSelfHostedModelsEnabled ||
        this.isInstanceModelSelectionEnabled
      );
    },
    duoModelsConfigurationProps() {
      if (this.isModelSwitchingEnabled) {
        return {
          header: s__('AiPowered|Model selection'),
          description: s__('AiPowered|Assign models to AI-native features.'),
          buttonText: s__('AiPowered|Manage models'),
          path: this.modelSwitchingPath,
        };
      }

      if (this.isInstanceModelSelectionEnabled) {
        return {
          header: s__('AiPowered|Model selection'),
          description: s__(
            'AiPowered|Assign self-hosted or cloud-connected models to use with specific AI-native features.',
          ),
          buttonText: s__('AiPowered|Manage models'),
          path: this.duoInstanceModelSelectionPath,
        };
      }

      if (this.isSelfHostedModelsEnabled) {
        return {
          header: s__('AiPowered|GitLab Duo Self-Hosted'),
          description: s__('AiPowered|Assign self-hosted models to specific AI-native features.'),
          buttonText: s__('AiPowered|Configure GitLab Duo Self-Hosted'),
          path: this.duoInstanceModelSelectionPath,
        };
      }

      return {};
    },
    shouldShowCodeSuggestionsUsage() {
      /* Show when in self-managed admin instance settings */
      if (!this.isSaaS) {
        return true;
      }

      /*
       * Do not show when in SaaS admin instance settings.
       * For SaaS, these configs are managed via the Duo home page under namespace settings.
       * i.e /groups/<group-name>/-/settings/gitlab_duo
       */
      return this.isSaaS && !this.isAdminInstanceDuoHome;
    },
  },
  methods: {
    isDuoCore(activeDuoTier) {
      return activeDuoTier === DUO_CORE;
    },
    hasGitlabCredits(addOnPurchases) {
      return addOnPurchases?.some(({ name }) => name === GITLAB_CREDITS);
    },
    shouldShowDuoBuyCreditsCard(activeDuoTier, addOnPurchases) {
      return this.isDuoCore(activeDuoTier) || this.hasGitlabCredits(addOnPurchases);
    },
    shouldShowSeatUtilizationInfoCard(activeDuoTier) {
      return activeDuoTier === DUO_PRO || activeDuoTier === DUO_ENTERPRISE;
    },
  },
};
</script>

<template>
  <div class="gl-grid gl-gap-y-5 gl-pb-5">
    <code-suggestions-usage
      v-if="shouldShowCodeSuggestionsUsage"
      :title="$options.i18n.gitlabDuoHomeTitle"
      :subtitle="$options.i18n.gitlabDuoHomeSubtitle"
      v-bind="$attrs"
    >
      <template #health-check>
        <health-check-list v-if="!isSaaS" />
      </template>
      <template #duo-card="{ totalValue, usageValue, activeDuoTier, addOnPurchases }">
        <div class="gl-grid gl-gap-y-5">
          <section class="gl-grid gl-gap-5 @md/panel:gl-grid-cols-2">
            <duo-agent-platform-buy-credits-card
              v-if="shouldShowDuoBuyCreditsCard(activeDuoTier, addOnPurchases)"
              :has-gitlab-credits="hasGitlabCredits(addOnPurchases)"
            />
            <duo-seat-utilization-info-card
              v-if="shouldShowSeatUtilizationInfoCard(activeDuoTier)"
              data-testid="duo-seat-utilization-info-card"
              :total-value="totalValue"
              :usage-value="usageValue"
              :active-duo-tier="activeDuoTier"
              :add-on-purchases="addOnPurchases"
            />
            <duo-configuration-settings-info-card
              data-testid="duo-configuration-settings-info-card"
              :active-duo-tier="activeDuoTier"
            />
          </section>
          <section class="gl-flex gl-flex-col gl-gap-5">
            <duo-models-configuration-info-card
              v-if="showDuoModelsConfigurationCard"
              :duo-models-configuration-props="duoModelsConfigurationProps"
            />
            <duo-usage-analytics-card
              v-if="gitlabCreditsDashboardPath"
              :dashboard-path="gitlabCreditsDashboardPath"
            />
            <duo-governance-info-card
              v-if="glFeatures.gitlabDuoGovernanceSettings && !isAdminInstanceDuoHome"
              data-testid="duo-governance-info-card"
            />
          </section>
          <section v-if="!isSaaS" class="gl-flex gl-flex-col gl-gap-5">
            <seed-external-agents />
          </section>
        </div>
      </template>
    </code-suggestions-usage>
  </div>
</template>
