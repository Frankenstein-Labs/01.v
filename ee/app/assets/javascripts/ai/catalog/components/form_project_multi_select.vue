<script>
import { s__, __ } from '~/locale';
import { ACCESS_LEVEL_MAINTAINER_STRING } from '~/access_level/constants';
import { DUO_LICENSED_FEATURE } from '../constants';
import getAiCatalogProjects from '../graphql/queries/ai_catalog_projects.query.graphql';
import getAvailableProjects from '../graphql/queries/ai_catalog_available_projects.query.graphql';
import MultiSelectCheckbox from './multi_select_checkbox.vue';

export default {
  name: 'FormProjectMultiSelect',
  components: {
    MultiSelectCheckbox,
  },
  props: {
    id: {
      type: String,
      required: false,
      default: null,
    },
    isValid: {
      type: Boolean,
      required: false,
      default: true,
    },
    itemId: {
      type: String,
      required: false,
      default: null,
    },
    projectLabelDescription: {
      type: String,
      required: true,
    },
    projectInvalidFeedback: {
      type: String,
      required: true,
    },
  },
  emits: ['error', 'input'],
  computed: {
    isFilteringEnabledProjects() {
      return Boolean(this.itemId);
    },
    query() {
      if (this.isFilteringEnabledProjects) return getAvailableProjects;
      return getAiCatalogProjects;
    },
    queryVariables() {
      const baseVariables = {
        minAccessLevel: ACCESS_LEVEL_MAINTAINER_STRING,
        sort: 'similarity',
        searchNamespaces: true,
        duoLicensedFeature: DUO_LICENSED_FEATURE,
      };
      if (this.isFilteringEnabledProjects) {
        return { ...baseVariables, itemId: this.itemId };
      }
      return baseVariables;
    },
  },
  methods: {
    itemAlreadyEnabledFn(item) {
      return Boolean(item?.aiCatalogItemConsumerForItem?.enabled);
    },
    itemTextFn(item) {
      return item?.nameWithNamespace;
    },
    itemLabelFn(item) {
      return item?.name;
    },
    itemSubLabelFn(item) {
      return item?.nameWithNamespace;
    },
    itemDisabledFn(item) {
      return this.itemAlreadyEnabledFn(item);
    },
    itemTrailingLabelFn(item) {
      return this.itemAlreadyEnabledFn(item) ? s__('AICatalog|Already enabled') : null;
    },
    onInput(items) {
      this.$emit(
        'input',
        items.map((item) => item.id),
      );
    },
    onError() {
      this.$emit('error', __('Failed to load projects'));
    },
  },
};
</script>

<template>
  <multi-select-checkbox
    :id="id"
    :is-valid="isValid"
    :query="query"
    :query-variables="queryVariables"
    data-key="projects"
    :placeholder-text="__('Search projects')"
    :item-text-fn="itemTextFn"
    :item-label-fn="itemLabelFn"
    :item-sub-label-fn="itemSubLabelFn"
    :item-disabled-fn="itemDisabledFn"
    :item-trailing-label-fn="itemTrailingLabelFn"
    :project-label-description="projectLabelDescription"
    :project-invalid-feedback="projectInvalidFeedback"
    @input="onInput"
    @error="onError"
  />
</template>
