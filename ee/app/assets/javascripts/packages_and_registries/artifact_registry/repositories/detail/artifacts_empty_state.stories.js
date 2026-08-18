import ArtifactsEmptyState from './artifacts_empty_state.vue';

export default {
  component: ArtifactsEmptyState,
  title: 'ee/artifact_registry/repositories/detail/artifacts_empty_state',
};

const Template = (format) => () => ({
  components: { ArtifactsEmptyState },
  provide: {
    slug: 'acme',
    clientBaseUrl: 'https://ar.gitlab.com',
  },
  data() {
    return { format };
  },
  template: '<artifacts-empty-state name="my-repository" :format="format" />',
});

export const Maven = Template('MAVEN');

export const Npm = Template('NPM');

export const Docker = Template('DOCKER');

export const Oci = Template('OCI');
