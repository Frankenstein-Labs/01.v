<script>
import { GlBreadcrumb } from '@gitlab/ui';
import { s__ } from '~/locale';
import { AI_CATALOG_INDEX_ROUTE } from './constants';

export default {
  name: 'AiCatalogBreadcrumbs',
  components: {
    GlBreadcrumb,
  },
  inject: {
    includeNamespaceBreadcrumbs: {
      default: false,
    },
    rootRouteName: {
      default: AI_CATALOG_INDEX_ROUTE,
    },
  },
  props: {
    staticBreadcrumbs: {
      required: true,
      type: Array,
    },
    allStaticBreadcrumbs: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    crumbs() {
      // Get the first matched items. Iterate over each of them and make them a breadcrumb item
      // only if they have a meta field with text
      const { id, reference } = this.$route.params;
      const matchedRoutes = (this.$route?.matched || [])
        .map((route) => {
          const useRouteId = Boolean(route.meta?.useId);
          const text = useRouteId && (id || reference) ? String(id || reference) : route.meta?.text;

          // Skip routes without text
          if (!text) return null;

          let to;
          if (route.name) {
            // Route has a name, so we can link directly to it
            to = { name: route.name, params: this.$route.params };
          } else if (route.meta?.indexRoute) {
            // An unnamed route that has an indexRoute specified -- use the indexRoute
            to = { name: route.meta.indexRoute, params: this.$route.params };
          } else {
            // Fallback
            to = { path: route.path };
          }

          return { text, to };
        })
        .filter(Boolean);

      return [...this.staticCrumbs, ...matchedRoutes];
    },
    namespaceCrumbs() {
      return this.includeNamespaceBreadcrumbs ? this.allStaticBreadcrumbs : this.staticBreadcrumbs;
    },
    staticCrumbs() {
      return [
        ...this.namespaceCrumbs,
        {
          text: s__('AICatalog|AI Catalog'),
          to: { name: this.rootRouteName },
        },
      ];
    },
  },
};
</script>
<template>
  <gl-breadcrumb :items="crumbs" :auto-resize="false" />
</template>
