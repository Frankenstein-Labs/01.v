<script>
import SpaBreadcrumbs from '~/vue_shared/spa/components/spa_breadcrumbs.vue';

export default {
  name: 'ContainerVirtualRegistriesBreadcrumbs',
  // overriding props of `SpaBreadcrumbs` to
  // pass `staticBreadcrumbs` as `allStaticBreadcrumbs`.
  // When using `injectVueAppBreadcrumbs` from
  // https://gitlab.com/gitlab-org/gitlab/-/blob/8fb0986e81b5df86064041658ae0b1232a2a69f3/app/assets/javascripts/lib/utils/breadcrumbs.js#L33,
  // `staticBreadcrumbs` needs to be considered if using
  // the last breadcrumb item as root.
  components: {
    SpaBreadcrumbs,
  },
  props: {
    staticBreadcrumbs: {
      required: true,
      type: Array,
    },
  },
};
</script>

<template>
  <spa-breadcrumbs :all-static-breadcrumbs="staticBreadcrumbs" />
</template>
