<script>
import { s__ } from '~/locale';
import BaseFeatureSettingsTable from 'ee/ai/shared/feature_settings/base_feature_settings_table.vue';
import AvailableModelsRow from 'ee/ai/shared/feature_settings/available_models_row.vue';
import {
  FEATURE_SETTINGS_FIXED_LOADER_WIDTH,
  FEATURE_SETTINGS_VARIABLE_LOADER_WIDTHS,
} from 'ee/ai/shared/feature_settings/constants';

import ModelAllowListSelector from './model_allow_list_selector.vue';
import ModelSelector from './model_selector.vue';
import ModelSelectionBatchSettingsUpdater from './batch_settings_updater.vue';

const SUB_FEATURE_FIELD = {
  key: 'sub_feature',
  label: s__('AdminAIPoweredFeatures|Feature'),
  thClass: 'gl-w-1/3',
  loaderWidths: FEATURE_SETTINGS_VARIABLE_LOADER_WIDTHS,
};

const MODEL_FIELD = {
  key: 'model_name',
  label: s__('AdminAIPoweredFeatures|Model'),
  thClass: 'gl-w-1/3',
  loaderWidths: [FEATURE_SETTINGS_FIXED_LOADER_WIDTH],
};

const DEFAULT_MODEL_FIELD = {
  ...MODEL_FIELD,
  label: s__('AdminAIPoweredFeatures|Default model'),
};

const BATCH_MODEL_UPDATE_FIELD = {
  key: 'batch_model_update',
  label: s__('AdminAIPoweredFeatures|Apply to all sub-features'),
  thClass: 'gl-sr-only gl-w-1/3',
};

const AVAILABLE_MODELS_FIELD = {
  key: 'available_models',
  label: s__('AdminAIPoweredFeatures|Available models'),
  thClass: 'gl-w-1/3',
};

export default {
  name: 'ModelSelectionFeatureSettingsTable',
  components: {
    AvailableModelsRow,
    BaseFeatureSettingsTable,
    ModelAllowListSelector,
    ModelSelector,
    ModelSelectionBatchSettingsUpdater,
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
    showAvailableModelsField: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      batchUpdateIsSaving: false,
      savingFeatures: {},
      activeFeature: null,
      isAllowlistModalVisible: false,
    };
  },
  computed: {
    tableFields() {
      return this.showAvailableModelsField
        ? [SUB_FEATURE_FIELD, DEFAULT_MODEL_FIELD, AVAILABLE_MODELS_FIELD]
        : [SUB_FEATURE_FIELD, MODEL_FIELD, BATCH_MODEL_UPDATE_FIELD];
    },
    activeFeatureSetting() {
      return this.featureSettings.find((s) => s.feature === this.activeFeature) ?? null;
    },
  },
  methods: {
    updateBatchSavingState(state) {
      this.batchUpdateIsSaving = state;
    },
    isConfigureButtonDisabled(item) {
      return this.savingFeatures[item.feature] || !item.allowList;
    },
    showModal(item) {
      if (this.savingFeatures[item.feature]) return;
      this.activeFeature = item.feature;
      this.isAllowlistModalVisible = true;
    },
    onSave(feature, isSaving) {
      this.savingFeatures = { ...this.savingFeatures, [feature]: isSaving };
    },
  },
};
</script>
<template>
  <div>
    <base-feature-settings-table
      :items="featureSettings"
      :is-loading="isLoading"
      :fields="tableFields"
    >
      <template #cell(sub_feature)="{ item }">
        {{ item.title }}
      </template>
      <template #cell(model_name)="{ item }">
        <model-selector
          :ai-feature-setting="item"
          :batch-update-is-saving="batchUpdateIsSaving"
          @update:is-saving="(value) => onSave(item.feature, value)"
        />
      </template>
      <template #cell(available_models)="{ item }">
        <available-models-row
          :disabled="isConfigureButtonDisabled(item)"
          :is-loading="savingFeatures[item.feature]"
          :allow-list="item.allowList"
          @click="showModal(item)"
        />
      </template>
      <template #cell(batch_model_update)="{ item }">
        <model-selection-batch-settings-updater
          v-if="!isLoading && featureSettings.length > 1"
          class="gl-float-right"
          :ai-feature-settings="featureSettings"
          :selected-feature-setting="item"
          @update-batch-saving-state="updateBatchSavingState"
        />
      </template>
    </base-feature-settings-table>
    <model-allow-list-selector
      v-if="showAvailableModelsField"
      :ai-feature-setting="activeFeatureSetting"
      :visible="isAllowlistModalVisible"
      @update:visible="isAllowlistModalVisible = $event"
    />
  </div>
</template>
