<script>
import PageHeading from '~/vue_shared/components/page_heading.vue';
import RegistryForm from 'ee/packages_and_registries/virtual_registries/components/registry/form.vue';

export default {
  name: 'RegistryNewPage',
  components: {
    PageHeading,
    RegistryForm,
  },
  inject: ['i18n'],
};
</script>

<template>
  <div>
    <page-heading :heading="i18n.newRegistryPageTitle" />
    <registry-form />
  </div>
</template>
