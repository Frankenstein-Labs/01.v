<script>
import { buildDocumentTitle } from '../utils';

export default {
  name: 'ArtifactRegistryRepositoriesApp',
  data() {
    return {
      baseTitle: document.title,
    };
  },
  computed: {
    documentTitle() {
      return buildDocumentTitle(this.$route, this.baseTitle);
    },
  },
  watch: {
    // On a client-side route change, move focus to the view container so the newly
    // rendered view is perceivable rather than leaving focus on the replaced content.
    // Watch the path alone: the filter, sort, and page selections live in the query and
    // update the rendered view in place, where moving focus would interrupt the list's
    // own announcement.
    '$route.path': function focusView() {
      this.$refs.view?.focus();
    },
    // The shell owns the title because a route can be named by something that resolves
    // after the navigation that opened it, which a router hook fires too early to see.
    documentTitle: {
      immediate: true,
      handler(title) {
        document.title = title;
      },
    },
  },
};
</script>

<template>
  <div ref="view" tabindex="-1" data-testid="repositories-shell">
    <router-view />
  </div>
</template>
