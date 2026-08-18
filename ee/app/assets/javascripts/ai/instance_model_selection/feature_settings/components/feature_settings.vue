<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { sortBy } from 'lodash-es';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import FeatureSettingsBlock from 'ee/ai/shared/feature_settings/feature_settings_block.vue';
import { DUO_MAIN_FEATURES } from 'ee/ai/shared/feature_settings/constants';

import getSelfHostedModelsQuery from 'ee/ai/instance_model_selection/self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';
import { AGENTIC_CHAT_FEATURE } from '../constants';
import BetaFeaturesAlert from '../../shared/components/beta_features_alert.vue';
import FeatureSettingsTable from './feature_settings_table.vue';

export default {
  name: 'FeatureSettings',
  components: {
    FeatureSettingsTable,
    FeatureSettingsBlock,
    BetaFeaturesAlert,
    GlLink,
    GlSprintf,
  },
  inject: [
    'betaModelsEnabled',
    'canManageSelfHostedModels',
    'canManageDapSelfHostedModels',
    'modelSelectionAllowlistAvailable',
  ],
  codeSuggestionsHelpPage: helpPagePath('user/project/repository/code_suggestions/_index'),
  duoChatHelpPage: helpPagePath('user/gitlab_duo_chat/_index'),
  mergeRequestsHelpPage: helpPagePath('user/project/merge_requests/duo_in_merge_requests'),
  issuesHelpPage: helpPagePath('user/discussions/_index', {
    anchor: 'summarize-issue-discussions-with-gitlab-duo-chat',
  }),
  duoAgentPlatformHelpPage: helpPagePath('user/duo_agent_platform/_index'),
  duoAgenticChatHelpPage: helpPagePath('user/gitlab_duo_chat/agentic_chat'),
  otherGitLabDuoHelpPage: helpPagePath('user/get_started/getting_started_gitlab_duo', {
    anchor: 'step-3-try-other-gitlab-duo-features',
  }),
  data() {
    return {
      aiFeatureSettings: [],
      aiSelfHostedModels: [],
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.loading;
    },
    hasAnySelfHostedModels() {
      return this.aiSelfHostedModels.length > 0;
    },
    hasAnyGitlabManagedModels() {
      return this.aiFeatureSettings.some(
        (setting) =>
          setting.validGitlabModels?.nodes?.length > 0 || Boolean(setting.defaultGitlabModel),
      );
    },
    hasMixedSources() {
      return this.hasAnySelfHostedModels && this.hasAnyGitlabManagedModels;
    },
    sections() {
      const otherGitLabDuoFeatures = this.getSubFeatures(
        DUO_MAIN_FEATURES.OTHER_GITLAB_DUO_FEATURES,
      );
      const mergeRequestFeatures = this.getSubFeatures(DUO_MAIN_FEATURES.MERGE_REQUESTS);
      const issuesFeatures = this.getSubFeatures(DUO_MAIN_FEATURES.ISSUES);
      const duoAgentPlatformFeatures = this.modelSelectionAllowlistAvailable
        ? this.getSubFeatures(DUO_MAIN_FEATURES.AGENT_PLATFORM).filter(
            (f) => f.feature !== AGENTIC_CHAT_FEATURE,
          )
        : this.getSubFeatures(DUO_MAIN_FEATURES.AGENT_PLATFORM);
      const agenticChatFeature = this.getAgenticChatFeature();

      return [
        {
          id: 'duo-agent-platform',
          title: s__('AdminAIPoweredFeatures|GitLab Duo Agent Platform'),
          description: s__(
            'AdminAIPoweredFeatures|Multiple AI agents that work in parallel to help you create code, research results, and perform tasks simultaneously. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.duoAgentPlatformHelpPage,
          features: duoAgentPlatformFeatures,
          hasBetaFeatures: true,
          show: duoAgentPlatformFeatures.length && this.canManageDapSelfHostedModels,
          showAvailableModelsField: false,
        },
        {
          id: 'duo-agentic-chat',
          title: s__('AdminAIPoweredFeatures|GitLab Duo Agentic Chat'),
          description: s__(
            'AdminAIPoweredFeatures|An AI chat assistant that autonomously uses tools and performs multi-step tasks to answer complex questions. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.duoAgenticChatHelpPage,
          features: agenticChatFeature,
          hasBetaFeatures: false,
          show:
            this.modelSelectionAllowlistAvailable &&
            agenticChatFeature.length &&
            this.canManageDapSelfHostedModels,
          showAvailableModelsField: true,
        },
        {
          id: 'duo-chat',
          title: s__('AdminAIPoweredFeatures|GitLab Duo Chat'),
          description: s__(
            'AdminAIPoweredFeatures|An AI assistant that helps users accelerate software development using real-time conversational AI. This setting is for regular Duo Chat only. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.duoChatHelpPage,
          features: this.getSubFeatures(DUO_MAIN_FEATURES.DUO_CHAT),
          hasBetaFeatures: true,
          show: true,
          showAvailableModelsField: false,
        },
        {
          id: 'code-suggestions',
          title: s__('AdminAIPoweredFeatures|Code Suggestions'),
          description: s__(
            'AdminAIPoweredFeatures|Assists developers by generating and completing code in real-time. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.codeSuggestionsHelpPage,
          features: this.getSubFeatures(DUO_MAIN_FEATURES.CODE_SUGGESTIONS),
          hasBetaFeatures: false,
          show: true,
          showAvailableModelsField: false,
        },
        {
          id: 'duo-merge-requests',
          title: s__('AdminAIPoweredFeatures|GitLab Duo for merge requests'),
          description: s__(
            'AdminAIPoweredFeatures|AI-native features that help users accomplish tasks during the lifecycle of a merge request. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.mergeRequestsHelpPage,
          features: mergeRequestFeatures,
          hasBetaFeatures: false,
          show: mergeRequestFeatures.length,
          showAvailableModelsField: false,
        },
        {
          id: 'duo-issues',
          title: s__('AdminAIPoweredFeatures|GitLab Duo for issues'),
          description: s__(
            'AdminAIPoweredFeatures|An AI-native feature that generates a summary of discussions on an issue. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.issuesHelpPage,
          features: issuesFeatures,
          hasBetaFeatures: false,
          show: issuesFeatures.length,
          showAvailableModelsField: false,
        },
        {
          id: 'other-duo-features',
          title: s__('AdminAIPoweredFeatures|Other GitLab Duo features'),
          description: s__(
            'AdminAIPoweredFeatures|AI-native features that support users outside of Chat or Code Suggestions. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.otherGitLabDuoHelpPage,
          features: otherGitLabDuoFeatures,
          hasBetaFeatures: true,
          show: otherGitLabDuoFeatures.length,
          showAvailableModelsField: false,
        },
      ];
    },
  },
  apollo: {
    aiFeatureSettings: {
      query: getAiFeatureSettingsQuery,
      update(data) {
        return data.aiFeatureSettings?.nodes || [];
      },
      error(error) {
        createAlert({
          message: s__(
            'AdminAIPoweredFeatures|An error occurred while loading the AI feature settings. Please try again.',
          ),
          error,
          captureError: true,
        });
      },
    },
    aiSelfHostedModels: {
      query: getSelfHostedModelsQuery,
      update(data) {
        return data.aiSelfHostedModels?.nodes || [];
      },
      error() {
        // Failure here only affects whether the "GitLab managed model / Self-hosted model"
        // subtext is shown within model dropdown; the page still works without it.
      },
    },
  },
  methods: {
    getSubFeatures(mainFeature) {
      const displayOrder = {
        GA: 1,
        BETA: 2,
        EXPERIMENT: 3,
      };

      const subFeatures = this.aiFeatureSettings.filter(
        (setting) => setting.mainFeature === mainFeature,
      );
      // sort rows by releaseState
      return sortBy(subFeatures, (subFeature) => displayOrder[subFeature.releaseState]);
    },
    getAgenticChatFeature() {
      return this.aiFeatureSettings.filter((setting) => setting.feature === AGENTIC_CHAT_FEATURE);
    },
    shouldShowBetaAlert(section) {
      return section.hasBetaFeatures && !this.betaModelsEnabled && this.canManageSelfHostedModels;
    },
  },
};
</script>
<template>
  <div>
    <div v-for="section in sections" :key="section.id">
      <feature-settings-block v-if="section.show" :id="section.id" :title="section.title">
        <template #description>
          <gl-sprintf :message="section.description">
            <template #link="{ content }">
              <gl-link :href="section.link" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </template>
        <template #content>
          <div>
            <beta-features-alert
              v-if="shouldShowBetaAlert(section)"
              :message="
                s__(
                  'AdminSelfHostedModels|More features are available in beta. You can %{linkStart}turn on AI-native beta features%{linkEnd}.',
                )
              "
            />
            <feature-settings-table
              :data-testid="`${section.id}-table`"
              :feature-settings="section.features"
              :is-loading="isLoading"
              :has-mixed-sources="hasMixedSources"
              :show-available-models-field="section.showAvailableModelsField"
            />
          </div>
        </template>
      </feature-settings-block>
    </div>
  </div>
</template>
