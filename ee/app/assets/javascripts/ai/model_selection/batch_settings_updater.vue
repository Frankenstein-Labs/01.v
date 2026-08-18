<script>
import { GlToastMixin } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__, sprintf } from '~/locale';
import BatchUpdateButton from 'ee/ai/shared/feature_settings/batch_update_button.vue';
import updateAiNamespaceFeatureSettingsMutation from './graphql/update_ai_namespace_feature_settings.mutation.graphql';
import getAiNamespaceFeatureSettingsQuery from './graphql/get_ai_namepace_feature_settings.query.graphql';

export default {
  name: 'ModelSelectionBatchSettingsUpdater',
  components: {
    BatchUpdateButton,
  },
  mixins: [GlToastMixin],
  inject: ['groupId'],
  props: {
    aiFeatureSettings: {
      type: Array,
      required: true,
    },
    selectedFeatureSetting: {
      type: Object,
      required: true,
    },
  },
  emits: ['update-batch-saving-state'],
  computed: {
    selectedModelRef() {
      return this.selectedFeatureSetting.selectedModel?.ref;
    },
    canBatchUpdate() {
      // 'GitLab Default' (falsy value) is always batch update-able
      if (!this.selectedModelRef) return true;

      return this.aiFeatureSettings.every((fs) => {
        const selectableModelRefs = fs.selectableModels.map((model) => model?.ref);

        return selectableModelRefs.includes(this.selectedModelRef);
      });
    },
    tooltipTitle() {
      const tooltipText = this.canBatchUpdate
        ? s__('AdminSelfHostedModels|Apply to all %{mainFeature} sub-features')
        : s__(
            'AdminSelfHostedModels|This model cannot be applied to all %{mainFeature} sub-features',
          );

      return sprintf(tooltipText, { mainFeature: this.selectedFeatureSetting.mainFeature });
    },
    successMessage() {
      return sprintf(
        s__('ModelSelection|Successfully updated all %{mainFeature} features'),
        {
          mainFeature: this.aiFeatureSettings[0].mainFeature,
        },
        false,
      );
    },
    errorMessage() {
      return sprintf(
        s__(
          'AdminSelfHostedModels|An error occurred while updating the %{mainFeature} sub-feature settings. Please try again.',
        ),
        { mainFeature: this.selectedFeatureSetting.mainFeature },
        false,
      );
    },
  },
  methods: {
    async onClick() {
      this.$emit('update-batch-saving-state', true);

      try {
        const features = this.aiFeatureSettings.map((fs) => fs.feature.toUpperCase());

        const { data } = await this.$apollo.mutate({
          mutation: updateAiNamespaceFeatureSettingsMutation,
          variables: {
            input: {
              features,
              groupId: this.groupId,
              offeredModelRef: this.selectedModelRef,
            },
          },
          refetchQueries: [
            { query: getAiNamespaceFeatureSettingsQuery, variables: { groupId: this.groupId } },
          ],
        });

        if (data) {
          const { errors } = data.aiModelSelectionNamespaceUpdate;

          if (errors.length > 0) {
            throw new Error(errors[0]);
          }

          this.$toast.show(this.successMessage);
        }
      } catch (error) {
        createAlert({
          message: this.errorMessage,
          error,
          captureError: true,
        });
      } finally {
        this.$emit('update-batch-saving-state', false);
      }
    },
  },
};
</script>
<template>
  <batch-update-button
    :main-feature="selectedFeatureSetting.mainFeature"
    :tooltip-title="tooltipTitle"
    :disabled="!canBatchUpdate"
    @batch-update="onClick"
  />
</template>
