<script>
import { GlAlert, GlSkeletonLoader } from '@gitlab/ui';
import { fetchPolicies } from '~/lib/graphql';
import { s__, sprintf } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import NotFound from '../../components/not_found.vue';
import {
  PAGE_NOT_FOUND_TITLE,
  REPOSITORY_FORMAT_LABELS,
  REPOSITORY_FORMAT_LOGO_SIZE_HEADING,
} from '../../constants';
import getArtifactQuery from '../../graphql/queries/get_artifact.query.graphql';
import getArtifactVersionsQuery from '../../graphql/queries/get_artifact_versions.query.graphql';
import { artifactDisplayName, isContainerFormat } from '../../utils';
import FormatLogo from '../components/format_logo.vue';
import VersionsSection from './versions_section.vue';

export default {
  name: 'ArtifactRegistryVersionList',
  components: {
    FormatLogo,
    GlAlert,
    GlSkeletonLoader,
    NotFound,
    PageHeading,
    VersionsSection,
  },
  inject: ['breadCrumbState', 'organizationGid'],
  data() {
    return {
      repository: undefined,
      hasError: false,
      versionConnection: undefined,
      hasVersionConnectionError: false,
    };
  },
  apollo: {
    repository: {
      query: getArtifactQuery,
      variables() {
        return {
          organizationId: this.organizationGid,
          name: this.repositoryName,
          artifactId: this.artifactId,
        };
      },
      update: ({ organization }) => organization?.artifactRegistryRepository ?? null,
      result({ error }) {
        this.hasError = Boolean(error);
      },
      error() {
        this.hasError = true;
      },
    },
    versionConnection: {
      query: getArtifactVersionsQuery,
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      variables() {
        return {
          organizationId: this.organizationGid,
          name: this.repositoryName,
          artifactId: this.artifactId,
        };
      },
      skip() {
        return !this.readsVersions;
      },
      update: ({ organization }) =>
        organization?.artifactRegistryRepository?.package?.versions ?? null,
      result({ error }) {
        this.hasVersionConnectionError = Boolean(error);
      },
      error() {
        this.hasVersionConnectionError = true;
      },
    },
  },
  computed: {
    repositoryName() {
      return this.$route.params.id;
    },
    artifactId() {
      return this.$route.params.artifactId;
    },
    isLoading() {
      return this.$apollo.queries.repository.loading;
    },
    format() {
      return this.repository?.format;
    },
    artifact() {
      return this.repository?.image ?? this.repository?.package ?? null;
    },
    displayName() {
      return artifactDisplayName(this.artifact, this.format);
    },
    formatLabel() {
      return REPOSITORY_FORMAT_LABELS[this.format];
    },
    // A missing repository and a missing artifact render one outcome, so the view never
    // confirms that an artifact the viewer cannot see exists.
    isNotFound() {
      return !this.isLoading && !this.hasError && !this.artifact;
    },
    isPopulated() {
      return Boolean(this.artifact);
    },
    readsVersions() {
      return this.isPopulated && !isContainerFormat(this.format);
    },
    versions() {
      return this.versionConnection?.nodes ?? [];
    },
    hasVersionsError() {
      return (
        this.readsVersions && (this.hasVersionConnectionError || this.versionConnection === null)
      );
    },
    isLoadingVersions() {
      if (!this.readsVersions || this.hasVersionsError) return false;

      return this.$apollo.queries.versionConnection.loading || this.versionConnection === undefined;
    },
    statusMessage() {
      if (this.hasError || this.hasVersionsError) return this.$options.i18n.unavailable;
      if (this.isLoading) return this.$options.i18n.loading;
      if (this.isNotFound) return this.$options.i18n.notFound;
      if (this.isLoadingVersions) return this.$options.i18n.versionsLoading;
      if (this.readsVersions) {
        return sprintf(this.$options.i18n.versionsLoaded, { name: this.displayName });
      }

      return sprintf(this.$options.i18n.loaded, { name: this.displayName });
    },
  },
  watch: {
    displayName: {
      immediate: true,
      handler(name) {
        this.breadCrumbState.updateName(name);
      },
    },
  },
  beforeDestroy() {
    this.breadCrumbState.updateName('');
  },
  i18n: {
    unavailable: s__('ArtifactRegistry|The Artifact Registry service is unavailable.'),
    loading: s__('ArtifactRegistry|Loading artifact details.'),
    loaded: s__('ArtifactRegistry|Artifact details for %{name} loaded.'),
    versionsLoading: s__('ArtifactRegistry|Loading versions.'),
    versionsLoaded: s__('ArtifactRegistry|Version list for %{name} updated.'),
    notFound: PAGE_NOT_FOUND_TITLE,
  },
  logoSize: REPOSITORY_FORMAT_LOGO_SIZE_HEADING,
};
</script>

<template>
  <div>
    <span
      class="gl-sr-only"
      aria-live="polite"
      aria-atomic="true"
      data-testid="versions-announcement"
      >{{ statusMessage }}</span
    >

    <gl-skeleton-loader v-if="isLoading" :lines="2" :width="500" class="gl-mt-4" />

    <gl-alert v-else-if="hasError" variant="danger" :dismissible="false">
      {{ $options.i18n.unavailable }}
    </gl-alert>

    <not-found v-else-if="isNotFound" />

    <template v-else-if="isPopulated">
      <page-heading>
        <template #heading>
          <span class="gl-flex gl-flex-wrap gl-items-center gl-gap-3">
            <format-logo :format="format" :size="$options.logoSize" />
            <span class="gl-sr-only" data-testid="artifact-format-name">{{ formatLabel }}</span>
            <span class="gl-wrap-anywhere" data-testid="artifact-name">{{ displayName }}</span>
          </span>
        </template>
      </page-heading>

      <versions-section
        v-if="readsVersions"
        :versions="versions"
        :loading="isLoadingVersions"
        :has-error="hasVersionsError"
      />
    </template>
  </div>
</template>
