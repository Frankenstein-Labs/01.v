<script>
import { GlFormGroup, GlFormInput, GlFormTextarea, GlButton } from '@gitlab/ui';

export default {
  name: 'StreamDestinationEditorAwsFields',
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
        accessKeyXid: this.value.config.accessKeyXid,
        awsRegion: this.value.config.awsRegion,
        bucketName: this.value.config.bucketName,
      },
      secretAccessKey: this.value.secretToken,
      addingSecretAccessKey: false,
    };
  },
  computed: {
    shouldShowSecretAccessKey() {
      return !this.isEditing || (this.isEditing && this.addingSecretAccessKey);
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
    secretAccessKey: {
      handler(newAccessKey) {
        this.$emit('input', {
          ...this.value,
          secretToken: newAccessKey,
        });
      },
    },
  },
  methods: {
    secretAccessKeyFormatter(value) {
      return value.replaceAll('\\n', '\n');
    },
  },
};
</script>
<template>
  <div>
    <gl-form-group
      :label="s__('AuditStreams|Access Key ID')"
      data-testid="access-key-xid-form-group"
    >
      <gl-form-input
        v-model="config.accessKeyXid"
        :placeholder="s__('AuditStreams|AKIA1231dsdsdsdsds23')"
        data-testid="access-key-xid"
      />
    </gl-form-group>
    <gl-form-group :label="s__('AuditStreams|AWS Region')" data-testid="aws-region-form-group">
      <gl-form-input
        v-model="config.awsRegion"
        :placeholder="'us-east-1'"
        data-testid="aws-region"
      />
    </gl-form-group>
    <gl-form-group :label="s__('AuditStreams|Bucket Name')" data-testid="bucket-name-form-group">
      <gl-form-input
        v-model="config.bucketName"
        :placeholder="s__('AuditStreams|bucket-name')"
        data-testid="bucket-name"
      />
    </gl-form-group>

    <gl-form-group
      :label="s__('AuditStreams|Secret Access Key')"
      data-testid="secret-access-key-form-group"
    >
      <div v-if="isEditing" class="gl-pb-3">
        {{
          s__(
            'AuditStreams|Use the AWS console to view the secret access key. To change the secret access key, replace it with a new secret access key.',
          )
        }}
        <gl-button
          size="small"
          category="secondary"
          variant="confirm"
          data-testid="secret-access-key-add-button"
          :disabled="shouldShowSecretAccessKey"
          @click="addingSecretAccessKey = !addingSecretAccessKey"
          >{{ s__('AuditStreams|Add a new secret access key') }}</gl-button
        >
        <gl-button
          v-if="shouldShowSecretAccessKey"
          size="small"
          data-testid="secret-access-key-cancel-button"
          @click="addingSecretAccessKey = !addingSecretAccessKey"
          >{{ __('Cancel') }}</gl-button
        >
      </div>
      <gl-form-textarea
        v-if="shouldShowSecretAccessKey"
        v-model="secretAccessKey"
        rows="16"
        no-resize
        :formatter="secretAccessKeyFormatter"
        class="!gl-h-auto"
        data-testid="secret-access-key"
      />
    </gl-form-group>
  </div>
</template>
