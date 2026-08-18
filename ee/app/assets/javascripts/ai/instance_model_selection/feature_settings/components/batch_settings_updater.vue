<script>
import { GlIcon, GlTooltip, GlToastMixin } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__, sprintf } from '~/locale';
import BatchUpdateButton from 'ee/ai/shared/feature_settings/batch_update_button.vue';
import updateAiFeatureSettings from '../graphql/mutations/update_ai_feature_setting.mutation.graphql';
import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';
import { PROVIDERS } from '../constants';

export default {
  name: 'InstanceModelSelectionBatchSettingsUpdater',
  components: {
    BatchUpdateButton,
    GlIcon,
    GlTooltip,
  },
  mixins: [GlToastMixin],
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
    selectedFeatureSettingUnassigned() {
      if (this.selectedFeatureSettingHasGitlabManagedModels) return false;

      return this.selectedFeatureSetting.provider === PROVIDERS.UNASSIGNED;
    },
    selectedFeatureSettingDisabled() {
      return this.selectedFeatureSetting.provider === PROVIDERS.DISABLED;
    },
    selectedFeatureSettingSelfHosted() {
      return this.selectedFeatureSetting.provider === PROVIDERS.SELF_HOSTED;
    },
    selectedFeatureSettingHasGitlabManagedModels() {
      return this.selectedFeatureSetting.validGitlabModels?.nodes.length;
    },

    selectedFeatureSettingVendored() {
      return this.selectedFeatureSetting.provider === PROVIDERS.VENDORED;
    },
    selectedModelCompatibleWithAllSettings() {
      const selectedModelId = this.selectedFeatureSetting.selfHostedModel?.id;

      if (!selectedModelId) return false;

      return this.aiFeatureSettings.every((fs) => {
        const validModels = fs.validModels?.nodes?.map((model) => model.id);

        return validModels.includes(selectedModelId);
      });
    },
    canBatchUpdate() {
      if (this.selectedFeatureSettingDisabled) {
        return false;
      }

      if (this.selectedFeatureSettingVendored) {
        return true;
      }

      return this.selectedModelCompatibleWithAllSettings;
    },
    tooltipTitle() {
      let tooltipText;

      if (this.canBatchUpdate) {
        tooltipText = s__('AdminSelfHostedModels|Apply to all %{mainFeature} sub-features');
      } else if (this.selectedFeatureSettingUnassigned || this.selectedFeatureSettingDisabled) {
        tooltipText = s__(
          'AdminSelfHostedModels|Assign a model to %{subFeature} before applying to all',
        );
      } else {
        tooltipText = s__(
          'AdminSelfHostedModels|This model cannot be applied to all %{mainFeature} sub-features',
        );
      }

      return sprintf(tooltipText, {
        mainFeature: this.selectedFeatureSetting.mainFeature,
        subFeature: this.selectedFeatureSetting.title,
      });
    },
    successMessage() {
      return sprintf(
        s__('AdminSelfHostedModels|Successfully updated all %{mainFeature} features'),
        {
          mainFeature: this.selectedFeatureSetting.mainFeature,
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
  warningTooltipTitle: s__('AdminSelfHostedModels|Assign a model to enable this feature'),
  methods: {
    async onClick() {
      this.$emit('update-batch-saving-state', true);

      try {
        const features = this.aiFeatureSettings.map((fs) => fs.feature.toUpperCase());
        const { provider, selfHostedModel } = this.selectedFeatureSetting;

        const { data } = await this.$apollo.mutate({
          mutation: updateAiFeatureSettings,
          variables: {
            input: {
              features,
              provider: provider.toUpperCase(),
              aiSelfHostedModelId: this.selectedFeatureSettingSelfHosted
                ? selfHostedModel?.id
                : null,
            },
          },
          refetchQueries: [{ query: getAiFeatureSettingsQuery }],
        });

        if (data) {
          const { errors } = data.aiFeatureSettingUpdate;

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
  <div :class="{ 'gl-flex gl-w-full gl-justify-between': selectedFeatureSettingUnassigned }">
    <div v-if="selectedFeatureSettingUnassigned" ref="unAssignedFeatureWarning">
      <div
        class="gl-flex gl-h-7 gl-w-7 gl-items-center gl-justify-center gl-rounded-base gl-bg-orange-50"
      >
        <gl-icon
          data-testid="warning-icon"
          :aria-label="$options.warningTooltipTitle"
          name="warning"
          variant="warning"
          :size="16"
        />
      </div>
      <gl-tooltip
        data-testid="unassigned-feature-tooltip"
        :target="() => $refs.unAssignedFeatureWarning"
        :title="$options.warningTooltipTitle"
      />
    </div>
    <batch-update-button
      v-if="!selectedFeatureSettingHasGitlabManagedModels"
      :main-feature="selectedFeatureSetting.mainFeature"
      :disabled="!canBatchUpdate"
      :tooltip-title="tooltipTitle"
      @batch-update="onClick"
    />
  </div>
</template>
