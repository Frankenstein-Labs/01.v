<script>
import { GlButton } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import toast from '~/vue_shared/plugins/global_toast';
import axios from '~/lib/utils/axios_utils';
import { s__ } from '~/locale';

export default {
  name: 'DuoOtelInfo',
  components: {
    GlButton,
  },
  props: {
    createWorkflowPath: {
      type: String,
      required: true,
      validator: (value) => value.startsWith('/'),
    },
  },
  data() {
    return {
      isLoading: false,
    };
  },
  methods: {
    async startOtelWorkflow() {
      this.isLoading = true;
      try {
        await axios.post(this.createWorkflowPath);
        toast(this.$options.i18n.successMessage);
      } catch (error) {
        Sentry.captureException(error);
        createAlert({
          message: this.$options.i18n.errorMessage,
        });
      } finally {
        this.isLoading = false;
      }
    },
  },
  i18n: {
    buttonText: s__('Observability|Add OpenTelemetry with Duo'),
    successMessage: s__('Observability|OpenTelemetry workflow started'),
    errorMessage: s__('Observability|Failed to start workflow'),
  },
};
</script>

<template>
  <div class="project-page-sidebar-block gl-border-b gl-border-subtle gl-py-4">
    <gl-button
      category="primary"
      variant="confirm"
      icon="tanuki-ai"
      :loading="isLoading"
      @click="startOtelWorkflow"
    >
      {{ $options.i18n.buttonText }}
    </gl-button>
  </div>
</template>
