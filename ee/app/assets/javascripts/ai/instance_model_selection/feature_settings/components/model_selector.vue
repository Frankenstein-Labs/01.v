<script>
import { GlButton, GlIcon, GlTooltipDirective, GlToastMixin } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import getSelfHostedModelsQuery from 'ee/ai/instance_model_selection/self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import { getTypeFromGraphQLId } from '~/graphql_shared/utils';
import { formatDefaultModelData } from 'ee/ai/shared/utils/model_selection_utils';
import {
  RELEASE_STATES,
  INSTANCE_MODEL_SELECTION_ROUTE_NAMES,
} from 'ee/ai/instance_model_selection/constants';
import { TYPENAME_AI_SELF_HOSTED_MODEL } from 'ee_else_ce/graphql_shared/constants';
import updateAiFeatureSetting from '../graphql/mutations/update_ai_feature_setting.mutation.graphql';
import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';
import { PROVIDERS, GITLAB_DEFAULT_MODEL, DAP_FEATURES } from '../constants';
import GitlabManagedModelsDisclaimerModal from './gitlab_managed_models_disclaimer_modal.vue';

export default {
  name: 'ModelSelector',
  components: {
    GlButton,
    GlIcon,
    ModelSelectDropdown,
    GitlabManagedModelsDisclaimerModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [GlToastMixin],
  inject: ['canManageSelfHostedModels', 'canManageDapSelfHostedModels'],
  props: {
    aiFeatureSetting: {
      type: Object,
      required: true,
    },
    batchUpdateIsSaving: {
      type: Boolean,
      required: true,
    },
    hasMixedSources: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['update:is-saving'],
  i18n: {
    defaultErrorMessage: s__(
      'AdminSelfHostedModels|An error occurred while updating the self-hosted model, please try again.',
    ),
    successMessage: s__('AdminSelfHostedModels|Successfully updated %{mainFeature} / %{title}'),
  },
  data() {
    return {
      isSaving: false,
    };
  },
  computed: {
    canAddSelfHostedModel() {
      if (DAP_FEATURES.includes(this.aiFeatureSetting.feature)) {
        return this.canManageDapSelfHostedModels;
      }

      return this.canManageSelfHostedModels;
    },
    isGitlabManagedModelSelected() {
      const { provider, gitlabModel } = this.aiFeatureSetting;
      // Refers to the GitLab managed models offered by instance-level model selection
      return provider === PROVIDERS.VENDORED && gitlabModel?.ref;
    },
    isSelfHostedModelSelected() {
      return this.aiFeatureSetting.provider === PROVIDERS.SELF_HOSTED;
    },
    sourceSubtext() {
      if (!this.hasMixedSources) return null;

      if (this.isSelfHostedModelSelected) {
        return s__('AdminSelfHostedModels|Self-hosted model');
      }

      if (this.isGitlabManagedModelSelected || this.isDefaultGitlabModelSelected) {
        return s__('AdminSelfHostedModels|GitLab managed model');
      }

      return null;
    },
    sourceTooltip() {
      if (!this.hasMixedSources) return null;

      if (this.isSelfHostedModelSelected) {
        return s__(
          'AdminSelfHostedModels|This feature is using a self-hosted model, deployed on your own infrastructure.',
        );
      }

      if (this.isGitlabManagedModelSelected || this.isDefaultGitlabModelSelected) {
        return s__(
          'AdminSelfHostedModels|This feature is using a GitLab managed model, external to your infrastructure.',
        );
      }

      return null;
    },
    isDefaultGitlabModelSelected() {
      const { provider, gitlabModel, defaultGitlabModel } = this.aiFeatureSetting;

      if (!defaultGitlabModel) return false;

      return Boolean(
        (provider === PROVIDERS.VENDORED && !gitlabModel) || provider === PROVIDERS.UNASSIGNED,
      );
    },
    selectedOption() {
      const { provider, selfHostedModel, gitlabModel } = this.aiFeatureSetting;
      let selected = provider;

      if (provider === PROVIDERS.SELF_HOSTED) {
        selected = selfHostedModel?.id;
      }

      if (this.isGitlabManagedModelSelected) {
        selected = gitlabModel?.ref;
      }

      if (this.isDefaultGitlabModelSelected) {
        selected = GITLAB_DEFAULT_MODEL;
      }

      const match = this.listItems
        .flatMap((item) => item.options ?? item)
        .find((item) => item.value === selected);

      if (!match) return null;

      if (this.sourceSubtext) {
        return { ...match, subtext: this.sourceSubtext };
      }

      return match;
    },
    listItems() {
      const { selfHostedModels, gitlabManagedModels } = this;

      const disabledOption = {
        value: PROVIDERS.DISABLED,
        text: s__('AdminAIPoweredFeatures|Disabled'),
      };

      const items = [];

      if (selfHostedModels.length) {
        items.push({
          text: s__('AdminSelfHostedModels|Self-hosted models'),
          options: [...selfHostedModels, disabledOption],
        });
      }

      if (gitlabManagedModels.length) {
        items.push({
          text: s__('AdminSelfHostedModels|GitLab managed models'),
          options: gitlabManagedModels,
        });
      }

      return items;
    },
    selfHostedModels() {
      const validModels = this.aiFeatureSetting.validModels?.nodes || [];
      const gaModels = validModels.filter(({ releaseState }) => releaseState === RELEASE_STATES.GA);
      const betaModels = validModels.filter(
        ({ releaseState }) => releaseState === RELEASE_STATES.BETA,
      );

      // sorted by releaseState
      return [...gaModels, ...betaModels].map(({ name, modelDisplayName, id, releaseState }) => ({
        value: id,
        text: `${name} (${modelDisplayName})`,
        releaseState,
      }));
    },
    gitlabManagedModels() {
      const validGitlabModels = this.aiFeatureSetting.validGitlabModels?.nodes || [];
      const { defaultGitlabModel } = this.aiFeatureSetting;

      const models = validGitlabModels.map(
        ({ name, ref, modelProvider, modelDescription, costIndicator }) => ({
          value: ref,
          text: name,
          provider: modelProvider,
          description: modelDescription,
          costIndicator,
        }),
      );

      if (defaultGitlabModel) {
        const formattedDefaultGitLabModel = formatDefaultModelData(defaultGitlabModel);

        models.push(formattedDefaultGitLabModel);
      }

      return models;
    },
  },

  methods: {
    async onSelect(selectedOptionValue) {
      const provider = this.getProvider(selectedOptionValue);

      if (provider === PROVIDERS.VENDORED) {
        const selectedOption = this.gitlabManagedModels.find(
          ({ value }) => value === selectedOptionValue,
        );
        this.$refs.disclaimerModal.showModal(selectedOption);
        return;
      }

      await this.updateSelectedModel(selectedOptionValue);
    },
    async updateSelectedModel(selectedOption) {
      this.onSave(true);

      const provider = this.getProvider(selectedOption);

      const offeredModelRef = provider === PROVIDERS.VENDORED ? selectedOption : null;
      const selfHostedModelId = provider === PROVIDERS.SELF_HOSTED ? selectedOption : null;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateAiFeatureSetting,
          variables: {
            input: {
              features: [this.aiFeatureSetting.feature.toUpperCase()],
              provider: provider.toUpperCase(),
              aiSelfHostedModelId: selfHostedModelId,
              offeredModelRef,
            },
          },
          refetchQueries: [
            { query: getSelfHostedModelsQuery },
            { query: getAiFeatureSettingsQuery },
          ],
          awaitRefetchQueries: true,
        });

        if (data) {
          const { errors } = data.aiFeatureSettingUpdate;

          if (errors.length > 0) {
            throw new Error(errors[0]);
          }

          this.$toast.show(this.successMessage(this.aiFeatureSetting));
        }
      } catch (error) {
        createAlert({
          message: this.errorMessage(error),
          error,
          captureError: true,
        });
      } finally {
        this.onSave(false);
      }
    },
    onSave(value) {
      this.isSaving = value;
      this.$emit('update:is-saving', value);
    },
    getProvider(option) {
      if (option === PROVIDERS.DISABLED) return PROVIDERS.DISABLED;

      const gqlType = getTypeFromGraphQLId(option);

      if (gqlType === TYPENAME_AI_SELF_HOSTED_MODEL) return PROVIDERS.SELF_HOSTED;

      return PROVIDERS.VENDORED;
    },
    errorMessage(error) {
      return error.message || this.$options.i18n.defaultErrorMessage;
    },
    successMessage(aiFeatureSetting) {
      return sprintf(
        this.$options.i18n.successMessage,
        {
          mainFeature: aiFeatureSetting.mainFeature,
          title: aiFeatureSetting.title,
        },
        false,
      );
    },
  },
  INSTANCE_MODEL_SELECTION_ROUTE_NAMES,
};
</script>
<template>
  <div class="gl-flex gl-items-center gl-gap-3">
    <gitlab-managed-models-disclaimer-modal ref="disclaimerModal" @confirm="updateSelectedModel" />
    <model-select-dropdown
      class="gl-w-34 lg:gl-w-48"
      :header-text="s__('AdminAIPoweredFeatures|Compatible models')"
      :selected-option="selectedOption"
      :items="listItems"
      :placeholder-dropdown-text="s__('AdminAIPoweredFeatures|Select a model')"
      :is-loading="isSaving || batchUpdateIsSaving"
      @select="onSelect"
    >
      <template v-if="canAddSelfHostedModel" #footer>
        <div class="gl-border-t-1 gl-border-t-dropdown !gl-p-2 gl-border-t-solid">
          <gl-button
            data-testid="add-self-hosted-model-button"
            category="tertiary"
            block
            class="!gl-justify-start"
            :to="{ name: $options.INSTANCE_MODEL_SELECTION_ROUTE_NAMES.NEW }"
          >
            {{ s__('AdminAIPoweredFeatures|Add self-hosted model') }}
          </gl-button>
        </div>
      </template>
    </model-select-dropdown>
    <gl-icon
      v-if="sourceTooltip"
      v-gl-tooltip="{ title: sourceTooltip, placement: 'bottom' }"
      name="information-o"
      variant="info"
      tabindex="0"
      :aria-label="sourceTooltip"
      data-testid="model-source-info"
    />
  </div>
</template>
