<script>
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import { RELEASE_STATES } from '../../constants';

export default {
  name: 'ModelSelector',
  components: {
    ModelSelectDropdown,
  },
  inject: ['modelOptions'],
  props: {
    selectedModel: {
      type: String,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['update:model'],
  computed: {
    availableModels() {
      const gaModels = this.modelOptions.filter(
        ({ releaseState }) => releaseState === RELEASE_STATES.GA,
      );
      const betaModels = this.modelOptions.filter(
        ({ releaseState }) => releaseState === RELEASE_STATES.BETA,
      );

      return [...gaModels, ...betaModels].map(({ modelValue, modelName, releaseState }) => ({
        value: modelValue,
        text: modelName,
        releaseState,
      }));
    },
    selectedOption() {
      return this.availableModels.find(({ value }) => value === this.selectedModel);
    },
  },
  methods: {
    onSelect(model) {
      this.$emit('update:model', model);
    },
  },
};
</script>

<template>
  <model-select-dropdown
    :selected-option="selectedOption"
    :items="availableModels"
    :placeholder-dropdown-text="s__('AdminSelfHostedModels|Select model')"
    :is-loading="isLoading"
    @select="onSelect"
  />
</template>
