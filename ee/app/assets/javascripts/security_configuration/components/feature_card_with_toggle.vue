<script>
import {
  GlCard,
  GlIcon,
  GlLink,
  GlPopover,
  GlToggle,
  GlAlert,
  GlLoadingIcon,
  GlToastMixin,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { FEATURE_DISABLED_TOOLTIP } from '~/security_configuration/constants';

export default {
  name: 'FeatureCardWithToggle',
  components: {
    GlCard,
    GlIcon,
    GlLink,
    GlPopover,
    GlToggle,
    GlAlert,
    GlLoadingIcon,
  },
  mixins: [GlToastMixin],
  inject: {
    projectFullPath: { default: '' },
  },
  props: {
    feature: {
      type: Object,
      required: false,
      default: null,
    },
    mutation: {
      type: Object,
      required: true,
    },
    initialValue: {
      type: Boolean,
      required: true,
    },
    mutationResponseKey: {
      type: String,
      required: true,
    },
    enabledKey: {
      type: String,
      required: true,
    },
    toggleTestId: {
      type: String,
      required: true,
    },
    i18n: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      toggleValue: this.initialValue,
      errorMessage: '',
      isAlertDismissed: false,
      isRunningMutation: false,
    };
  },
  computed: {
    shouldShowAlert() {
      return this.errorMessage && !this.isAlertDismissed;
    },
    isToggleDisabled() {
      return !this.feature.canUserConfigure || this.isRunningMutation;
    },
    showLock() {
      return !this.feature?.canUserConfigure;
    },
    lockIconId() {
      return `${this.feature?.type || 'feature'}-lock-icon`;
    },
    featureName() {
      return this.feature?.name || this.i18n.name;
    },
    featureDescription() {
      return this.feature?.description || this.i18n.description;
    },
    featureHelpPath() {
      return this.feature?.helpPath;
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
    async toggleFeature(checked) {
      const oldValue = this.toggleValue;

      try {
        this.isRunningMutation = true;
        this.toggleValue = checked;
        this.clearError();

        const { data } = await this.$apollo.mutate({
          mutation: this.mutation,
          variables: {
            input: {
              projectPath: this.projectFullPath,
              enable: checked,
            },
          },
        });

        const response = data[this.mutationResponseKey];

        if (response.errors.length > 0) {
          throw new Error(response.errors[0]);
        }

        this.toggleValue = response[this.enabledKey];
        this.$toast.show(
          this.toggleValue ? this.i18n.toastMessageEnabled : this.i18n.toastMessageDisabled,
        );
      } catch (error) {
        this.toggleValue = oldValue;
        this.reportError(error.message || s__('CVS|Something went wrong. Please try again.'));
      } finally {
        this.isRunningMutation = false;
      }
    },
  },
  i18n: {
    enabled: s__('SecurityConfiguration|Enabled'),
    notEnabled: s__('SecurityConfiguration|Not enabled'),
    tooltipTitle: s__('SecurityConfiguration|Action unavailable'),
    accessLevelTooltipDescription: FEATURE_DISABLED_TOOLTIP,
    learnMore: __('Learn more'),
  },
};
</script>

<template>
  <gl-card>
    <template #header>
      <div class="gl-flex gl-items-baseline">
        <h3 class="gl-m-0 gl-mr-3 gl-text-base">
          {{ featureName }}
          <gl-icon v-if="showLock" :id="lockIconId" name="lock" class="gl-mb-1" />
        </h3>
        <gl-popover v-if="showLock" :target="lockIconId" placement="right">
          <template #title>{{ $options.i18n.tooltipTitle }}</template>
          {{ $options.i18n.accessLevelTooltipDescription }}
        </gl-popover>

        <div class="gl-ml-auto gl-shrink-0" data-testid="feature-status">
          <span :class="toggleValue ? 'gl-text-success' : 'gl-text-disabled'">
            <gl-icon v-if="toggleValue" name="check-circle-filled" />
            {{ toggleValue ? $options.i18n.enabled : $options.i18n.notEnabled }}
          </span>
        </div>
      </div>
    </template>

    <p class="gl-mb-0">
      {{ featureDescription }}
      <gl-link v-if="featureHelpPath" :href="featureHelpPath" target="_blank">
        {{ $options.i18n.learnMore }}.
      </gl-link>
    </p>

    <gl-alert
      v-if="shouldShowAlert"
      class="gl-mb-5 gl-mt-2"
      variant="danger"
      @dismiss="isAlertDismissed = true"
      >{{ errorMessage }}</gl-alert
    >
    <div class="gl-mt-5 gl-flex gl-items-center">
      <gl-toggle
        :disabled="isToggleDisabled"
        :value="toggleValue"
        :label="featureName"
        label-position="hidden"
        :data-testid="toggleTestId"
        @change="toggleFeature"
      />
      <gl-loading-icon v-if="isRunningMutation" inline class="gl-ml-3" />
    </div>
  </gl-card>
</template>
