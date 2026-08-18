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
import SetContainerScanningForRegistry from 'ee/security_configuration/graphql/set_container_scanning_for_registry.mutation.graphql';
import { __, s__ } from '~/locale';

export default {
  name: 'ContainerScanningForRegistryFeatureCard',
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
  inject: ['projectFullPath'],
  props: {
    feature: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      toggleValue: this.feature.available && this.feature.configured,
      errorMessage: '',
      isAlertDismissed: false,
      isRunningMutation: false,
    };
  },
  computed: {
    shouldShowAlert() {
      return this.errorMessage && !this.isAlertDismissed;
    },
    available() {
      return this.feature.available;
    },
    enabled() {
      return this.toggleValue && this.available;
    },
    cardClasses() {
      return { 'gl-bg-strong': !this.available };
    },
    textClasses() {
      return { 'gl-text-subtle': !this.available };
    },
    statusClasses() {
      const { enabled } = this;

      return {
        'gl-ml-auto': true,
        'gl-flex-shrink-0': true,
        'gl-text-disabled': !enabled,
        'gl-text-success': enabled,
        'gl-w-full': false,
        'gl-justify-between': false,
        'gl-flex': false,
        'gl-mb-4': false,
      };
    },
    isToggleDisabled() {
      return !this.feature.canUserConfigure || this.isRunningMutation;
    },
    showLock() {
      return !this.feature.canUserConfigure && this.available;
    },
    featureLockDescription() {
      if (!this.feature.canUserConfigure) {
        return this.$options.i18n.accessLevelTooltipDescription;
      }
      return '';
    },
    statusText() {
      if (this.enabled) {
        return this.$options.i18n.enabled;
      }
      if (this.available) {
        return this.$options.i18n.notEnabled;
      }
      return this.$options.i18n.availableWith;
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
    async toggleCVS(checked) {
      const oldValue = this.toggleValue;

      try {
        this.isRunningMutation = true;
        this.toggleValue = checked;

        this.clearError();

        const { data } = await this.$apollo.mutate({
          mutation: SetContainerScanningForRegistry,
          variables: {
            input: {
              namespacePath: this.projectFullPath,
              enable: checked,
            },
          },
        });

        const { errors } = data.setContainerScanningForRegistry;

        if (errors.length > 0) {
          throw new Error(errors[0].message);
        } else {
          this.toggleValue =
            data.setContainerScanningForRegistry.containerScanningForRegistryEnabled;

          this.$toast.show(
            this.toggleValue
              ? this.$options.i18n.toastMessageEnabled
              : this.$options.i18n.toastMessageDisabled,
          );
        }
      } catch (error) {
        this.toggleValue = oldValue;
        this.reportError(error);
      } finally {
        this.isRunningMutation = false;
      }
    },
  },
  i18n: {
    enabled: s__('SecurityConfiguration|Enabled'),
    notEnabled: s__('SecurityConfiguration|Not enabled'),
    availableWith: s__('SecurityConfiguration|Available with Ultimate'),
    learnMore: __('Learn more'),
    tooltipTitle: s__('CVS|Action unavailable'),
    accessLevelTooltipDescription: s__(
      'CVS|Only security managers, maintainers, and owners can toggle this feature.',
    ),
    toastMessageEnabled: s__('CVS|Container Scanning for Registry is enabled'),
    toastMessageDisabled: s__('CVS|Container Scanning for Registry is disabled'),
  },
};
</script>

<template>
  <gl-card :class="cardClasses">
    <template #header>
      <div class="gl-flex gl-items-baseline">
        <h3 class="gl-m-0 gl-mr-3 gl-text-base" :class="textClasses">
          {{ feature.name }}
          <gl-icon v-if="showLock" id="ContainerScanningLockIcon" name="lock" class="gl-mb-1" />
        </h3>
        <gl-popover v-if="showLock" target="ContainerScanningLockIcon" placement="right">
          <template #title> {{ $options.i18n.tooltipTitle }}</template>
          <slot>
            {{ featureLockDescription }}
          </slot>
        </gl-popover>

        <div
          :class="statusClasses"
          data-testid="feature-status"
          :data-qa-feature="`${feature.type}_${enabled}_status`"
        >
          <span>
            <gl-icon v-if="enabled" name="check-circle-filled" />
            <span class="{gl-text-success: enabled}">{{ statusText }}</span>
          </span>
        </div>
      </div>
    </template>

    <p class="gl-mb-0" :class="textClasses">
      {{ feature.description }}
      <gl-link :href="feature.helpPath" target="_blank">{{ $options.i18n.learnMore }}.</gl-link>
    </p>

    <template v-if="available">
      <gl-alert
        v-if="shouldShowAlert"
        class="gl-mb-5 gl-mt-2"
        variant="danger"
        @dismiss="isAlertDismissed = true"
        >{{ errorMessage }}
      </gl-alert>
      <div class="gl-mt-5 gl-flex gl-items-center">
        <gl-toggle
          :disabled="isToggleDisabled"
          :value="toggleValue"
          :label="s__('SecurityConfiguration|Toggle Container Scanning for Registry')"
          label-position="hidden"
          @change="toggleCVS"
        />
        <gl-loading-icon v-if="isRunningMutation" inline class="gl-ml-3" />
      </div>
    </template>
  </gl-card>
</template>
