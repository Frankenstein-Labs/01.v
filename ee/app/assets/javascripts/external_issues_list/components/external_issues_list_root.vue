<script>
import { GlButton, GlIcon, GlLink, GlSprintf, GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import SafeHtml from '~/vue_shared/directives/safe_html';

import IssuableList from '~/vue_shared/issuable/list/components/issuable_list_root.vue';
import {
  issuableListTabs,
  availableSortOptions,
  DEFAULT_PAGE_SIZE,
} from '~/vue_shared/issuable/list/constants';
import { STATUS_ALL, STATUS_CLOSED, STATUS_OPEN } from '~/issues/constants';
import { i18n } from '~/work_items/list/constants';
import {
  FILTERED_SEARCH_TERM,
  OPERATORS_IS,
  TOKEN_TITLE_LABEL,
  TOKEN_TYPE_LABEL,
} from '~/vue_shared/components/filtered_search_bar/constants';
import LabelToken from '~/vue_shared/components/filtered_search_bar/tokens/label_token.vue';

import ExternalIssuesListEmptyState from './external_issues_list_empty_state.vue';

export default {
  name: 'ExternalIssuesList',
  issuableListTabs,
  availableSortOptions,
  defaultPageSize: DEFAULT_PAGE_SIZE,
  components: {
    GlButton,
    GlIcon,
    GlLink,
    GlSprintf,
    GlAlert,
    IssuableList,
    ExternalIssuesListEmptyState,
  },
  directives: {
    SafeHtml,
  },
  inject: {
    initialState: {},
    initialSortBy: {},
    deployment: { default: 'cloud' },
    page: {},
    issuesFetchPath: {},
    projectFullPath: {},
    issueCreateUrl: {},
    getIssuesQuery: {},
    externalIssuesLogo: {},
    externalIssueTrackerName: {},
    searchInputPlaceholderText: {},
    recentSearchesStorageKey: {},
    createNewIssueText: {},
  },
  props: {
    initialFilterParams: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      issues: [],
      currentState: this.initialState,
      filterParams: this.initialFilterParams,
      sortedBy: this.initialSortBy,
      nextPageToken: null,
      isLast: false,
      currentPageInfo: null,
      currentPage: this.page,
      totalIssues: 0,
      pageTokenHistory: [],
      issuesCount: {
        [STATUS_OPEN]: 0,
        [STATUS_CLOSED]: 0,
        [STATUS_ALL]: 0,
      },
      errorMessage: null,
    };
  },
  computed: {
    isJiraCloud() {
      return this.deployment === 'cloud';
    },
    issuesListLoading() {
      return this.$apollo.queries.externalIssues.loading;
    },
    showPaginationControls() {
      if (this.isJiraCloud) {
        return (
          !this.issuesListLoading &&
          this.issues.length > 0 &&
          (this.pageTokenHistory.length > 0 || !this.isLast)
        );
      }
      return (
        !this.issuesListLoading && this.issues.length > 0 && this.totalIssues > DEFAULT_PAGE_SIZE
      );
    },
    hasFiltersApplied() {
      return Boolean(
        this.filterParams.project ||
        this.filterParams.status ||
        this.filterParams.authorUsername ||
        this.filterParams.assigneeUsername ||
        this.filterParams.labels ||
        this.filterParams.search,
      );
    },
    urlParams() {
      const params = {
        project: this.filterParams.project,
        status: this.filterParams.status,
        author_username: this.filterParams.authorUsername,
        assignee_username: this.filterParams.assigneeUsername,
        'labels[]': this.filterParams.labels,
        search: this.filterParams.search,
        ...(this.sortedBy === this.initialSortBy ? {} : { sort: this.sortedBy }),
        ...(this.currentState === this.initialState ? {} : { state: this.currentState }),
      };

      if (this.isJiraCloud) {
        if (this.nextPageToken) {
          params.next_page_token = this.nextPageToken;
        }
      } else if (this.currentPage !== 1) {
        params.page = this.currentPage;
      }

      return params;
    },
    paginationCurrentPage() {
      return this.isJiraCloud ? undefined : this.currentPage;
    },
    paginationPreviousPage() {
      return this.isJiraCloud ? undefined : this.currentPage - 1;
    },
    paginationNextPage() {
      return this.isJiraCloud ? undefined : this.currentPage + 1;
    },
    paginationTotalItems() {
      return this.isJiraCloud ? undefined : this.totalIssues;
    },
    paginationHasNext() {
      return this.isJiraCloud
        ? !this.isLast
        : this.currentPage * DEFAULT_PAGE_SIZE < this.totalIssues;
    },
    paginationHasPrevious() {
      return this.isJiraCloud ? this.pageTokenHistory.length > 0 : this.currentPage > 1;
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    externalIssues: {
      query() {
        return this.getIssuesQuery;
      },
      variables() {
        return {
          issuesFetchPath: this.issuesFetchPath,
          sort: this.sortedBy, // navigation attributes
          state: this.currentState, // navigation attributes
          project: this.filterParams.project, // filter attributes
          status: this.filterParams.status, // filter attributes
          authorUsername: this.filterParams.authorUsername, // filter attributes
          assigneeUsername: this.filterParams.assigneeUsername, // filter attributes
          labels: this.filterParams.labels, // filter attributes
          search: this.filterParams.search, // filter attributes
          nextPageToken: this.isJiraCloud ? this.nextPageToken : undefined, // pagination attributes
          page: !this.isJiraCloud ? this.currentPage : undefined, // pagination attributes
        };
      },
      result({ data, error }) {
        // let error() callback handle errors
        if (error) {
          return;
        }

        const { pageInfo, nodes, errors } = data?.externalIssues ?? {};
        if (errors?.length > 0) {
          this.onExternalIssuesQueryError(new Error(errors[0]));
          return;
        }

        this.issues = nodes;
        this.currentPageInfo = pageInfo;

        if (this.isJiraCloud) {
          this.isLast = pageInfo.isLast;
        } else {
          this.currentPage = pageInfo.page;
          this.totalIssues = pageInfo.total;
        }

        this.issuesCount[this.currentState] = nodes.length;
      },
      error(error) {
        this.onExternalIssuesQueryError(error, i18n.errorFetchingIssues);
      },
    },
  },
  methods: {
    getFilteredSearchTokens() {
      return [
        {
          type: TOKEN_TYPE_LABEL,
          icon: 'labels',
          symbol: '~',
          title: TOKEN_TITLE_LABEL,
          unique: false,
          token: LabelToken,
          operators: OPERATORS_IS,
          defaultLabels: [],
          suggestionsDisabled: true,
          fetchLabels: () => {
            return Promise.resolve([]);
          },
        },
      ];
    },
    getFilteredSearchValue() {
      const { labels, search } = this.filterParams || {};
      const filteredSearchValue = [];

      if (labels) {
        filteredSearchValue.push(
          ...labels.map((label) => ({
            type: TOKEN_TYPE_LABEL,
            value: { data: label },
          })),
        );
      }

      if (search) {
        filteredSearchValue.push({
          type: FILTERED_SEARCH_TERM,
          value: {
            data: search,
          },
        });
      }

      return filteredSearchValue;
    },
    resetPagination() {
      if (this.isJiraCloud) {
        this.nextPageToken = null;
        this.pageTokenHistory = [];
      } else {
        this.currentPage = 1;
      }
    },
    onExternalIssuesQueryError(error, message) {
      this.errorMessage = message || error.message;

      Sentry.captureException(error);
    },
    onIssuableListClickTab(selectedIssueState) {
      this.resetPagination();
      this.currentState = selectedIssueState;
    },
    onIssuableListNextPage() {
      if (this.isJiraCloud) {
        if (this.currentPageInfo?.nextPageToken) {
          this.pageTokenHistory.push(this.nextPageToken);
          this.nextPageToken = this.currentPageInfo.nextPageToken;
        }
      } else {
        this.currentPage += 1;
      }
    },
    onIssuableListPreviousPage() {
      if (this.isJiraCloud) {
        if (this.pageTokenHistory.length > 0) {
          this.nextPageToken = this.pageTokenHistory.pop();
        }
      } else {
        this.currentPage -= 1;
      }
    },
    onIssuableListPageChange(page) {
      this.currentPage = page;
    },
    onIssuableListSort(selectedSort) {
      this.resetPagination();
      this.sortedBy = selectedSort;
    },
    onIssuableListFilter(filters = []) {
      const filterParams = {};
      const labels = [];
      const plainText = [];

      filters.forEach((filter) => {
        if (!filter.value.data) return;

        switch (filter.type) {
          case TOKEN_TYPE_LABEL:
            labels.push(filter.value.data);
            break;
          case FILTERED_SEARCH_TERM:
            plainText.push(filter.value.data);
            break;
          default:
            break;
        }
      });

      if (plainText.length) {
        filterParams.search = plainText.join(' ');
      }

      if (labels.length) {
        filterParams.labels = labels;
      }

      this.resetPagination();

      this.filterParams = {
        ...filterParams,
        project: this.filterParams.project,
        status: this.filterParams.status,
        authorUsername: this.filterParams.authorUsername,
        assigneeUsername: this.filterParams.assigneeUsername,
      };
    },
  },
  alertSafeHtmlConfig: { ALLOW_TAGS: ['a'] },
};
</script>

<template>
  <gl-alert v-if="errorMessage" class="gl-mt-3" variant="danger" :dismissible="false">
    <span v-safe-html:[$options.alertSafeHtmlConfig]="errorMessage"></span>
  </gl-alert>
  <issuable-list
    v-else
    :namespace="projectFullPath"
    :tabs="$options.issuableListTabs"
    :current-tab="currentState"
    :search-input-placeholder="searchInputPlaceholderText"
    :search-tokens="getFilteredSearchTokens()"
    :sort-options="$options.availableSortOptions"
    :initial-filter-value="getFilteredSearchValue()"
    :initial-sort-by="sortedBy"
    :issuables="issues"
    :issuables-loading="issuesListLoading"
    :show-pagination-controls="showPaginationControls"
    :current-page="paginationCurrentPage"
    :previous-page="paginationPreviousPage"
    :next-page="paginationNextPage"
    :total-items="paginationTotalItems"
    :use-keyset-pagination="isJiraCloud"
    :has-next-page="paginationHasNext"
    :has-previous-page="paginationHasPrevious"
    :default-page-size="$options.defaultPageSize"
    :url-params="urlParams"
    label-filter-param="labels"
    :recent-searches-storage-key="recentSearchesStorageKey"
    @click-tab="onIssuableListClickTab"
    @next-page="onIssuableListNextPage"
    @previous-page="onIssuableListPreviousPage"
    @sort="onIssuableListSort"
    @filter="onIssuableListFilter"
    @page-change="onIssuableListPageChange"
  >
    <template #nav-actions>
      <gl-button :href="issueCreateUrl" target="_blank" class="gl-my-5">
        {{ createNewIssueText }}
        <gl-icon name="external-link" />
      </gl-button>
    </template>
    <template #reference="{ issuable }">
      <span v-safe-html="externalIssuesLogo" class="gl-inline-flex gl-align-text-bottom"></span>
      <span v-if="issuable">
        {{ issuable.references ? issuable.references.relative : issuable.id }}
      </span>
    </template>
    <template #author="{ author }">
      <gl-sprintf :message="`%{authorName} in ${externalIssueTrackerName}`">
        <template #authorName>
          <gl-link class="author-link js-user-link" target="_blank" :href="author.webUrl">
            {{ author.name }}
          </gl-link>
        </template>
      </gl-sprintf>
    </template>
    <template #status="{ issuable }">
      <template v-if="issuable"> {{ issuable.status }} </template>
    </template>
    <template #empty-state>
      <external-issues-list-empty-state
        :current-state="currentState"
        :issues-count="issuesCount"
        :has-filters-applied="hasFiltersApplied"
      />
    </template>
  </issuable-list>
</template>
