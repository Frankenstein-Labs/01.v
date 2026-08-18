<script>
import { GlCard, GlButton } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { __, s__ } from '~/locale';
import { DUO_IDENTIFIERS, DUO_TITLES } from 'ee/constants/duo';
import { AVAILABILITY_OPTIONS } from '../constants';
import getDuoSettingsQuery from '../../graphql/get_ai_settings.query.graphql';
import DuoConfigurationSettingsRow from './duo_configuration_settings_row.vue';

export default {
  name: 'DuoConfigurationSettingsInfoCard',
  i18n: {
    aiLogsText: s__('AiPowered|AI logs'),
    aiGatewayUrlText: s__('AiPowered|Local AI gateway URL'),
    duoAgentPlatformServiceUrlText: s__(
      'AiPowered|Local URL for the GitLab Duo Agent Platform service',
    ),
    duoAgentPlatformServiceSecureText: s__(
      'AiPowered|Secure connection (TLS) for GitLab Duo Agent Platform service',
    ),
    duoChangeConfigurationButtonText: s__('AiPowered|Change configuration'),
    experimentAndBetaFeaturesText: s__('AiPowered|Experiment and beta features'),
    betaSelfHostedModelsText: s__('AiPowered|Self-hosted beta models and features'),
    directConnectionsText: s__('AiPowered|Direct connections'),
    enabledText: __('Enabled'),
    defaultOnText: s__('AiPowered|On by default'),
    defaultOffText: s__('AiPowered|Off by default'),
    alwaysOffText: s__('AiPowered|Always off'),
    enabled: s__('AiPowered|Enabled'),
    disabled: s__('AiPowered|Not enabled'),
    duoCoreAvailabilityText: s__('AiPowered|GitLab Duo Core available to all users'),
    duoSettingsErrorMessage: s__(
      'AiPowered|An error occurred while loading GitLab Duo settings. Please try again.',
    ),
  },
  components: {
    GlCard,
    GlButton,
    DuoConfigurationSettingsRow,
  },
  inject: {
    exposeDuoAgentPlatformServiceUrl: { default: false },
    canManageSelfHostedModels: { default: false },
    duoConfigurationPath: {},
    isSaaS: {},
    duoAvailability: {},
    directCodeSuggestionsEnabled: { default: false },
    expandedLoggingEnabled: { default: false },
    experimentFeaturesEnabled: {},
    betaSelfHostedModelsEnabled: { default: false },
    areExperimentSettingsAllowed: {},
    areDuoCoreFeaturesEnabled: { default: false },
  },
  apollo: {
    duoSettings: {
      query: getDuoSettingsQuery,
      error(error) {
        createAlert({
          message: this.$options.i18n.duoSettingsErrorMessage,
          error,
          captureError: true,
        });
      },
    },
  },
  props: {
    activeDuoTier: {
      type: String,
      required: true,
      validator: (val) => DUO_IDENTIFIERS.includes(val),
    },
  },
  data() {
    return {
      duoSettings: null,
    };
  },
  computed: {
    aiGatewayUrl() {
      return this.duoSettings?.aiGatewayUrl ?? '';
    },
    duoAgentPlatformServiceUrl() {
      return this.duoSettings?.duoAgentPlatformServiceUrl ?? '';
    },
    selfHostedDuoAgentPlatformServiceSecureEnabled() {
      return this.duoSettings?.selfHostedDuoAgentPlatformServiceSecure ?? false;
    },
    isSelfManaged() {
      return !this.isSaaS;
    },
    availabilityStatusText() {
      switch (this.duoAvailability) {
        case AVAILABILITY_OPTIONS.DEFAULT_ON:
          return this.$options.i18n.defaultOnText;
        case AVAILABILITY_OPTIONS.DEFAULT_OFF:
          return this.$options.i18n.defaultOffText;
        case AVAILABILITY_OPTIONS.NEVER_ON:
          return this.$options.i18n.alwaysOffText;
        default:
          return null;
      }
    },
    title() {
      return DUO_TITLES[this.activeDuoTier];
    },
    isDuoCoreEnabled() {
      // FIXME: Database inconsistency between Duo Core feature flags and availability settings
      //
      // Issue: Some Duo Core features are enabled in the database even when duoAvailability
      // is set to 'Always off', creating an misinformal state.
      //
      // Current fix: This method aggregates both conditions to determine actual availability.
      // Future: Potentially clean up database state to remove this workaround.
      //
      // Reference: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/196907#note_2616291902
      return (
        this.areDuoCoreFeaturesEnabled && this.duoAvailability !== AVAILABILITY_OPTIONS.NEVER_ON
      );
    },
    isDuoAgentPlatformEnabled() {
      return this.exposeDuoAgentPlatformServiceUrl && this.duoAgentPlatformServiceUrl;
    },
  },
};
</script>
<template>
  <gl-card
    header-class="gl-heading-scale-300"
    footer-class="gl-bg-transparent gl-border-none gl-flex-end"
    class="gl-justify-between"
  >
    <template #header>
      <h3 class="gl-m-0" data-testid="duo-configuration-settings-info">{{ title }}</h3>
    </template>
    <template #default>
      <p class="gl-heading-scale-500 gl-mb-0" data-testid="configuration-status">
        {{ availabilityStatusText }}
      </p>
      <duo-configuration-settings-row
        :duo-configuration-settings-row-type-title="$options.i18n.duoCoreAvailabilityText"
        :config-value="isDuoCoreEnabled"
      />
      <duo-configuration-settings-row
        v-if="areExperimentSettingsAllowed"
        :duo-configuration-settings-row-type-title="$options.i18n.experimentAndBetaFeaturesText"
        :config-value="experimentFeaturesEnabled"
      />
      <duo-configuration-settings-row
        v-if="isSelfManaged"
        :duo-configuration-settings-row-type-title="$options.i18n.directConnectionsText"
        :config-value="directCodeSuggestionsEnabled"
      />
      <template v-if="isSelfManaged && canManageSelfHostedModels">
        <duo-configuration-settings-row
          :duo-configuration-settings-row-type-title="$options.i18n.betaSelfHostedModelsText"
          :config-value="betaSelfHostedModelsEnabled"
        />
        <duo-configuration-settings-row
          :duo-configuration-settings-row-type-title="$options.i18n.aiLogsText"
          :config-value="expandedLoggingEnabled"
        />
        <duo-configuration-settings-row
          v-if="aiGatewayUrl"
          :duo-configuration-settings-row-type-title="$options.i18n.aiGatewayUrlText"
          :config-value="aiGatewayUrl"
        />
        <duo-configuration-settings-row
          v-if="isDuoAgentPlatformEnabled"
          :duo-configuration-settings-row-type-title="$options.i18n.duoAgentPlatformServiceUrlText"
          :config-value="duoAgentPlatformServiceUrl"
        />
        <duo-configuration-settings-row
          v-if="isDuoAgentPlatformEnabled"
          :duo-configuration-settings-row-type-title="
            $options.i18n.duoAgentPlatformServiceSecureText
          "
          :config-value="selfHostedDuoAgentPlatformServiceSecureEnabled"
        />
      </template>
    </template>
    <template #footer>
      <div data-testid="duo-configuration-settings-action-buttons">
        <gl-button category="primary" variant="default" :href="duoConfigurationPath">{{
          $options.i18n.duoChangeConfigurationButtonText
        }}</gl-button>
      </div>
    </template>
  </gl-card>
</template>
