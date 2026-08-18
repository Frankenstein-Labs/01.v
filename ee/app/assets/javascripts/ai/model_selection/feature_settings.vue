<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import FeatureSettingsBlock from 'ee/ai/shared/feature_settings/feature_settings_block.vue';
import { DUO_MAIN_FEATURES } from 'ee/ai/shared/feature_settings/constants';

import { AGENTIC_CHAT_FEATURE } from './constants';
import ModelSelectionFeatureSettingsTable from './feature_settings_table.vue';

export default {
  name: 'FeatureSettings',
  components: {
    ModelSelectionFeatureSettingsTable,
    FeatureSettingsBlock,
    GlLink,
    GlSprintf,
  },
  inject: {
    modelSelectionAllowlistAvailable: {
      default: false,
    },
  },
  props: {
    featureSettings: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
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
  computed: {
    sections() {
      const agenticChatFeatures = this.getAgenticChatFeature();
      const duoAgentPlatformFeatures = this.modelSelectionAllowlistAvailable
        ? this.getSubFeatures(DUO_MAIN_FEATURES.AGENT_PLATFORM).filter(
            (feature) => feature.feature !== AGENTIC_CHAT_FEATURE,
          )
        : this.getSubFeatures(DUO_MAIN_FEATURES.AGENT_PLATFORM);

      return [
        {
          id: 'duo-agent-platform',
          title: s__('AdminAIPoweredFeatures|GitLab Duo Agent Platform'),
          description: s__(
            'AdminAIPoweredFeatures|Multiple AI agents that work in parallel to help you create code, research results, and perform tasks simultaneously. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.duoAgentPlatformHelpPage,
          features: duoAgentPlatformFeatures,
          show: duoAgentPlatformFeatures.length,
          showAvailableModelsField: false,
        },
        {
          id: 'duo-agentic-chat',
          title: s__('AdminAIPoweredFeatures|GitLab Duo Agentic Chat'),
          description: s__(
            'AdminAIPoweredFeatures|An AI chat assistant that autonomously uses tools and performs multi-step tasks to answer complex questions. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.duoAgenticChatHelpPage,
          features: agenticChatFeatures,
          show: this.modelSelectionAllowlistAvailable && agenticChatFeatures.length,
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
          features: this.getSubFeatures(DUO_MAIN_FEATURES.MERGE_REQUESTS),
          show: true,
          showAvailableModelsField: false,
        },
        {
          id: 'duo-issues',
          title: s__('AdminAIPoweredFeatures|GitLab Duo for issues'),
          description: s__(
            'AdminAIPoweredFeatures|An AI-native feature that generates a summary of discussions on an issue. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.issuesHelpPage,
          features: this.getSubFeatures(DUO_MAIN_FEATURES.ISSUES),
          show: true,
          showAvailableModelsField: false,
        },
        {
          id: 'other-duo-features',
          title: s__('AdminAIPoweredFeatures|Other GitLab Duo features'),
          description: s__(
            'AdminAIPoweredFeatures|AI-native features that support users outside of Chat or Code Suggestions. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.otherGitLabDuoHelpPage,
          features: this.getSubFeatures(DUO_MAIN_FEATURES.OTHER_GITLAB_DUO_FEATURES),
          show: true,
          showAvailableModelsField: false,
        },
      ];
    },
  },
  methods: {
    getSubFeatures(mainFeature) {
      return this.featureSettings.filter((setting) => setting.mainFeature === mainFeature);
    },
    getAgenticChatFeature() {
      return this.featureSettings.filter((setting) => setting.feature === AGENTIC_CHAT_FEATURE);
    },
  },
};
</script>
<template>
  <div>
    <template v-for="section in sections">
      <feature-settings-block
        v-if="section.show"
        :id="section.id"
        :key="section.id"
        :title="section.title"
      >
        <template #description>
          <gl-sprintf :message="section.description">
            <template #link="{ content }">
              <gl-link :href="section.link" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </template>
        <template #content>
          <model-selection-feature-settings-table
            :data-testid="`${section.id}-table`"
            :feature-settings="section.features"
            :is-loading="isLoading"
            :show-available-models-field="section.showAvailableModelsField"
          />
        </template>
      </feature-settings-block>
    </template>
  </div>
</template>
