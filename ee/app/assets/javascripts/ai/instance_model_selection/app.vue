<script>
import { GlTabs, GlTab, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import SelfHostedModelsTable from './self_hosted_models/components/self_hosted_models_table.vue';
import FeatureSettings from './feature_settings/components/feature_settings.vue';
import { INSTANCE_MODEL_SELECTION_TABS, INSTANCE_MODEL_SELECTION_ROUTE_NAMES } from './constants';

export default {
  name: 'InstanceModelSelectionRootApp',
  components: {
    GlTabs,
    GlTab,
    GlButton,
    SelfHostedModelsTable,
    FeatureSettings,
    PageHeading,
  },
  inject: ['canManageInstanceModelSelection', 'canManageSelfHostedModels', 'isDedicatedInstance'],
  props: {
    tabId: {
      type: String,
      required: false,
      default: INSTANCE_MODEL_SELECTION_TABS.AI_FEATURE_SETTINGS,
    },
  },
  INSTANCE_MODEL_SELECTION_ROUTE_NAMES,
  data() {
    return {
      currentTabIndex: 0,
    };
  },
  computed: {
    tabs() {
      return [
        {
          id: INSTANCE_MODEL_SELECTION_TABS.AI_FEATURE_SETTINGS,
          title: s__('AdminAIPoweredFeatures|AI-native features'),
          show: true,
        },
        {
          id: INSTANCE_MODEL_SELECTION_TABS.SELF_HOSTED_MODELS,
          title: s__('AdminSelfHostedModels|Self-hosted models'),
          show: this.canManageSelfHostedModels,
        },
      ];
    },
    canManageGitLabManagedModelsOnly() {
      return !this.canManageSelfHostedModels;
    },
    canManageGitLabManagedAndSelfHostedModels() {
      return (
        this.canManageSelfHostedModels &&
        (this.canManageInstanceModelSelection || this.isDedicatedInstance)
      );
    },
    description() {
      if (this.canManageGitLabManagedModelsOnly) {
        return s__(
          'AdminSelfHostedModels|Configure and assign GitLab managed models to AI-native features.',
        );
      }

      if (this.canManageGitLabManagedAndSelfHostedModels) {
        return s__(
          'AdminSelfHostedModels|Configure and assign self-hosted models or GitLab managed models to AI-native features.',
        );
      }

      // Can manage self-hosted models only
      return s__(
        'AdminSelfHostedModels|Manage GitLab Duo by configuring and assigning self-hosted models to AI-native features.',
      );
    },
    isSelfHostedModelsTab() {
      return this.tabId === INSTANCE_MODEL_SELECTION_TABS.SELF_HOSTED_MODELS;
    },
  },
  watch: {
    tabId: {
      handler(newTabId) {
        this.currentTabIndex = this.tabs.findIndex((tab) => tab.id === newTabId) || 0;
      },
      immediate: true,
    },
  },
  methods: {
    navigateToSelfHostedModelsTab() {
      this.$router.push({ name: INSTANCE_MODEL_SELECTION_ROUTE_NAMES.MODELS });
    },
    navigateToFeaturesTab() {
      this.$router.push({ name: INSTANCE_MODEL_SELECTION_ROUTE_NAMES.FEATURES });
    },
    onTabClick(tabId) {
      if (tabId === this.tabId) return;

      if (tabId === INSTANCE_MODEL_SELECTION_TABS.AI_FEATURE_SETTINGS) {
        this.navigateToFeaturesTab();
        return;
      }

      this.navigateToSelfHostedModelsTab();
    },
  },
};
</script>

<template>
  <div>
    <page-heading>
      <template #heading>
        <div data-testid="model-selection-heading">
          {{ s__('AdminSelfHostedModels|Model selection') }}
        </div>
      </template>
      <template #description>{{ description }}</template>
      <template #actions>
        <gl-button
          v-if="canManageSelfHostedModels"
          variant="confirm"
          :to="{ name: $options.INSTANCE_MODEL_SELECTION_ROUTE_NAMES.NEW }"
        >
          {{ s__('AdminSelfHostedModels|Add self-hosted model') }}
        </gl-button>
      </template>
    </page-heading>
    <div :class="{ 'top-area': isSelfHostedModelsTab }">
      <gl-tabs
        v-model="currentTabIndex"
        data-testid="self-hosted-duo-config-tabs"
        class="gl-flex gl-grow"
      >
        <div v-for="tab in tabs" :key="tab.id">
          <gl-tab v-if="tab.show" :data-testid="`${tab.id}-tab`" @click="onTabClick(tab.id)">
            <template #title>
              {{ tab.title }}
            </template>
          </gl-tab>
        </div>
      </gl-tabs>
    </div>
    <div v-if="canManageSelfHostedModels && isSelfHostedModelsTab">
      <self-hosted-models-table />
    </div>
    <div v-else>
      <feature-settings />
    </div>
  </div>
</template>
