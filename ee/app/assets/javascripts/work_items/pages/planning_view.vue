<script>
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { NAMESPACE_GROUP, NAMESPACE_PROJECT } from '~/issues/constants';
import {
  TOKEN_TYPE_CUSTOM_FIELD,
  OPERATORS_IS,
  TOKEN_TYPE_STATUS,
  TOKEN_TITLE_STATUS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  TOKEN_TITLE_WEIGHT,
  TOKEN_TYPE_WEIGHT,
  TOKEN_TYPE_HEALTH,
  TOKEN_TITLE_HEALTH,
  TOKEN_TYPE_ITERATION,
  TOKEN_TITLE_ITERATION,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import {
  CUSTOM_FIELDS_TYPE_MULTI_SELECT,
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
  WORK_ITEM_TYPE_NAME_TICKET,
  WORK_ITEM_TYPE_NAME_EPIC,
} from '~/work_items/constants';

import PlanningView from '~/work_items/pages/planning_view.vue';

import namespaceCustomFieldsQuery from 'ee/vue_shared/components/filtered_search_bar/queries/custom_field_names.query.graphql';
import searchIterationsQuery from 'ee/work_items/list/graphql/search_iterations.query.graphql';

const CustomFieldToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/custom_field_token.vue');
const WeightToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/weight_token.vue');
const WorkItemStatusToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/work_item_status_token.vue');
const HealthToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/health_token.vue');
const IterationToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/iteration_token.vue');

export default {
  name: 'PlanningViewEE',
  components: {
    PlanningView,
  },
  inject: [
    'isGroup',
    'workItemType',
    'hasCustomFieldsFeature',
    'hasIssueWeightsFeature',
    'hasIssuableHealthStatusFeature',
    'hasStatusFeature',
    'hasIterationsFeature',
    'workItemTypesConfiguration',
  ],
  props: {
    rootPageFullPath: {
      type: String,
      required: true,
    },
    withTabs: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  data() {
    return {
      customFields: [],
    };
  },
  apollo: {
    customFields: {
      query: namespaceCustomFieldsQuery,
      variables() {
        return {
          fullPath: this.rootPageFullPath,
          active: true,
        };
      },
      skip() {
        return !this.hasCustomFieldsFeature;
      },
      update(data) {
        const listTypeIds = (this.workItemTypesConfiguration || [])
          .filter((type) => type.isFilterableListView)
          .map((type) => type.id);

        return (data.namespace?.customFields?.nodes || []).filter((field) => {
          const fieldTypeAllowed = [
            CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            CUSTOM_FIELDS_TYPE_MULTI_SELECT,
          ].includes(field.fieldType);

          const fieldAllowedOnWorkItem = field.workItemTypes.some((type) =>
            listTypeIds.includes(type.id),
          );

          return fieldTypeAllowed && fieldAllowedOnWorkItem;
        });
      },
      error(error) {
        createAlert({
          message: s__('WorkItem|Failed to load custom fields.'),
          captureError: true,
          error,
        });
      },
    },
  },
  computed: {
    namespace() {
      return !this.isGroup ? NAMESPACE_PROJECT : NAMESPACE_GROUP;
    },
    isServiceDeskList() {
      return this.workItemType === WORK_ITEM_TYPE_NAME_TICKET;
    },
    isEpicsList() {
      return this.workItemType === WORK_ITEM_TYPE_NAME_EPIC;
    },
    showCustomStatusFeature() {
      return this.hasStatusFeature && !this.isEpicsList && !this.isServiceDeskList;
    },
    searchTokens() {
      const tokens = [];

      if (this.customFields.length > 0) {
        this.customFields.forEach((field, index) => {
          tokens.push({
            order: 30 + index, // buffer to put all custom fields at end of list
            type: `${TOKEN_TYPE_CUSTOM_FIELD}[${getIdFromGraphQLId(field.id)}]`,
            title: field.name,
            icon: 'multiple-choice',
            field,
            fullPath: this.rootPageFullPath,
            token: CustomFieldToken,
            operators: OPERATORS_IS,
            unique: field.fieldType !== CUSTOM_FIELDS_TYPE_MULTI_SELECT,
          });
        });
      }

      if (!this.isEpicsList) {
        if (this.hasIssueWeightsFeature) {
          tokens.push({
            order: 10,
            type: TOKEN_TYPE_WEIGHT,
            title: TOKEN_TITLE_WEIGHT,
            icon: 'weight',
            token: WeightToken,
            unique: true,
          });
        }

        if (this.hasIterationsFeature) {
          tokens.push({
            order: 8,
            type: TOKEN_TYPE_ITERATION,
            title: TOKEN_TITLE_ITERATION,
            icon: 'iteration',
            token: IterationToken,
            fetchIterations: this.fetchIterations,
            recentSuggestionsStorageKey: `${this.rootPageFullPath}-work-items-recent-tokens-iteration`,
            fullPath: this.rootPageFullPath,
            isProject: !this.isGroup,
          });
        }
      }

      if (this.showCustomStatusFeature) {
        tokens.push({
          order: 6,
          type: TOKEN_TYPE_STATUS,
          title: TOKEN_TITLE_STATUS,
          icon: 'status',
          token: WorkItemStatusToken,
          fullPath: this.rootPageFullPath,
          unique: true,
          operators: OPERATORS_IS,
        });
      }

      if (this.hasIssuableHealthStatusFeature) {
        tokens.push({
          order: 13,
          type: TOKEN_TYPE_HEALTH,
          title: TOKEN_TITLE_HEALTH,
          icon: 'status-health',
          token: HealthToken,
          unique: true,
        });
      }

      return tokens;
    },
  },
  methods: {
    async fetchIterations(search) {
      const id = Number(search);
      const variables =
        !search || Number.isNaN(id)
          ? { fullPath: this.rootPageFullPath, search, isProject: !this.isGroup }
          : { fullPath: this.rootPageFullPath, id, isProject: !this.isGroup };

      variables.state = 'all';

      return this.$apollo
        .query({
          query: searchIterationsQuery,
          variables,
        })
        .then(({ data }) => data[this.namespace]?.iterations.nodes)
        .catch(() => {});
    },
  },
};
</script>

<template>
  <planning-view
    :root-page-full-path="rootPageFullPath"
    :with-tabs="withTabs"
    :ee-search-tokens="searchTokens"
  />
</template>
