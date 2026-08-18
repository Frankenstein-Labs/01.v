<script>
import {
  GlTable,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlExperimentBadge,
  GlIcon,
  GlLink,
  GlSearchBoxByType,
  GlSkeletonLoader,
  GlSprintf,
  GlTruncate,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { __, s__ } from '~/locale';
import getSelfHostedModelsQuery from '../graphql/queries/get_self_hosted_models.query.graphql';
import { BEDROCK_DUMMY_ENDPOINT, VERTEX_DUMMY_ENDPOINT } from '../constants';
import { RELEASE_STATES, INSTANCE_MODEL_SELECTION_ROUTE_NAMES } from '../../constants';
import DeleteSelfHostedModelDisclosureItem from './delete_self_hosted_model_disclosure_item.vue';

export default {
  name: 'SelfHostedModelsTable',
  components: {
    GlTable,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlExperimentBadge,
    GlIcon,
    GlLink,
    GlSearchBoxByType,
    GlSkeletonLoader,
    GlSprintf,
    GlTruncate,
    DeleteSelfHostedModelDisclosureItem,
  },
  inject: ['canManageSelfHostedModels'],
  INSTANCE_MODEL_SELECTION_ROUTE_NAMES,
  data() {
    return {
      searchTerm: '',
      selfHostedModels: [],
    };
  },
  i18n: {
    emptyStateText: s__(
      'AdminSelfHostedModels|No self-hosted models yet. %{newModelLinkStart}Add a self-hosted model%{newModelLinkEnd} and select it for a feature to start using it.',
    ),
    emptyStateTextWithoutLink: s__(
      'AdminSelfHostedModels|Self-hosted models are available only with the GitLab Duo Enterprise add-on. Contact your administrator.',
    ),
    errorMessage: s__(
      'AdminSelfHostedModels|An error occurred while loading self-hosted models. Please try again.',
    ),
  },
  fields: [
    {
      key: 'name',
      label: s__('AdminSelfHostedModels|Name'),
      thClass: 'gl-w-4/20',
      tdClass: 'gl-content-center',
    },
    {
      key: 'model',
      label: s__('AdminSelfHostedModels|Model family'),
      thClass: 'gl-w-4/20',
      tdClass: 'gl-content-center',
    },
    {
      key: 'endpoint',
      label: s__('AdminSelfHostedModels|Endpoint'),
      thClass: 'gl-w-4/20',
      tdClass: 'gl-content-center',
    },
    {
      key: 'identifier',
      label: s__('AdminSelfHostedModels|Model identifier'),
      thClass: 'gl-w-3/20',
      tdClass: 'gl-content-center',
    },
    {
      key: 'has_api_key',
      label: s__('AdminSelfHostedModels|API token'),
      thClass: 'gl-w-2/20',
      tdClass: 'gl-content-center',
    },
    {
      key: 'actions',
      label: __('Actions'),
      thClass: 'gl-w-2/20 @md/panel:gl-invisible',
      tdClass: 'gl-content-center gl-text-right',
    },
  ],
  computed: {
    loaderItems() {
      return [
        {
          loaderWidth: {
            name: '275',
            model: '100',
            endpoint: '300',
            identifier: '125',
          },
        },
        {
          loaderWidth: {
            name: '225',
            model: '175',
            endpoint: '225',
            identifier: '175',
          },
        },
        {
          loaderWidth: {
            name: '300',
            model: '150',
            endpoint: '300',
            identifier: '150',
          },
        },
      ];
    },
    isLoading() {
      return this.$apollo.loading;
    },
  },
  methods: {
    editModelItem(model) {
      const modelId = getIdFromGraphQLId(model.id);

      return {
        text: __('Edit'),
        to: { name: INSTANCE_MODEL_SELECTION_ROUTE_NAMES.EDIT, params: { id: modelId } },
      };
    },
    getModelEndpointText(endpoint) {
      return [BEDROCK_DUMMY_ENDPOINT, VERTEX_DUMMY_ENDPOINT].includes(endpoint) ? '--' : endpoint;
    },
    isBetaModel(model) {
      return model.releaseState === RELEASE_STATES.BETA;
    },
  },
  apollo: {
    selfHostedModels: {
      query: getSelfHostedModelsQuery,
      update(data) {
        return data.aiSelfHostedModels?.nodes || [];
      },
      error(error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          error,
          captureError: true,
        });
      },
    },
  },
};
</script>
<template>
  <div>
    <div class="gl-py-4">
      <gl-search-box-by-type v-model.trim="searchTerm" />
    </div>
    <gl-table
      :fields="$options.fields"
      :items="isLoading ? loaderItems : selfHostedModels"
      stacked="md"
      :hover="true"
      :filter="searchTerm"
      :selectable="false"
      show-empty
      fixed
    >
      <template #empty>
        <p class="gl-m-0 gl-py-4">
          <gl-sprintf v-if="canManageSelfHostedModels" :message="$options.i18n.emptyStateText">
            <template #newModelLink="{ content }">
              <gl-link :to="{ name: $options.INSTANCE_MODEL_SELECTION_ROUTE_NAMES.NEW }">{{
                content
              }}</gl-link>
            </template>
          </gl-sprintf>
          <span v-else>{{ $options.i18n.emptyStateTextWithoutLink }}</span>
        </p>
      </template>
      <template #cell(name)="{ item }">
        <gl-skeleton-loader v-if="isLoading" :height="42" :width="400"
          ><rect y="6" :width="item.loaderWidth.name" height="36" rx="10" />
        </gl-skeleton-loader>
        <span v-else><gl-truncate :text="item.name" position="end" with-tooltip /></span>
      </template>
      <template #cell(model)="{ item }">
        <gl-skeleton-loader v-if="isLoading" :height="42" :width="400"
          ><rect y="6" :width="item.loaderWidth.model" height="36" rx="10" />
        </gl-skeleton-loader>
        <div v-else>
          {{ item.modelDisplayName }}
          <gl-experiment-badge v-if="isBetaModel(item)" type="beta" />
        </div>
      </template>
      <template #cell(endpoint)="{ item }">
        <gl-skeleton-loader v-if="isLoading" :height="42" :width="400"
          ><rect y="6" :width="item.loaderWidth.endpoint" height="36" rx="10" />
        </gl-skeleton-loader>
        <span v-else
          ><gl-truncate :text="getModelEndpointText(item.endpoint)" position="end" with-tooltip
        /></span>
      </template>
      <template #cell(identifier)="{ item }">
        <gl-skeleton-loader v-if="isLoading" :height="42" :width="300"
          ><rect y="4" :width="item.loaderWidth.identifier" height="36" rx="10" />
        </gl-skeleton-loader>
        <span v-else>
          <gl-truncate :text="item.identifier" position="end" with-tooltip />
        </span>
      </template>
      <template #cell(has_api_key)="{ item }">
        <gl-skeleton-loader v-if="isLoading" :height="42" :width="200">
          <circle cx="20" cy="20" r="20" />
        </gl-skeleton-loader>
        <span v-else>
          <gl-icon
            v-if="item.hasApiToken"
            :aria-label="s__('AdminSelfHostedModels|Model uses an API token')"
            name="check-circle"
          />
        </span>
      </template>
      <template #cell(actions)="{ item }">
        <gl-disclosure-dropdown
          v-if="!isLoading && canManageSelfHostedModels"
          class="gl-py-2"
          category="tertiary"
          size="small"
          icon="ellipsis_v"
          :no-caret="true"
        >
          <gl-disclosure-dropdown-item
            data-testid="model-edit-button"
            :item="editModelItem(item)"
          />
          <delete-self-hosted-model-disclosure-item :model="item" />
        </gl-disclosure-dropdown>
      </template>
    </gl-table>
  </div>
</template>
