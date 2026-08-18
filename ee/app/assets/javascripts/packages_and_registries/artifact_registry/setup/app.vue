<script>
import { artifactRegistryRepositoriesOrganizationPath } from 'ee/lib/utils/path_helpers/organizations';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import SetupForm from './setup_form.vue';

const ACTIVATED_ALERT_ID = 'artifact-registry-activated';

export default {
  name: 'ArtifactRegistrySetupApp',
  i18n: {
    heading: s__('ArtifactRegistry|Set up Artifact registry'),
    description: s__(
      'ArtifactRegistry|A unified registry for artifacts across all projects and groups in your organization. To get started, choose a registry handle.',
    ),
    activatedTitle: s__('ArtifactRegistry|Artifact registry set up successfully'),
    activated: s__(
      'ArtifactRegistry|Create your first repository to start publishing and pulling artifacts.',
    ),
  },
  components: {
    PageHeading,
    SetupForm,
  },
  inject: ['organizationPath'],
  methods: {
    onSuccess({ handle }) {
      visitUrlWithAlerts(
        artifactRegistryRepositoriesOrganizationPath(this.organizationPath, handle),
        [
          {
            id: ACTIVATED_ALERT_ID,
            title: this.$options.i18n.activatedTitle,
            message: this.$options.i18n.activated,
            variant: 'success',
            dismissible: true,
          },
        ],
      );
    },
  },
};
</script>

<template>
  <div data-testid="artifact-registry-setup">
    <page-heading :heading="$options.i18n.heading">
      <template #description>{{ $options.i18n.description }}</template>
    </page-heading>

    <setup-form @success="onSuccess" />
  </div>
</template>
