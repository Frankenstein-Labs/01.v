<script>
import { GlButton, GlFormCheckbox, GlModal, GlSprintf } from '@gitlab/ui';
import { GITLAB_DEFAULT_MODEL, SUPPRESS_DEFAULT_MODEL_MODAL_KEY } from './constants';

export default {
  name: 'GitlabDefaultModelModal',
  components: {
    GlButton,
    GlFormCheckbox,
    GlModal,
    GlSprintf,
  },
  emits: ['confirm-submit'],
  data() {
    return {
      suppressModal: false,
    };
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- Invoked by parent component
    showModal() {
      this.$refs.modal.show();
    },
    hideModal() {
      this.$refs.modal.hide();
    },
    confirmSubmit() {
      this.$emit('confirm-submit', GITLAB_DEFAULT_MODEL);
    },
    onSubmit() {
      if (this.suppressModal) {
        localStorage.setItem(SUPPRESS_DEFAULT_MODEL_MODAL_KEY, 'true');
      }

      this.confirmSubmit();
      this.hideModal();
    },
  },
};
</script>
<template>
  <gl-modal
    ref="modal"
    modal-id="default-model-modal"
    :title="s__('ModelSelection|GitLab default model')"
  >
    <template #default>
      <p>
        <gl-sprintf
          :message="
            s__(
              'ModelSelection|When you select the %{boldStart}GitLab default model%{boldEnd}, this feature will use the current GitLab managed default model for this feature and automatically updates when GitLab changes this default.',
            )
          "
        >
          <template #bold="{ content }">
            <span class="gl-font-bold">{{ content }}</span>
          </template>
        </gl-sprintf>
      </p>
      <p>
        {{
          s__(
            'ModelSelection|If you select a specific model, this feature will continue to use your selection regardless of any changes to GitLab default models.',
          )
        }}
      </p>
    </template>
    <template #modal-footer>
      <div class="gl-flex gl-items-baseline">
        <gl-form-checkbox v-model="suppressModal" class="gl-mr-5">
          {{ __('Do not show again') }}
        </gl-form-checkbox>
        <div>
          <gl-button data-testid="cancel-button" @click="hideModal">
            {{ __('Cancel') }}
          </gl-button>
          <gl-button data-testid="confirm-button" type="submit" variant="confirm" @click="onSubmit">
            {{ __('Confirm') }}
          </gl-button>
        </div>
      </div>
    </template>
  </gl-modal>
</template>
