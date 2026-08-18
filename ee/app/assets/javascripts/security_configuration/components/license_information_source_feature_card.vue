<script>
import {
  GlCard,
  GlIcon,
  GlLink,
  GlCollapsibleListbox,
  GlAlert,
  GlTooltipDirective,
  GlToastMixin,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import SetLicenseConfigurationSource from '~/security_configuration/graphql/set_license_configuration_source.graphql';
import FeatureCardBadge from '~/security_configuration/components/feature_card_badge.vue';
import { FEATURE_DISABLED_TOOLTIP } from '~/security_configuration/constants';

const SBOM = 'SBOM';
const PMDB = 'PMDB';

const sourceItems = [
  { value: SBOM, text: SBOM },
  { value: PMDB, text: PMDB },
];

export default {
  name: 'LicenseInformationSourceFeatureCard',
  components: {
    GlCard,
    GlIcon,
    GlLink,
    GlCollapsibleListbox,
    GlAlert,
    FeatureCardBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [GlToastMixin],
  inject: ['projectFullPath', 'licenseConfigurationSource'],
  props: {
    feature: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      licenseSource: this.licenseConfigurationSource,
      errorMessage: '',
      isAlertDismissed: false,
    };
  },
  computed: {
    available() {
      return this.feature.available;
    },
    enabled() {
      return this.available && this.feature.configured;
    },
    statusClasses() {
      const { enabled, hasBadge } = this;

      return {
        'gl-ml-auto': true,
        'gl-shrink-0': true,
        'gl-text-disabled': !enabled,
        'gl-text-success': enabled,
        'gl-w-full': hasBadge,
        'gl-justify-between': hasBadge,
        'gl-flex': hasBadge,
        'gl-mb-4': hasBadge,
      };
    },
    hasBadge() {
      const shouldDisplay = this.available || this.feature.badge?.alwaysDisplay;
      return Boolean(shouldDisplay && this.feature.badge?.text);
    },
    shouldShowAlert() {
      return this.errorMessage && !this.isAlertDismissed;
    },
    disabledTooltip() {
      return this.feature.canUserConfigure ? null : FEATURE_DISABLED_TOOLTIP;
    },
  },
  methods: {
    reportError(error) {
      this.errorMessage = error;
      this.isAlertDismissed = false;
    },
    clearError() {
      this.errorMessage = '';
      this.isAlertDismissed = true;
    },
    async onSelect(source) {
      try {
        this.clearError();

        const { data } = await this.$apollo.mutate({
          mutation: SetLicenseConfigurationSource,
          variables: {
            input: {
              projectPath: this.projectFullPath,
              source,
            },
          },
        });

        const { errors, licenseConfigurationSource } = data.setLicenseConfigurationSource;

        if (errors.length > 0) {
          this.reportError(errors[0]);
        }
        if (licenseConfigurationSource !== null) {
          this.licenseSource = licenseConfigurationSource;
          this.$toast.show(
            licenseConfigurationSource === SBOM
              ? s__('LicenseConfigurationSource|License configuration source set to SBOM')
              : s__('LicenseConfigurationSource|License configuration source set to PMDB'),
          );
        }
      } catch (error) {
        this.reportError(s__('LicenseConfigurationSource|Something went wrong. Please try again.'));
      }
    },
  },
  i18n: {
    enabled: s__('SecurityConfiguration|Enabled'),
    notEnabled: s__('SecurityConfiguration|Not enabled'),
    availableWith: s__('SecurityConfiguration|Available with Ultimate'),
    learnMore: __('Learn more'),
  },
  sourceItems,
};
</script>

<template>
  <gl-card :class="{ 'gl-bg-strong': !available }">
    <template #header>
      <div class="gl-flex gl-items-baseline" :class="{ 'gl-flex-col-reverse': hasBadge }">
        <h3 class="gl-m-0 gl-mr-3 gl-text-base" :class="{ 'gl-text-subtle': !available }">
          {{ feature.name }}
        </h3>
        <div
          :class="statusClasses"
          data-testid="feature-status"
          :data-qa-feature="`${feature.type}_${enabled}_status`"
        >
          <feature-card-badge
            v-if="hasBadge"
            :badge="feature.badge"
            :badge-href="feature.badge.badgeHref"
          />

          <template v-if="enabled">
            <span>
              <gl-icon name="check-circle-filled" />
              <span class="gl-text-success">{{ $options.i18n.enabled }}</span>
            </span>
          </template>

          <template v-else-if="available">
            {{ $options.i18n.notEnabled }}
          </template>

          <template v-else>
            {{ $options.i18n.availableWith }}
          </template>
        </div>
      </div>
    </template>

    <p class="gl-mb-0" :class="{ 'gl-text-subtle': !available }">
      {{ feature.description }}
      <gl-link :href="feature.helpPath">{{ $options.i18n.learnMore }}.</gl-link>
    </p>

    <template v-if="available">
      <gl-alert
        v-if="shouldShowAlert"
        class="gl-mb-2 gl-mt-5"
        variant="danger"
        @dismiss="isAlertDismissed = true"
        >{{ errorMessage }}</gl-alert
      >
      <span
        v-gl-tooltip
        :title="disabledTooltip"
        class="gl-mb-2 gl-mt-5 gl-block"
        data-testid="license-source-listbox-tooltip"
      >
        <gl-collapsible-listbox
          :disabled="!feature.canUserConfigure"
          :items="$options.sourceItems"
          :selected="licenseSource"
          @select="onSelect"
        />
      </span>
    </template>
  </gl-card>
</template>
