<script>
import { GlFormGroup, GlFormInput, GlFormTextarea, GlButton } from '@gitlab/ui';

export default {
  name: 'StreamDestinationEditorGcpFields',
  components: {
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlButton,
  },
  props: {
    value: {
      type: Object,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['input'],
  data() {
    return {
      config: {
        logIdName: this.value.config.logIdName,
        clientEmail: this.value.config.clientEmail,
        googleProjectIdName: this.value.config.googleProjectIdName,
      },
      privateKey: this.value.secretToken,
      addingPrivateKey: false,
    };
  },
  computed: {
    shouldShowPrivateKey() {
      return !this.isEditing || (this.isEditing && this.addingPrivateKey);
    },
  },
  watch: {
    config: {
      handler(newConfig) {
        this.$emit('input', {
          ...this.value,
          config: {
            ...this.value.config,
            ...newConfig,
          },
        });
      },
      deep: true,
    },
    privateKey: {
      handler(newAccessKey) {
        this.$emit('input', {
          ...this.value,
          secretToken: newAccessKey,
        });
      },
    },
  },
  methods: {
    privateKeyFormatter(value) {
      return value.replaceAll('\\n', '\n');
    },
  },
};
</script>
<template>
  <div>
    <gl-form-group :label="s__('AuditStreams|Project ID')" data-testid="project-id-form-group">
      <gl-form-input
        v-model="config.googleProjectIdName"
        :placeholder="s__('AuditStreams|my-google-project')"
        data-testid="project-id"
      />
    </gl-form-group>
    <gl-form-group :label="s__('AuditStreams|Client Email')" data-testid="client-email-form-group">
      <gl-form-input
        v-model="config.clientEmail"
        :placeholder="s__('AuditStreams|my-email@my-google-project.iam.gservice.account.com')"
        data-testid="client-email"
      />
    </gl-form-group>
    <gl-form-group :label="s__('AuditStreams|Log ID')" data-testid="log-id-form-group">
      <gl-form-input
        v-model="config.logIdName"
        :placeholder="s__('AuditStreams|audit-events')"
        data-testid="log-id"
      />
    </gl-form-group>

    <gl-form-group :label="s__('AuditStreams|Private key')" data-testid="private-key-form-group">
      <div v-if="isEditing" class="gl-pb-3">
        {{
          s__(
            'AuditStreams|Use the Google Cloud console to view the private key. To change the private key, replace it with a new private key.',
          )
        }}
        <gl-button
          size="small"
          category="secondary"
          variant="confirm"
          data-testid="private-key-add-button"
          :disabled="shouldShowPrivateKey"
          @click="addingPrivateKey = !addingPrivateKey"
          >{{ s__('AuditStreams|Add a new private key') }}</gl-button
        >
        <gl-button
          v-if="shouldShowPrivateKey"
          size="small"
          data-testid="private-key-cancel-button"
          @click="addingPrivateKey = !addingPrivateKey"
          >{{ __('Cancel') }}</gl-button
        >
      </div>
      <gl-form-textarea
        v-if="shouldShowPrivateKey"
        v-model="privateKey"
        rows="16"
        no-resize
        :formatter="privateKeyFormatter"
        class="!gl-h-auto"
        data-testid="private-key"
      />
    </gl-form-group>
  </div>
</template>
