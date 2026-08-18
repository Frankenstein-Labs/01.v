<script>
import { orderBy } from 'lodash-es';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import IssueBoardFilteredSearchFoss from '~/boards/components/issue_board_filtered_search.vue';
import {
  OPERATORS_IS,
  TOKEN_TYPE_EPIC,
  TOKEN_TYPE_HEALTH,
  TOKEN_TYPE_ITERATION,
  TOKEN_TYPE_WEIGHT,
  TOKEN_TYPE_STATUS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import { TYPENAME_ISSUE, TYPENAME_TASK } from '~/graphql_shared/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  CUSTOM_FIELDS_TYPE_MULTI_SELECT,
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
} from '~/work_items/constants';
import {
  TOKEN_TYPE_CUSTOM_FIELD,
  TOKEN_TITLE_EPIC,
  TOKEN_TITLE_HEALTH,
  TOKEN_TITLE_ITERATION,
  TOKEN_TITLE_WEIGHT,
  TOKEN_TITLE_STATUS,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import namespaceCustomFieldsQuery from 'ee/vue_shared/components/filtered_search_bar/queries/custom_field_names.query.graphql';
import EpicToken from 'ee/vue_shared/components/filtered_search_bar/tokens/epic_token.vue';
import HealthToken from 'ee/vue_shared/components/filtered_search_bar/tokens/health_token.vue';
import IterationToken from 'ee/vue_shared/components/filtered_search_bar/tokens/iteration_token.vue';
import WeightToken from 'ee/vue_shared/components/filtered_search_bar/tokens/weight_token.vue';
import CustomFieldToken from 'ee/vue_shared/components/filtered_search_bar/tokens/custom_field_token.vue';
import WorkItemStatusToken from 'ee/vue_shared/components/filtered_search_bar/tokens/work_item_status_token.vue';
import issueBoardFilters from '../issue_board_filters';

// This is a false violation of @gitlab/no-runtime-template-compiler, since it
// extends a valid Vue single file component.
// eslint-disable-next-line @gitlab/no-runtime-template-compiler
export default {
  name: 'IssueBoardFilteredSearch',
  extends: IssueBoardFilteredSearchFoss,
  i18n: {
    ...IssueBoardFilteredSearchFoss.i18n,
  },
  mixins: [glFeatureFlagMixin()],
  inject: [
    'epicFeatureAvailable',
    'iterationFeatureAvailable',
    'hasCustomFieldsFeature',
    'healthStatusFeatureAvailable',
    'isGroupBoard',
    'statusListsAvailable',
    'hasStatusFeature',
  ],
  data() {
    return {
      customFields: [],
    };
  },
  apollo: {
    customFields: {
      query: namespaceCustomFieldsQuery,
      skip() {
        return !this.hasCustomFieldsFeature || !this.fullPath;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          active: true,
        };
      },
      update(data) {
        return (data.namespace?.customFields?.nodes || []).filter((field) => {
          const fieldTypeAllowed = [
            CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            CUSTOM_FIELDS_TYPE_MULTI_SELECT,
          ].includes(field.fieldType);
          const fieldAllowedOnWorkItem = field.workItemTypes.some(
            (type) =>
              type.name === TYPENAME_ISSUE ||
              (this.glFeatures.workItemTasksOnBoards && type.name === TYPENAME_TASK),
          );

          return fieldTypeAllowed && fieldAllowedOnWorkItem;
        });
      },
      error(error) {
        createAlert({
          message: s__('WorkItemCustomFields|Failed to load custom fields.'),
          captureError: true,
          error,
        });
      },
    },
  },
  computed: {
    epicsGroupPath() {
      return this.isGroupBoard
        ? this.fullPath
        : this.fullPath.slice(0, this.fullPath.lastIndexOf('/'));
    },
    showCustomStatusFilter() {
      return this.statusListsAvailable && this.hasStatusFeature;
    },
    // eslint-disable-next-line vue/no-unused-properties -- This component inherits from `IssueBoardFilteredSearchFoss` which calls `tokens()` internally
    tokens() {
      const { fetchIterations } = issueBoardFilters(this.$apollo, this.fullPath, this.isGroupBoard);

      const tokens = [
        ...this.tokensCE,
        ...(this.epicFeatureAvailable
          ? [
              {
                type: TOKEN_TYPE_EPIC,
                title: TOKEN_TITLE_EPIC,
                icon: 'epic',
                token: EpicToken,
                unique: true,
                symbol: '&',
                idProperty: 'id',
                useIdValue: true,
                fullPath: this.epicsGroupPath,
              },
            ]
          : []),
        ...(this.iterationFeatureAvailable
          ? [
              {
                icon: 'iteration',
                title: TOKEN_TITLE_ITERATION,
                type: TOKEN_TYPE_ITERATION,
                token: IterationToken,
                unique: true,
                fetchIterations,
                isProject: !this.isGroupBoard,
                fullPath: this.fullPath,
              },
            ]
          : []),
        {
          type: TOKEN_TYPE_WEIGHT,
          title: TOKEN_TITLE_WEIGHT,
          icon: 'weight',
          token: WeightToken,
          unique: true,
        },
        ...(this.healthStatusFeatureAvailable
          ? [
              {
                type: TOKEN_TYPE_HEALTH,
                title: TOKEN_TITLE_HEALTH,
                icon: 'status-health',
                token: HealthToken,
                unique: false,
              },
            ]
          : []),
        ...(this.hasCustomFieldsFeature
          ? this.customFields.map((field) => {
              return {
                type: `${TOKEN_TYPE_CUSTOM_FIELD}[${getIdFromGraphQLId(field?.id)}]`,
                title: field?.name,
                icon: 'multiple-choice',
                field,
                fullPath: this.fullPath,
                token: CustomFieldToken,
                operators: OPERATORS_IS,
                unique: true,
              };
            })
          : []),

        ...(this.showCustomStatusFilter
          ? [
              {
                type: TOKEN_TYPE_STATUS,
                title: TOKEN_TITLE_STATUS,
                icon: 'status',
                token: WorkItemStatusToken,
                fullPath: this.fullPath,
                unique: true,
                operators: OPERATORS_IS,
              },
            ]
          : []),
      ];

      return orderBy(tokens, ['title']);
    },
  },
};
</script>
