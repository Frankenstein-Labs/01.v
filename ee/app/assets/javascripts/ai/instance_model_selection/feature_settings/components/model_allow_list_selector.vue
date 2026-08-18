<script>
import { GlToastMixin } from '@gitlab/ui';
import AvailableModelsModal from 'ee/ai/shared/feature_settings/available_models_modal.vue';
import { s__, sprintf } from '~/locale';
import updateModelAllowlist from '../graphql/mutations/update_model_allowlist.mutation.graphql';
import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';

export default {
  name: 'ModelAllowListSelector',
  components: {
    AvailableModelsModal,
  },
  mixins: [GlToastMixin],
  props: {
    aiFeatureSetting: {
      type: Object,
      required: false,
      default: null,
    },
    visible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['update:visible'],
  data() {
    return {
      isSaving: false,
      errorMessage: '',
    };
  },
  computed: {
    availableModels() {
      return this.aiFeatureSetting?.allowList?.models?.nodes ?? [];
    },
    gitlabDefaultModel() {
      return this.aiFeatureSetting.defaultGitlabModel;
    },
    chosenModelForFeature() {
      const chosenModel = this.aiFeatureSetting.gitlabModel;

      return chosenModel ?? this.gitlabDefaultModel;
    },
    allowListEnabled() {
      return this.aiFeatureSetting?.allowList?.enabled ?? false;
    },
    featureTitle() {
      return this.aiFeatureSetting.title ?? '';
    },
  },
  methods: {
    async onSave({ enabled, allowedModelRefs }) {
      this.isSaving = true;
      this.errorMessage = '';

      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateModelAllowlist,
          variables: {
            input: {
              feature: this.aiFeatureSetting.feature.toUpperCase(),
              allowlistEnabled: enabled,
              allowlistModelRefs: allowedModelRefs,
            },
          },
          refetchQueries: [{ query: getAiFeatureSettingsQuery }],
        });

        const payload = data?.aiFeatureSettingModelAllowlistUpdate;

        // A resolved mutation with no payload means a top-level GraphQL error;
        // fall back to the default message rather than dereferencing null.
        if (!payload) {
          throw new Error();
        }

        if (payload.errors.length > 0) {
          throw new Error(payload.errors[0]);
        }

        this.$toast.show(this.successMessage());
        this.$emit('update:visible', false);
      } catch (error) {
        const defaultErrorMessage = s__(
          'AdminAIPoweredFeatures|An error occurred while updating the available models. Please try again.',
        );
        this.errorMessage = error.message || defaultErrorMessage;
      } finally {
        this.isSaving = false;
      }
    },
    successMessage() {
      return sprintf(
        s__('AdminAIPoweredFeatures|Successfully updated available models for %{title}'),
        {
          title: this.featureTitle,
        },
        false,
      );
    },
  },
};
</script>
<template>
  <available-models-modal
    v-if="aiFeatureSetting && chosenModelForFeature && visible"
    :available-models="availableModels"
    :chosen-model-for-feature="chosenModelForFeature"
    :feature-title="featureTitle"
    :allow-list-enabled="allowListEnabled"
    :visible="visible"
    :loading="isSaving"
    :error-message="errorMessage"
    @update:visible="$emit('update:visible', $event)"
    @update:error-message="errorMessage = $event"
    @save="onSave"
  />
</template>
