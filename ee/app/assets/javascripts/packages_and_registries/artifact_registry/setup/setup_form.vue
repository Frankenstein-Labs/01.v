<script>
import {
  GlAlert,
  GlButton,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormInputGroup,
  GlInputGroupText,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import { __, s__, sprintf } from '~/locale';
import {
  REGISTRY_HANDLE_BOUNDARY_PATTERN,
  REGISTRY_HANDLE_CHARSET_PATTERN,
  REGISTRY_HANDLE_MAX_LENGTH,
  REGISTRY_HANDLE_MIN_LENGTH,
  REGISTRY_HANDLE_PLACEHOLDER,
} from '../constants';
import activateArtifactRegistryMutation from '../graphql/mutations/activate_artifact_registry.mutation.graphql';
import HandleUsagePanel from './components/handle_usage_panel.vue';

const HANDLE_FIELD_ID = 'artifact-registry-handle';

export default {
  name: 'ArtifactRegistrySetupForm',
  i18n: {
    handleLabel: s__('ArtifactRegistry|Registry handle'),
    handleDescription: s__(
      'ArtifactRegistry|A permanent, unique identifier used across every Artifact Registry URL and client config file.',
    ),
    handleHint: s__(
      'ArtifactRegistry|Only lowercase letters, digits and hyphens (-) are allowed. Must start and end with an alphanumeric character.',
    ),
    handleRequired: s__('ArtifactRegistry|Registry handle is required.'),
    handleCharset: s__(
      'ArtifactRegistry|Only lowercase letters, digits and hyphens (-) are allowed. Remove any spaces or special characters.',
    ),
    handleBoundary: s__('ArtifactRegistry|Must start and end with an alphanumeric character.'),
    handleConsecutiveHyphens: s__('ArtifactRegistry|Must not contain consecutive hyphens (--).'),
    handleLength: sprintf(
      s__('ArtifactRegistry|Must be between %{min} and %{max} characters.'),
      { min: REGISTRY_HANDLE_MIN_LENGTH, max: REGISTRY_HANDLE_MAX_LENGTH },
      false,
    ),
    permanenceTitle: s__('ArtifactRegistry|Registry handle is permanent and globally reserved'),
    permanenceBody: s__(
      'ArtifactRegistry|This cannot be changed once claimed, even if Artifact Registry is disabled later. Choose something that represents your organization long-term.',
    ),
    submit: s__('ArtifactRegistry|Enable Artifact registry'),
    genericError: __('Something went wrong. Please try again.'),
  },
  components: {
    GlAlert,
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormInputGroup,
    GlInputGroupText,
    HandleUsagePanel,
  },
  inject: ['organizationGid', 'clientBaseUrl'],
  emits: ['success'],
  data() {
    return {
      handle: '',
      errorMessage: null,
      submitting: false,
    };
  },
  computed: {
    urlPrefix() {
      return this.clientBaseUrl ? `${this.clientBaseUrl}/` : null;
    },
    handleState() {
      return this.errorMessage ? false : null;
    },
  },
  watch: {
    handle() {
      this.errorMessage = null;
    },
  },
  methods: {
    validateHandle() {
      const { i18n } = this.$options;

      if (!this.handle) return i18n.handleRequired;

      if (!REGISTRY_HANDLE_CHARSET_PATTERN.test(this.handle)) return i18n.handleCharset;
      if (!REGISTRY_HANDLE_BOUNDARY_PATTERN.test(this.handle)) return i18n.handleBoundary;
      if (this.handle.includes('--')) return i18n.handleConsecutiveHyphens;

      if (
        this.handle.length < REGISTRY_HANDLE_MIN_LENGTH ||
        this.handle.length > REGISTRY_HANDLE_MAX_LENGTH
      ) {
        return i18n.handleLength;
      }

      return null;
    },
    async submit() {
      if (this.submitting) return;

      this.errorMessage = this.validateHandle();

      if (this.errorMessage) return;

      this.submitting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: activateArtifactRegistryMutation,
          variables: { input: { organizationId: this.organizationGid, handle: this.handle } },
        });

        const { registry, errors } = data.activateRegistry;

        if (errors.length) {
          this.errorMessage = errors.join(' ');
          this.submitting = false;
          return;
        }

        // Success navigates the page away, so the control stays busy rather than
        // re-enabling behind the redirect and inviting a second claim.
        this.$emit('success', registry);
      } catch (error) {
        createAlert({ message: this.$options.i18n.genericError, error, captureError: true });
        this.submitting = false;
      }
    },
  },
  handleFieldId: HANDLE_FIELD_ID,
  handlePlaceholder: REGISTRY_HANDLE_PLACEHOLDER,
};
</script>

<template>
  <gl-form class="@md/panel:gl-w-9/12" @submit.prevent="submit">
    <gl-form-group
      :label="$options.i18n.handleLabel"
      :label-description="$options.i18n.handleDescription"
      :label-for="$options.handleFieldId"
      :state="handleState"
      :invalid-feedback="errorMessage"
      data-testid="registry-handle-group"
    >
      <gl-form-input-group>
        <template v-if="urlPrefix" #prepend>
          <gl-input-group-text data-testid="handle-url-prefix">{{ urlPrefix }}</gl-input-group-text>
        </template>

        <gl-form-input
          :id="$options.handleFieldId"
          v-model="handle"
          :state="handleState"
          :placeholder="$options.handlePlaceholder"
          :readonly="submitting"
          data-testid="registry-handle"
        />

        <template v-if="urlPrefix" #append>
          <gl-input-group-text data-testid="handle-url-suffix">/...</gl-input-group-text>
        </template>
      </gl-form-input-group>

      <template #description>
        <span data-testid="registry-handle-hint">{{ $options.i18n.handleHint }}</span>
      </template>
    </gl-form-group>

    <handle-usage-panel :handle="handle" />

    <gl-alert
      variant="info"
      :title="$options.i18n.permanenceTitle"
      :dismissible="false"
      class="gl-mb-5"
      data-testid="permanence-callout"
    >
      {{ $options.i18n.permanenceBody }}
    </gl-alert>

    <gl-button
      class="js-no-auto-disable"
      variant="confirm"
      type="submit"
      :loading="submitting"
      data-testid="submit-activation"
    >
      {{ $options.i18n.submit }}
    </gl-button>
  </gl-form>
</template>
