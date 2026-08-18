<script>
import { GlFilteredSearchSuggestion, GlIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { s__, sprintf } from '~/locale';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import { TOKEN_TITLE_STATUS } from '~/vue_shared/components/filtered_search_bar/constants';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import getAllStatusesQuery from 'ee/issues/dashboard/queries/get_all_statuses.query.graphql';
import { getStatuses, sortStatuses } from 'ee/work_items/utils';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  name: 'WorkItemStatusToken',
  components: {
    BaseToken,
    GlFilteredSearchSuggestion,
    GlIcon,
  },
  mixins: [glListenersMixin],
  props: {
    active: {
      type: Boolean,
      required: true,
    },
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      options: [],
      loading: true,
    };
  },
  computed: {},
  methods: {
    getActiveOption(options, data) {
      return options.find((option) => option.name === data);
    },
    fetchAllStatuses(search) {
      return this.$apollo
        .query({
          query: getAllStatusesQuery,
          variables: {
            name: search,
          },
        })
        .then(({ data }) => sortStatuses(data.workItemAllowedStatuses.nodes));
    },
    fetchStatusesForNamespace() {
      return this.$apollo
        .query({
          query: namespaceWorkItemTypesQuery,
          variables: {
            fullPath: this.config.fullPath,
          },
        })
        .then(({ data }) => getStatuses(data?.namespace?.workItemTypes?.nodes));
    },
    fetchStatuses(search) {
      this.loading = true;

      const query = this.config.fetchAllStatuses
        ? this.fetchAllStatuses
        : this.fetchStatusesForNamespace;

      query(search)
        .then((statuses) => {
          this.options = statuses.map((status) => ({
            ...status,
            value: getIdFromGraphQLId(status.id),
          }));
        })
        .catch((error) => {
          const message = sprintf(
            s__(
              'WorkItemStatus|Options could not be loaded for field: %{dropdownLabel}. Please try again.',
            ),
            {
              dropdownLabel: TOKEN_TITLE_STATUS,
            },
          );

          createAlert({
            message,
            captureError: true,
            error,
          });
        })
        .finally(() => {
          this.loading = false;
        });
    },
    getOptionText(option) {
      return option.name;
    },
  },
};
</script>

<template>
  <base-token
    :active="active"
    :config="config"
    :value="value"
    :suggestions="options"
    :suggestions-loading="loading"
    :get-active-token-value="getActiveOption"
    :value-identifier="getOptionText"
    @fetch-suggestions="fetchStatuses"
    v-on="glListeners()"
  >
    <template #view="{ viewTokenProps: { inputValue, activeTokenValue } }">
      <div class="gl-truncate">
        <template v-if="activeTokenValue">
          <gl-icon
            :name="activeTokenValue.iconName"
            :size="12"
            class="gl-mb-[-1px] gl-mr-1 gl-mt-1"
            :style="{ color: activeTokenValue.color }"
          />
          <span>{{ activeTokenValue.name }}</span>
        </template>
        <template v-else>
          {{ inputValue }}
        </template>
      </div>
    </template>
    <template #suggestions-list="{ suggestions }">
      <gl-filtered-search-suggestion
        v-for="option in suggestions"
        :key="option.id"
        :value="option.name"
      >
        <gl-icon
          :name="option.iconName"
          :size="12"
          class="gl-mr-2"
          :style="{ color: option.color }"
        />
        <span>{{ getOptionText(option) }}</span>
      </gl-filtered-search-suggestion>
    </template>
  </base-token>
</template>
