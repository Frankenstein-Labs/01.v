<script>
// We are using gl-breadcrumb only at the last child of the handwritten breadcrumb
// until this gitlab-ui issue is resolved: https://gitlab.com/gitlab-org/gitlab-ui/-/issues/1079 [CLOSED]
import { GlBreadcrumb, GlSkeletonLoader } from '@gitlab/ui';
import { TYPENAME_ITERATIONS_CADENCE } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import readCadence from '../queries/iteration_cadence.query.graphql';

const cadencePath = '/:cadenceId';

export default {
  name: 'IterationBreadcrumb',
  components: {
    GlBreadcrumb,
    GlSkeletonLoader,
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    group: {
      skip() {
        return !this.cadenceId;
      },
      query: readCadence,
      variables() {
        return {
          fullPath: this.getGroupPath(),
          id: convertToGraphQLId(TYPENAME_ITERATIONS_CADENCE, this.cadenceId),
        };
      },
      result({ data: { group, errors }, error }) {
        const cadence = group?.iterationCadences?.nodes?.[0];

        if (!cadence || error || errors?.length) {
          this.cadenceTitle = this.cadenceId;
          return;
        }

        this.cadenceTitle = cadence.title;
      },
    },
  },
  props: {
    staticBreadcrumbs: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      cadenceTitle: '',
    };
  },
  computed: {
    cadenceId() {
      return this.$route.params.cadenceId;
    },
    allBreadcrumbs() {
      const pathArray = this.$route.path.split('/');
      const breadcrumbs = [];

      pathArray.forEach((path, index) => {
        let text = this.$route.matched[index]?.meta?.breadcrumb || path;

        if (this.$route.matched[index]?.path === cadencePath) {
          text = this.cadenceTitle;
        }
        const prevPath = breadcrumbs[index - 1]?.to || '';
        const to = `${prevPath}/${path}`.replace(/\/+/, '/');

        if (text) {
          breadcrumbs.push({
            path,
            to,
            text,
          });
        }
      });

      return [...this.staticBreadcrumbs, ...breadcrumbs];
    },
  },
  methods: {
    getGroupPath() {
      return document.body.dataset.groupFullPath;
    },
  },
};
</script>

<template>
  <gl-skeleton-loader
    v-if="$apollo.queries.group.loading"
    :width="200"
    :lines="1"
    class="gl-mx-3"
  />
  <gl-breadcrumb v-else :items="allBreadcrumbs" :auto-resize="false" />
</template>
