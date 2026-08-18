<script>
import { GlAlert, GlBadge, GlToggle, GlToastMixin } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { logError } from '~/lib/logger';
import { __, s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import SecretsManagerBillingAlert from 'ee/ci/secrets/components/secrets_manager_billing_alert.vue';
import { isProvisioningBlockedByEntitlement } from 'ee/ci/secrets/utils';
import getEntitlementQuery from 'ee/ci/secrets/graphql/queries/get_secrets_manager_entitlement.graphql';
import getInstanceSecretsManagerEnrollmentQuery from '../graphql/queries/get_instance_secrets_manager_enrollment.query.graphql';
import enrollInstanceSecretsManagerMutation from '../graphql/mutations/enroll_instance_secrets_manager.mutation.graphql';
import unenrollInstanceSecretsManagerMutation from '../graphql/mutations/unenroll_instance_secrets_manager.mutation.graphql';

export default {
  name: 'SecretsManagerInstanceEnrollmentToggle',
  components: {
    GlAlert,
    GlBadge,
    GlToggle,
    SecretsManagerBillingAlert,
  },
  i18n: {
    label: s__('SecretsManager|Secrets Manager'),
    helpText: s__(
      'SecretsManager|Enable Secrets Manager for this instance. When enabled, the secrets manager can be turned on for any project or group in the instance.',
    ),
    beta: __('Beta'),
    loadError: s__('SecretsManager|Failed to load Secrets Manager enrollment state.'),
    updateError: s__('SecretsManager|Failed to update Secrets Manager enrollment.'),
    enrollSuccess: s__('SecretsManager|Secrets Manager is enabled.'),
    unenrollSuccess: s__('SecretsManager|Secrets Manager is disabled.'),
  },
  mixins: [glFeatureFlagsMixin(), GlToastMixin],
  props: {
    topLevelGroupFullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      entitlement: null,
      errorMessage: '',
      isEnrolled: false,
      isMutating: false,
    };
  },
  apollo: {
    entitlement: {
      query: getEntitlementQuery,
      skip() {
        return !this.topLevelGroupFullPath;
      },
      variables() {
        return {
          fullPath: this.topLevelGroupFullPath,
        };
      },
      update(data) {
        return data.group?.secretsManagerEntitlement;
      },
      error(error) {
        this.reportError(this.$options.i18n.loadError, error);
      },
    },
    isEnrolled: {
      query: getInstanceSecretsManagerEnrollmentQuery,
      fetchPolicy: 'network-only',
      update(data) {
        return Boolean(data?.instanceSecretsManagerEnrollment?.enrolled);
      },
      error(error) {
        this.reportError(this.$options.i18n.loadError, error);
      },
    },
  },
  computed: {
    isBlockedByEntitlement() {
      return this.showPaidExperience && isProvisioningBlockedByEntitlement(this.entitlement);
    },
    isLoading() {
      return this.$apollo.queries.isEnrolled.loading || this.isMutating;
    },
    showPaidExperience() {
      return this.glFeatures.secretsManagerPaidExperience;
    },
  },
  methods: {
    reportError(message, error) {
      this.errorMessage = message;
      logError(message, error);
      Sentry.captureException(error);
    },
    toggleEnrollment(shouldEnroll) {
      return shouldEnroll ? this.enroll() : this.unenroll();
    },
    enroll() {
      return this.performMutation({
        mutation: enrollInstanceSecretsManagerMutation,
        responseKey: 'instanceSecretsManagerEnroll',
        nextValue: true,
        successMessage: this.$options.i18n.enrollSuccess,
      });
    },
    unenroll() {
      return this.performMutation({
        mutation: unenrollInstanceSecretsManagerMutation,
        responseKey: 'instanceSecretsManagerUnenroll',
        nextValue: false,
        successMessage: this.$options.i18n.unenrollSuccess,
      });
    },
    async performMutation({ mutation, responseKey, nextValue, successMessage }) {
      this.isMutating = true;
      this.errorMessage = '';

      try {
        const { data } = await this.$apollo.mutate({ mutation });
        const errors = data?.[responseKey]?.errors ?? [];

        if (errors.length) {
          throw new Error(errors.join(', '));
        }

        this.isEnrolled = nextValue;
        this.$toast.show(successMessage);
      } catch (error) {
        this.reportError(this.$options.i18n.updateError, error);
      } finally {
        this.isMutating = false;
      }
    },
  },
};
</script>
<template>
  <div>
    <gl-alert
      v-if="errorMessage"
      class="gl-mb-4"
      variant="danger"
      data-testid="enrollment-error-alert"
      @dismiss="errorMessage = ''"
    >
      {{ errorMessage }}
    </gl-alert>
    <div class="gl-flex gl-items-center gl-gap-2">
      <strong>{{ $options.i18n.label }}</strong>
      <gl-badge v-if="!showPaidExperience">{{ $options.i18n.beta }}</gl-badge>
    </div>
    <p class="gl-mb-3 gl-mt-2 gl-text-subtle">{{ $options.i18n.helpText }}</p>
    <gl-toggle
      :value="isEnrolled"
      :disabled="isLoading || isBlockedByEntitlement"
      :is-loading="isLoading"
      :label="$options.i18n.label"
      label-position="hidden"
      data-testid="secrets-manager-instance-enrollment-toggle"
      @change="toggleEnrollment"
    />
    <secrets-manager-billing-alert :entitlement="entitlement" />
  </div>
</template>
