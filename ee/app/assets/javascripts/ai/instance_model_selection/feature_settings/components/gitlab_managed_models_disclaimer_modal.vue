<script>
import { GlButton, GlFormCheckbox, GlModal, GlSprintf } from '@gitlab/ui';
import { SUPPRESS_GITLAB_MANAGED_MODELS_DISCLAIMER_MODAL_KEY } from '../constants';

export default {
  name: 'GitlabManagedModelsDisclaimerModal',
  components: {
    GlButton,
    GlFormCheckbox,
    GlModal,
    GlSprintf,
  },
  emits: ['confirm'],
  data() {
    return {
      selectedModel: null,
      suppressModal: false,
    };
  },
  computed: {
    selectedModelName() {
      return this.selectedModel?.text || '';
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- Invoked by parent component
    showModal(selectedModel) {
      this.selectedModel = selectedModel;

      if (localStorage.getItem(SUPPRESS_GITLAB_MANAGED_MODELS_DISCLAIMER_MODAL_KEY)) {
        this.confirmSubmit();
        return;
      }

      this.$refs.modal.show();
    },
    hideModal() {
      this.$refs.modal.hide();
    },
    confirmSubmit() {
      this.$emit('confirm', this.selectedModel?.value);
    },
    onSubmit() {
      if (this.suppressModal) {
        localStorage.setItem(SUPPRESS_GITLAB_MANAGED_MODELS_DISCLAIMER_MODAL_KEY, 'true');
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
    modal-id="gitlab-managed-models-disclaimer-modal"
    :title="s__('AdminAIPoweredFeatures|GitLab managed model')"
  >
    <template #default>
      <gl-sprintf
        :message="
          s__(
            'ModelSelection|By selecting %{selectedGitlabManagedModel}, you consent to using a GitLab managed model and sending data to the GitLab AI gateway.',
          )
        "
      >
        <template #selectedGitlabManagedModel>
          <span class="gl-font-bold">{{ selectedModelName }}</span>
        </template>
      </gl-sprintf>
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
            {{ __('I understand') }}
          </gl-button>
        </div>
      </div>
    </template>
  </gl-modal>
</template>
