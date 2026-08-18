<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ListHeader from 'ee_component/packages_and_registries/google_artifact_registry/components/list/header.vue';
import ListTable from 'ee_component/packages_and_registries/google_artifact_registry/components/list/table.vue';
import getArtifactRegistryRepositoryQuery from 'ee_component/packages_and_registries/google_artifact_registry/graphql/queries/get_artifact_registry_repository.query.graphql';
import getArtifactsQuery from 'ee_component/packages_and_registries/google_artifact_registry/graphql/queries/get_artifacts.query.graphql';

const PAGE_SIZE = 20;

export default {
  name: 'ArtifactRegistryListPage',
  components: {
    ListHeader,
    ListTable,
  },
  inject: ['fullPath'],
  apollo: {
    artifactRepository: {
      query: getArtifactRegistryRepositoryQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.project?.googleCloudArtifactRegistryRepository ?? {};
      },
      error(error) {
        this.failedToLoad = true;
        Sentry.captureException(error);
      },
    },
    artifacts: {
      query: getArtifactsQuery,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data.project?.googleCloudArtifactRegistryRepository?.artifacts ?? {};
      },
      error(error) {
        this.errorMessage = error.message;
        this.failedToLoadArtifacts = true;
        Sentry.captureException(error);
      },
    },
  },
  data() {
    return {
      artifactRepository: {},
      artifacts: {},
      sort: {
        sortBy: 'updateTime',
        sortDesc: true,
      },
      pageParams: {},
      cursors: [],
      failedToLoad: false,
      failedToLoadArtifacts: false,
      errorMessage: '',
    };
  },
  computed: {
    isArtifactsLoading() {
      return this.$apollo.queries.artifacts.loading;
    },
    isArtifactRepositoryLoading() {
      return this.$apollo.queries.artifactRepository.loading;
    },
    queryVariables() {
      return {
        first: PAGE_SIZE,
        fullPath: this.fullPath,
        sort: this.sortString,
        ...this.pageParams,
      };
    },
    showExternalLink() {
      return !this.isArtifactsLoading && !this.failedToLoadArtifacts;
    },
    sortString() {
      return this.sort.sortDesc ? 'UPDATE_TIME_DESC' : 'UPDATE_TIME_ASC';
    },
  },
  methods: {
    onSort(sort) {
      this.sort = sort;
      this.pageParams = {};
      this.cursors = [];
    },
    // The API only supports `next_page_token` which
    // translates to the `after` input
    // Storing the navigated cursors so that it is easier
    // to go back to previous pages
    fetchNextPage() {
      this.cursors = this.cursors.concat(this.artifacts.pageInfo?.startCursor);
      this.pageParams = { after: this.artifacts.pageInfo?.endCursor };
    },
    fetchPreviousPage() {
      const cursor = this.cursors.pop();
      this.pageParams = { after: cursor };
    },
  },
};
</script>

<template>
  <div data-testid="artifact-registry-list-page">
    <list-header
      :data="artifactRepository"
      :is-loading="isArtifactRepositoryLoading"
      :show-error="failedToLoad"
      :show-external-link="showExternalLink"
    />
    <list-table
      v-if="!failedToLoad"
      :data="artifacts"
      :error-message="errorMessage"
      :sort="sort"
      :is-loading="isArtifactsLoading"
      @sort-changed="onSort"
      @prev-page="fetchPreviousPage"
      @next-page="fetchNextPage"
    />
  </div>
</template>
