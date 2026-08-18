<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __ } from '~/locale';
import { DEFAULT_PER_PAGE } from '~/api';
import { fetchPolicies } from '~/lib/graphql';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import getAddOnEligibleUsers from 'ee/usage_quotas/add_on/graphql/self_managed_add_on_eligible_users.query.graphql';
import {
  ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE,
  ADD_ON_ERROR_DICTIONARY,
} from 'ee/usage_quotas/error_constants';
import ErrorAlert from 'ee/vue_shared/components/error_alert/error_alert.vue';
import AddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/add_on_eligible_user_list.vue';
import { DUO_IDENTIFIERS } from 'ee/constants/duo';
import { SORT_OPTIONS, DEFAULT_SORT_OPTION } from 'ee/usage_quotas/code_suggestions/constants';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import {
  OPERATORS_IS,
  TOKEN_TITLE_ASSIGNED_SEAT,
  TOKEN_TYPE_ASSIGNED_SEAT,
} from '~/vue_shared/components/filtered_search_bar/constants';
import SearchAndSortBar from 'ee/usage_quotas/code_suggestions/components/search_and_sort_bar.vue';

export default {
  name: 'SelfManagedAddOnEligibleUserList',
  components: {
    SearchAndSortBar,
    ErrorAlert,
    AddOnEligibleUserList,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    addOnPurchaseId: {
      type: String,
      required: true,
    },
    activeDuoTier: {
      type: String,
      required: true,
      validator: (value) => DUO_IDENTIFIERS.includes(value),
    },
  },
  addOnErrorDictionary: ADD_ON_ERROR_DICTIONARY,
  data() {
    return {
      addOnEligibleUsers: undefined,
      addOnEligibleUsersFetchError: undefined,
      pageInfo: undefined,
      pageSize: DEFAULT_PER_PAGE,
      pagination: {
        first: DEFAULT_PER_PAGE,
        last: null,
        after: null,
        before: null,
      },
      filterOptions: {},
      sort: DEFAULT_SORT_OPTION,
    };
  },
  apollo: {
    addOnEligibleUsers: {
      query: getAddOnEligibleUsers,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      nextFetchPolicy: fetchPolicies.CACHE_FIRST,
      variables() {
        return this.queryVariables;
      },
      update({ selfManagedAddOnEligibleUsers }) {
        this.pageInfo = selfManagedAddOnEligibleUsers?.pageInfo;
        return selfManagedAddOnEligibleUsers?.nodes;
      },
      error(error) {
        this.handleAddOnUsersFetchError(error);
      },
    },
  },
  computed: {
    sortOptions() {
      return SORT_OPTIONS;
    },
    queryVariables() {
      return {
        addOnType: this.activeDuoTier,
        addOnPurchaseIds: [this.addOnPurchaseId],
        sort: this.sort,
        ...this.filterOptions,
        ...this.pagination,
      };
    },
    filterTokens() {
      return [
        {
          options: [
            { value: 'true', title: __('Yes') },
            { value: 'false', title: __('No') },
          ],
          icon: 'user',
          operators: OPERATORS_IS,
          title: TOKEN_TITLE_ASSIGNED_SEAT,
          token: BaseToken,
          type: TOKEN_TYPE_ASSIGNED_SEAT,
          unique: true,
        },
      ];
    },
  },
  methods: {
    clearAddOnEligibleUsersFetchError() {
      this.addOnEligibleUsersFetchError = undefined;
    },
    handleAddOnUsersFetchError(error) {
      this.addOnEligibleUsersFetchError = ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE;
      Sentry.captureException(error);
    },
    handleNext(endCursor) {
      this.pagination = {
        first: this.pageSize,
        last: null,
        before: null,
        after: endCursor,
      };
    },
    handlePrev(startCursor) {
      this.pagination = {
        first: null,
        last: this.pageSize,
        before: startCursor,
        after: null,
      };
    },
    handlePageSizeChange(size) {
      this.pageSize = size;
      this.pagination.first = size;
    },
    handleFilter(filterOptions) {
      this.pagination = {
        first: this.pageSize,
        last: null,
        after: null,
        before: null,
      };
      this.filterOptions = filterOptions;
    },
    handleSort(sort) {
      this.sort = sort;
    },
  },
};
</script>

<template>
  <add-on-eligible-user-list
    :add-on-purchase-id="addOnPurchaseId"
    :users="addOnEligibleUsers"
    :is-loading="$apollo.loading"
    :page-info="pageInfo"
    :page-size="pageSize"
    :search="filterOptions.search"
    :active-duo-tier="activeDuoTier"
    @next="handleNext"
    @prev="handlePrev"
    @page-size-change="handlePageSizeChange"
  >
    <template #search-and-sort-bar>
      <search-and-sort-bar
        :sort-options="sortOptions"
        :tokens="filterTokens"
        @on-filter="handleFilter"
        @on-sort="handleSort"
      />
    </template>
    <template #error-alert>
      <error-alert
        v-if="addOnEligibleUsersFetchError"
        data-testid="add-on-eligible-users-fetch-error"
        :error="addOnEligibleUsersFetchError"
        :error-dictionary="$options.addOnErrorDictionary"
        :dismissible="true"
        @dismiss="clearAddOnEligibleUsersFetchError"
      />
    </template>
  </add-on-eligible-user-list>
</template>
