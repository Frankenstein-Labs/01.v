<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DetailsHeader from 'ee_component/packages_and_registries/google_artifact_registry/components/details/header.vue';
import ImageDetails from 'ee_component/packages_and_registries/google_artifact_registry/components/details/image.vue';
import getArtifactDetailsQuery from 'ee_component/packages_and_registries/google_artifact_registry/graphql/queries/get_artifact_details.query.graphql';

export default {
  name: 'ArtifactRegistryDetailsPage',
  components: {
    DetailsHeader,
    ImageDetails,
  },
  inject: ['breadCrumbState', 'fullPath'],
  apollo: {
    artifact: {
      query: getArtifactDetailsQuery,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data.googleCloudArtifactRegistryRepositoryArtifact ?? {};
      },
      result() {
        this.updateBreadcrumb();
      },
      error(error) {
        this.failedToLoad = true;
        Sentry.captureException(error);
      },
    },
  },
  data() {
    return {
      artifact: {},
      failedToLoad: false,
    };
  },
  computed: {
    headerData() {
      const { uri, artifactRegistryImageUrl } = this.artifact;
      if (uri) {
        return {
          title: this.imageNameAndShortDigest,
          uri,
          artifactRegistryImageUrl,
        };
      }
      return {};
    },
    imageParams() {
      return this.$route.params.image;
    },
    shortDigest() {
      // remove sha256: from the string, and show only the first 12 char
      return this.imageParams.split('sha256:')[1]?.substring(0, 12) ?? '';
    },
    imageNameAndShortDigest() {
      const [name] = this.imageParams.split('@');
      return `${name}@${this.shortDigest}`;
    },
    isLoading() {
      return this.$apollo.queries.artifact.loading;
    },
    queryVariables() {
      return {
        googleCloudProjectId: this.$route.params.projectId,
        location: this.$route.params.location,
        repository: this.$route.params.repository,
        image: this.imageParams,
        projectPath: this.fullPath,
      };
    },
  },
  methods: {
    updateBreadcrumb() {
      this.breadCrumbState.updateName(this.imageNameAndShortDigest);
    },
  },
};
</script>

<template>
  <div>
    <details-header :data="headerData" :is-loading="isLoading" :show-error="failedToLoad" />
    <image-details v-if="!failedToLoad" :data="artifact" :is-loading="isLoading" />
  </div>
</template>
