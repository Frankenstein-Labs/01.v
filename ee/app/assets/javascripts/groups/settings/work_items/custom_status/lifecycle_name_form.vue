<script>
import { GlFormInput, GlFormGroup, GlButton } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { s__, __ } from '~/locale';
import lifecycleUpdateMutation from './graphql/lifecycle_update.mutation.graphql';

export default {
  name: 'LifecycleNameForm',
  components: {
    GlFormInput,
    GlFormGroup,
    GlButton,
  },
  props: {
    lifecycle: {
      type: Object,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
    cardHover: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLifecycleTemplate: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isEditing: false,
      isSubmitting: false,
      formData: {
        lifecycleName: this.lifecycle.name,
      },
      errorMessage: '',
    };
  },
  computed: {
    lifecycleId() {
      return getIdFromGraphQLId(this.lifecycle.id);
    },
  },
  methods: {
    resetForm() {
      this.formData = {
        lifecycleName: this.lifecycle.name,
      };
      this.errorMessage = '';
    },
    closeForm() {
      this.isEditing = false;
      this.resetForm();
    },
    async handleSave() {
      /** when the lifecycle name is empty */
      if (!this.formData.lifecycleName.trim()) {
        this.errorMessage = s__('WorkItem|Lifecycle name cannot be empty');
        return;
      }

      /** when the name is same as current */
      if (this.formData.lifecycleName === this.lifecycle.name) {
        this.closeForm();
        return;
      }

      this.isSubmitting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: lifecycleUpdateMutation,
          variables: {
            input: {
              namespacePath: this.fullPath,
              id: this.lifecycle.id,
              name: this.formData.lifecycleName,
            },
          },
          optimisticResponse: {
            lifecycleUpdate: {
              lifecycle: {
                name: this.formData.lifecycleName,
                ...this.lifecycle,
                __typename: 'WorkItemLifecycle',
              },
              errors: [],
              __typename: 'LifecycleUpdatePayload',
            },
          },
        });

        if (data?.lifecycleUpdate?.errors?.length) {
          throw new Error(data.lifecycleUpdate.errors.join(', '));
        }

        this.isEditing = false;
        this.errorMessage = '';
      } catch (error) {
        this.errorMessage = error.message || __('Something went wrong while updating the name');
        Sentry.captureException(error);
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>
<template>
  <div v-if="isEditing" class="gl-flex gl-flex-wrap gl-items-start gl-gap-3">
    <gl-form-group
      :label="s__('WorkItem|Lifecycle name')"
      :label-for="`lifecycle-name-${lifecycleId}`"
      label-sr-only
      class="gl-mb-0 gl-grow-2"
      :invalid-feedback="errorMessage"
      :state="!Boolean(errorMessage)"
    >
      <gl-form-input
        :id="`lifecycle-name-${lifecycleId}`"
        v-model="formData.lifecycleName"
        :placeholder="s__('WorkItem|Lifecycle name')"
        :maxlength="64"
        autofocus
        autocomplete="off"
        class="gl-grow-2"
        :state="!Boolean(errorMessage)"
        @keydown.enter="handleSave"
        @keydown.esc="closeForm"
      />
    </gl-form-group>

    <div class="gl-flex gl-gap-3">
      <gl-button
        :data-testid="`rename-${lifecycleId}`"
        variant="confirm"
        :disabled="isSubmitting"
        @click="handleSave"
      >
        {{ __('Save') }}
      </gl-button>
      <gl-button :data-testid="`cancel-rename-${lifecycleId}`" @click="closeForm">
        {{ __('Cancel') }}
      </gl-button>
    </div>
  </div>
  <div v-else class="gl-flex gl-min-h-7 gl-items-center">
    <span :data-testid="`name-${lifecycleId}`" class="gl-font-bold gl-text-strong">{{
      isLifecycleTemplate ? s__('WorkItem|Default statuses') : lifecycle.name
    }}</span>

    <gl-button
      :data-testid="`trigger-rename-${lifecycleId}`"
      category="tertiary"
      icon="pencil"
      size="small"
      class="gl-ml-3 gl-opacity-10 focus-visible:gl-opacity-10 @sm/panel:gl-opacity-0"
      :class="{ '!gl-opacity-10': cardHover }"
      @click="isEditing = true"
      >{{ __('Rename') }}</gl-button
    >
  </div>
</template>
