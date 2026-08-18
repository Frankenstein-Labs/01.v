<script>
import { GlBadge, GlLink, GlToggle, GlToastMixin } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import enrollMutation from 'ee/ci/secrets/graphql/mutations/enroll_namespace_secrets_manager.mutation.graphql';
import unenrollMutation from '../graphql/unenroll_namespace_secrets_manager.mutation.graphql';

export default {
  name: 'SecretsManagerSaasEnrollmentToggle',
  components: {
    GlBadge,
    GlLink,
    GlToggle,
  },
  mixins: [glFeatureFlagsMixin(), GlToastMixin],
  props: {
    canManageEnrollment: {
      type: Boolean,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
    hasEnrollmentQueryError: {
      type: Boolean,
      required: true,
    },
    isEnrolled: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['toggled'],
  data() {
    return {
      errorMessage: null,
      isLoading: false,
    };
  },
  computed: {
    isToggleDisabled() {
      return (
        !this.canManageEnrollment ||
        this.hasEnrollmentQueryError ||
        this.isLoading ||
        (this.showPaidExperience && this.disabled)
      );
    },
    showPaidExperience() {
      return this.glFeatures.secretsManagerPaidExperience;
    },
  },
  methods: {
    async enrollNamespace() {
      this.isLoading = true;
      this.errorMessage = null;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: enrollMutation,
          variables: { fullPath: this.fullPath },
        });

        const { errors } = data.namespaceSecretsManagerEnroll;

        if (errors.length > 0) {
          throw new Error(errors[0]);
        }

        this.$emit('toggled');
        this.$toast.show(
          s__('SecretsManagerPermissions|GitLab Secrets Manager is enabled for this namespace.'),
        );
      } catch (error) {
        this.errorMessage =
          error.message ||
          s__(
            'SecretsManagerPermissions|An error occurred while enabling the secrets manager for this namespace.',
          );
        Sentry.captureException(error);
      } finally {
        this.isLoading = false;
      }
    },
    callMutation() {
      if (this.isEnrolled) {
        this.unenrollNamespace();
      } else {
        this.enrollNamespace();
      }
    },
    async unenrollNamespace() {
      this.isLoading = true;
      this.errorMessage = null;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: unenrollMutation,
          variables: { fullPath: this.fullPath },
        });

        const { errors } = data.namespaceSecretsManagerUnenroll;

        if (errors.length > 0) {
          throw new Error(errors[0]);
        }

        this.$emit('toggled');
        this.$toast.show(
          s__('SecretsManagerPermissions|GitLab Secrets Manager is disabled for this namespace.'),
        );
      } catch (error) {
        this.errorMessage =
          error.message ||
          s__(
            'SecretsManagerPermissions|An error occurred while disabling the secrets manager for this namespace.',
          );
        Sentry.captureException(error);
      } finally {
        this.isLoading = false;
      }
    },
  },
  LEARN_MORE_LINK: helpPagePath('ci/secrets/secrets_manager/_index'),
};
</script>

<template>
  <div>
    <label class="gl-mb-1" for="gsm-enrollment-toggle">
      {{ s__('SecretsManagerPermissions|Secrets manager') }}
    </label>
    <gl-badge v-if="!showPaidExperience" data-testid="open-beta-badge" variant="neutral">
      {{ __('Beta') }}
    </gl-badge>
    <p class="gl-mb-2 gl-text-subtle">
      {{
        s__(
          'SecretsManagerPermissions|Allow the secrets manager to be enabled in any project or subgroup in this group.',
        )
      }}
      <gl-link :href="$options.LEARN_MORE_LINK">
        {{ __('Learn more.') }}
      </gl-link>
    </p>
    <gl-toggle
      id="gsm-enrollment-toggle"
      :value="isEnrolled"
      :label="s__('SecretsManagerPermissions|Secrets manager')"
      :disabled="isToggleDisabled"
      :is-loading="isLoading"
      data-testid="gsm-enrollment-toggle"
      label-position="hidden"
      name="gsm-enrollment-toggle"
      @change="callMutation"
    />
    <p
      v-if="errorMessage"
      class="gl-mb-0 gl-mt-2 gl-text-danger"
      data-testid="gsm-enrollment-error"
    >
      {{ errorMessage }}
    </p>
  </div>
</template>
