<script>
import { GlBreadcrumb } from '@gitlab/ui';
import { routeName } from '../utils';

// An ancestor crumb is a shorter route than the one being viewed, so it cannot place every
// current param. Narrowing to the ones its own path declares is what keeps vue-router from
// discarding the rest with a warning. A wildcard declares none and takes them all.
const placeableParams = ({ path }, params) => {
  const names = path.match(/:\w+/g);

  if (!names) return params;

  return Object.fromEntries(names.map((name) => [name.slice(1), params[name.slice(1)]]));
};

export default {
  name: 'ArtifactRegistryBreadcrumbs',
  components: {
    GlBreadcrumb,
  },
  // `injectVueAppBreadcrumbs` passes the full Rails trail alongside the same trail with
  // its last crumb sliced off, and only the sliced one is declared below. Without this
  // the undeclared full trail would serialize onto the rendered breadcrumb as a stray
  // attribute.
  inheritAttrs: false,
  props: {
    staticBreadcrumbs: {
      required: true,
      type: Array,
    },
  },
  computed: {
    crumbs() {
      const { matched, params } = this.$route;

      const routeCrumbs = matched
        .map((route) => {
          const text = routeName({ meta: route.meta, params });

          if (!text) return null;

          // A route that renders nothing of its own hands its name to a child and names
          // that child in `meta.defaultRoute`, so the crumb still has a route to link to.
          const name = route.name || route.meta.defaultRoute;

          // Carrying the current params is what interpolates a dynamic segment:
          // vue-router merges them into a named location only when that location already
          // supplies one, so a bare `{ name }` renders the uninterpolated route pattern.
          // The predicate is the path rather than `meta.useId` because the `*` fallback
          // needs its params too. A static target takes none: handing it params it cannot
          // place makes vue-router warn that it discarded them.
          const to = /[:*]/.test(route.path)
            ? { name, params: placeableParams(route, params) }
            : { name };

          return { text, to };
        })
        .filter(Boolean);

      return [...this.staticBreadcrumbs, ...routeCrumbs];
    },
  },
};
</script>

<template>
  <gl-breadcrumb :items="crumbs" :auto-resize="false" />
</template>
