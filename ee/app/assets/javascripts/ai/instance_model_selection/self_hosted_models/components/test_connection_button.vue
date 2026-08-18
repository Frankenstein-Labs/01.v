<script>
import { GlButton } from '@gitlab/ui';
import { createAlert } from '~/alert';
import testSelfHostedModelConnectionMutation from '../graphql/mutations/test_self_hosted_model_connection.mutation.graphql';

export default {
  name: 'TestConnectionButton',
  components: {
    GlButton,
  },
  props: {
    connectionTestInput: {
      type: Object,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      isLoading: false,
    };
  },
  methods: {
    async onSubmit() {
      try {
        this.isLoading = true;
        const { data } = await this.$apollo.mutate({
          mutation: testSelfHostedModelConnectionMutation,
          variables: {
            input: {
              ...this.connectionTestInput,
            },
          },
        });

        if (data) {
          const { result } = data.aiSelfHostedModelConnectionCheck;

          if (!result.success) {
            this.errors = result.errors;

            throw new Error(result.errors[0]);
          }

          createAlert({
            message: result.message,
            variant: 'success',
          });
        }
      } catch (error) {
        createAlert({
          message: error.message,
          error,
          captureError: true,
        });
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>
<template>
  <gl-button type="button" :loading="isLoading" :disabled="disabled" @click="onSubmit">
    {{ s__('AdminSelfHostedModels|Test connection') }}
  </gl-button>
</template>
