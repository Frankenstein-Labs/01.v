<script>
import { GlButton, GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__ } from '~/locale';
import cdAvailableAgentsQuery from '../graphql/cd_available_agents.query.graphql';
import EnvironmentCard from './environment_card.vue';

export default {
  name: 'EnvironmentList',
  components: {
    EnvironmentCard,
    GlButton,
    GlEmptyState,
    GlLoadingIcon,
  },
  props: {
    environments: {
      type: Array,
      required: false,
      default: () => [],
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasNextPage: {
      type: Boolean,
      required: false,
      default: false,
    },
    loadingMore: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['register', 'load-more'],
  i18n: {
    emptyStateTitle: s__('ContinuousDeployment|Get started with environments'),
    emptyStateDescription: s__(
      'ContinuousDeployment|Environments are places where code gets deployed, such as staging or production.',
    ),
    registerFirstEnvironment: s__('ContinuousDeployment|Register your first environment'),
    loadMore: __('Load more'),
  },
  data() {
    return {
      agentsOrganization: null,
    };
  },
  apollo: {
    // The cards render agent names, but a driver binding only stores the agent's ID. The
    // register panel already runs this query for its picker, so Apollo serves both from
    // one request.
    agentsOrganization: {
      query: cdAvailableAgentsQuery,
      update: (data) => data.organization,
      error(error) {
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    agents() {
      return this.agentsOrganization?.cdAvailableAgents?.nodes || [];
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="loading" size="md" class="gl-mt-5" data-testid="list-loader" />
    <template v-else-if="environments.length">
      <div class="gl-mt-5 gl-flex gl-flex-wrap gl-gap-4">
        <environment-card
          v-for="environment in environments"
          :key="environment.id"
          :environment="environment"
          :agents="agents"
        />
      </div>
      <div v-if="hasNextPage" class="gl-mt-5 gl-flex gl-justify-center">
        <gl-button
          :loading="loadingMore"
          data-testid="load-more-button"
          @click="$emit('load-more')"
        >
          {{ $options.i18n.loadMore }}
        </gl-button>
      </div>
    </template>
    <gl-empty-state
      v-else
      :title="$options.i18n.emptyStateTitle"
      :description="$options.i18n.emptyStateDescription"
      illustration-name="empty-environment-md"
    >
      <template #actions>
        <gl-button
          variant="confirm"
          data-testid="register-first-environment-button"
          @click="$emit('register')"
        >
          {{ $options.i18n.registerFirstEnvironment }}
        </gl-button>
      </template>
    </gl-empty-state>
  </div>
</template>
