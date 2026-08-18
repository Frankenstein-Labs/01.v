<script>
import { GlAlert, GlKeysetPagination, GlSkeletonLoader } from '@gitlab/ui';
import { fetchPolicies } from '~/lib/graphql';
import { s__ } from '~/locale';
import { getPageParams } from '~/packages_and_registries/shared/utils';
import NotFound from '../../components/not_found.vue';
import { GRAPHQL_PAGE_SIZE } from '../../constants';
import getRepositoryDetailQuery from '../../graphql/queries/get_repository_detail.query.graphql';
import getRepositoryImagesQuery from '../../graphql/queries/get_repository_images.query.graphql';
import getRepositoryPackagesQuery from '../../graphql/queries/get_repository_packages.query.graphql';
import { isContainerFormat } from '../../utils';
import ArtifactsSection from './artifacts_section.vue';
import RepositoryHeader from './repository_header.vue';
import RepositorySidebar from './repository_sidebar.vue';

export default {
  name: 'ArtifactRegistryRepositoryDetail',
  components: {
    ArtifactsSection,
    GlAlert,
    GlKeysetPagination,
    GlSkeletonLoader,
    NotFound,
    RepositoryHeader,
    RepositorySidebar,
  },
  inject: ['organizationGid'],
  data() {
    return {
      repository: undefined,
      hasError: false,
      artifactConnection: undefined,
      hasArtifactConnectionError: false,
    };
  },
  apollo: {
    repository: {
      query: getRepositoryDetailQuery,
      variables() {
        return { organizationId: this.organizationGid, name: this.repositoryName };
      },
      update: ({ organization }) => organization?.artifactRegistryRepository ?? null,
      // The query re-runs whenever its variables change, so each result has to speak for
      // itself: a read that succeeds after one that failed must clear the flag, or the
      // alert outlives the error it reported. `result` fires for failures too, so it
      // reads the error rather than assuming success.
      result({ error }) {
        this.hasError = Boolean(error);
      },
      error() {
        this.hasError = true;
      },
    },
    artifactConnection: {
      query() {
        return this.readsImages ? getRepositoryImagesQuery : getRepositoryPackagesQuery;
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      variables() {
        return {
          organizationId: this.organizationGid,
          name: this.repositoryName,
          first: GRAPHQL_PAGE_SIZE,
          ...this.pageParams,
        };
      },
      skip() {
        return !this.isPopulated;
      },
      update({ organization }) {
        const repository = organization?.artifactRegistryRepository;

        return (this.readsImages ? repository?.images : repository?.packages) ?? null;
      },
      result({ error }) {
        this.hasArtifactConnectionError = Boolean(error);
      },
      error() {
        this.hasArtifactConnectionError = true;
      },
    },
  },
  computed: {
    repositoryName() {
      return this.$route.params.id;
    },
    isLoading() {
      return this.$apollo.queries.repository.loading;
    },
    readsImages() {
      return isContainerFormat(this.repository?.format);
    },
    hasArtifactsError() {
      return this.hasArtifactConnectionError || this.artifactConnection === null;
    },
    isLoadingArtifacts() {
      if (this.hasArtifactsError) return false;

      return (
        this.$apollo.queries.artifactConnection.loading || this.artifactConnection === undefined
      );
    },
    artifacts() {
      return this.artifactConnection?.nodes ?? [];
    },
    pageInfo() {
      return this.artifactConnection?.pageInfo ?? {};
    },
    pageParams() {
      return getPageParams(this.$route.query, GRAPHQL_PAGE_SIZE);
    },
    hasNoArtifacts() {
      return !this.isLoadingArtifacts && !this.hasArtifactsError && this.artifacts.length === 0;
    },
    // The read resolves null both for a repository that does not exist and for one
    // the viewer may not see, so the view renders one outcome for the two and never
    // confirms the repository exists.
    isNotFound() {
      return this.repository === null;
    },
    isPopulated() {
      return Boolean(this.repository);
    },
    // Every page announces the same sentence, and a live region stays silent on a message
    // identical to the one it holds. The loading pass a cursor change already causes is
    // what separates one page's announcement from the next.
    artifactsMessage() {
      if (this.hasArtifactsError) return this.$options.i18n.unavailable;
      if (this.isLoadingArtifacts) return this.$options.i18n.artifactsLoading;

      return this.$options.i18n.artifactsUpdated;
    },
  },
  methods: {
    pageTo({ before, after }) {
      this.$router.push({ query: { ...this.$route.query, before, after } });
    },
  },
  i18n: {
    unavailable: s__('ArtifactRegistry|The Artifact Registry service is unavailable.'),
    artifactsLoading: s__('ArtifactRegistry|Loading artifacts.'),
    artifactsUpdated: s__('ArtifactRegistry|Artifact list updated.'),
    sidebarLabel: s__('ArtifactRegistry|Repository details'),
  },
};
</script>

<template>
  <div>
    <span
      class="gl-sr-only"
      aria-live="polite"
      aria-atomic="true"
      data-testid="artifacts-announcement"
      >{{ artifactsMessage }}</span
    >

    <!-- Each region carries its own loading affordance, so the page reads as the shape
         it is about to be rather than as a single spinner. -->
    <gl-skeleton-loader v-if="isLoading" :lines="2" :width="500" class="gl-mt-4" />

    <gl-alert v-else-if="hasError" variant="danger" :dismissible="false">
      {{ $options.i18n.unavailable }}
    </gl-alert>

    <not-found v-else-if="isNotFound" />

    <template v-else-if="isPopulated">
      <!-- The header names the whole page, so it spans it: inside the column grid
           below, its actions would right-align to the end of the main column rather
           than the end of the view. The grid is for the content under it — the
           artifact list and the metadata sidebar. -->
      <repository-header :repository="repository" />

      <div class="gl-grid gl-gap-5 @lg/panel:gl-grid-cols-3">
        <div class="@lg/panel:gl-col-span-2" data-testid="repository-detail-main">
          <artifacts-section
            :name="repository.name"
            :format="repository.format"
            :artifacts="artifacts"
            :loading="isLoadingArtifacts"
            :has-error="hasArtifactsError"
          />

          <div class="gl-mt-3 gl-flex gl-justify-center">
            <gl-keyset-pagination
              v-bind="pageInfo"
              @prev="pageTo({ before: $event })"
              @next="pageTo({ after: $event })"
            />
          </div>
        </div>
        <aside :aria-label="$options.i18n.sidebarLabel" data-testid="repository-detail-sidebar">
          <repository-sidebar :repository="repository" :hide-stats="hasNoArtifacts" />
        </aside>
      </div>
    </template>
  </div>
</template>
