<script>
import CeDependencyProxyUsage from '~/usage_quotas/storage/namespace/components/dependency_proxy_usage.vue';

export default {
  name: 'DependencyProxyUsageEE',
  components: {
    CeDependencyProxyUsage,
  },
  props: CeDependencyProxyUsage.props,
};
</script>

<template>
  <ce-dependency-proxy-usage
    v-bind="$props"
    :description="
      s__('UsageQuota|Cache for frequently-accessed Docker images and virtual registries.')
    "
  />
</template>
