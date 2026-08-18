<script>
import { GlSprintf, GlSkeletonLoader } from '@gitlab/ui';
import { RESOURCE_TYPES } from '~/groups_projects/constants';
import { numberToMetricPrefix } from '~/lib/utils/number_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import getProjectSecretsCount from '../graphql/get_project_secrets_count.query.graphql';
import getGroupSecretsCount from '../graphql/get_group_secrets_count.query.graphql';

export default {
  name: 'DeleteModalSecretsCount',
  components: { GlSprintf, GlSkeletonLoader },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    resourceType: {
      type: String,
      required: true,
    },
  },
  emits: ['fetch-error'],
  data() {
    return {
      secretsCount: null,
    };
  },
  apollo: {
    secretsCount: {
      query() {
        return this.resourceType === RESOURCE_TYPES.PROJECT
          ? getProjectSecretsCount
          : getGroupSecretsCount;
      },
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.secretsCount;
      },
      error(e) {
        this.$emit('fetch-error');
        Sentry.captureException(e);
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.secretsCount.loading;
    },
  },
  methods: {
    numberToMetricPrefix,
  },
};
</script>

<template>
  <li v-if="isLoading">
    <gl-skeleton-loader :lines="1" />
  </li>
  <li v-else-if="secretsCount !== null">
    <gl-sprintf :message="n__('%{count} secret', '%{count} secrets', secretsCount)">
      <template #count>{{ numberToMetricPrefix(secretsCount) }}</template>
    </gl-sprintf>
  </li>
</template>
