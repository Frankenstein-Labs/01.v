<script>
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import CreateButton from '../components/create_button.vue';

export default {
  name: 'ArtifactRegistryRepositoriesHeader',
  i18n: {
    title: s__('ArtifactRegistry|Repositories'),
  },
  components: {
    CreateButton,
    PageHeading,
  },
};
</script>

<template>
  <page-heading :heading="$options.i18n.title">
    <template #actions>
      <create-button />
    </template>
  </page-heading>
</template>
