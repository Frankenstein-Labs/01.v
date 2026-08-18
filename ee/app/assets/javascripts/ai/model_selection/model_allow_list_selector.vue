<script>
import { GlToastMixin } from '@gitlab/ui';
import AvailableModelsModal from 'ee/ai/shared/feature_settings/available_models_modal.vue';
import { s__, sprintf } from '~/locale';
import { GITLAB_DEFAULT_MODEL } from './constants';
import updateNamespaceModelAllowlist from './graphql/update_namespace_model_allowlist.mutation.graphql';
import aiNamespaceFeatureSettingsQuery from './graphql/get_ai_namepace_feature_settings.query.graphql';

export default {
  name: 'ModelAllowListSelector',
  components: {
    AvailableModelsModal,
  },
  mixins: [GlToastMixin],
  inject: ['groupId'],
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
      return this.aiFeatureSetting?.defaultModel;
    },
    chosenModelForFeature() {
      const chosenModel = this.aiFeatureSetting?.selectedModel;

      if (!chosenModel || chosenModel.ref === GITLAB_DEFAULT_MODEL) {
        return this.gitlabDefaultModel;
      }

      return chosenModel;
    },
    allowListEnabled() {
      return this.aiFeatureSetting?.allowList?.enabled ?? false;
    },
    featureTitle() {
      return this.aiFeatureSetting?.title ?? '';
    },
  },
  methods: {
    async onSave({ enabled, allowedModelRefs }) {
      this.isSaving = true;
      this.errorMessage = '';

      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateNamespaceModelAllowlist,
          variables: {
            input: {
              groupId: this.groupId,
              feature: this.aiFeatureSetting.feature.toUpperCase(),
              allowlistEnabled: enabled,
              allowlistModelRefs: allowedModelRefs,
            },
          },
          refetchQueries: [
            { query: aiNamespaceFeatureSettingsQuery, variables: { groupId: this.groupId } },
          ],
        });

        const payload = data?.aiModelSelectionNamespaceModelAllowlistUpdate;

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
    v-if="chosenModelForFeature && visible"
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
