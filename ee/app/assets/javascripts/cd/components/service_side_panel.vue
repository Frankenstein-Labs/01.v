<script>
import { GlBadge, GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_CD_SERVICE } from 'ee/graphql_shared/constants';
import DynamicPanel from '~/vue_shared/components/dynamic_panel.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import { healthVariant, healthLabel, worstServiceHealth } from '../utils';
import cdServiceQuery from '../graphql/cd_service.query.graphql';
import ArtifactSourceCard from './artifact_source_card.vue';
import EnvironmentBreakdown from './environment_breakdown.vue';

export default {
  name: 'ServiceSidePanel',
  components: {
    GlBadge,
    GlEmptyState,
    GlLoadingIcon,
    DynamicPanel,
    MountingPortal,
    ArtifactSourceCard,
    EnvironmentBreakdown,
    TimeAgo,
  },
  props: {
    serviceId: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['close'],
  data() {
    return {
      selectedService: null,
    };
  },
  apollo: {
    selectedService: {
      query: cdServiceQuery,
      variables() {
        return { id: this.serviceGid };
      },
      update: (data) => data?.organization?.cdService ?? null,
      skip() {
        return !this.serviceId;
      },
      error(error) {
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    serviceGid() {
      return convertToGraphQLId(TYPENAME_CD_SERVICE, this.serviceId);
    },
    hasService() {
      return this.selectedService != null;
    },
    serviceHealth() {
      return worstServiceHealth(this.selectedService);
    },
    isLoading() {
      return this.$apollo.queries.selectedService.loading;
    },
    sourceRef() {
      return this.selectedService?.artifactSources?.nodes?.[0]?.sourceRef ?? '';
    },
    artifactSources() {
      return this.selectedService?.artifactSources?.nodes ?? [];
    },
    hasArtifactSources() {
      return this.artifactSources.length > 0;
    },
    serviceEnvironments() {
      const environments = this.selectedService?.serviceEnvironmentHealths?.nodes ?? [];
      return environments
        .filter((node) => node.environment != null)
        .map((node) => ({
          id: node.id,
          tier: node.environment.tier,
          name: node.environment.name,
          health: node.health,
          version: node.deployedVersions?.nodes?.[0]?.name ?? null,
        }));
    },
    hasEnvironments() {
      return this.serviceEnvironments.length > 0;
    },
  },
  methods: {
    healthVariant,
    healthLabel,
  },
};
</script>

<template>
  <mounting-portal mount-to="#contextual-panel-portal" append>
    <dynamic-panel data-testid="service-side-panel" @close="$emit('close')">
      <template v-if="hasService" #header>
        <div class="gl-flex gl-w-full gl-items-center gl-justify-between gl-py-3">
          <div>
            <p
              class="gl-mb-2 gl-text-xs gl-font-bold gl-uppercase gl-tracking-wider gl-text-status-brand"
              data-testid="detail-eyebrow"
            >
              {{ s__('ContinuousDeployment|Service') }}
            </p>
            <h3 class="gl-my-0 gl-text-base" data-testid="detail-title">
              {{ selectedService.name }}
            </h3>
          </div>
          <gl-badge :variant="healthVariant(serviceHealth)" data-testid="detail-health-badge">
            {{ healthLabel(serviceHealth) }}
          </gl-badge>
        </div>
      </template>

      <gl-loading-icon v-if="isLoading" size="lg" class="gl-mt-6" data-testid="service-loading" />

      <div v-else-if="hasService" class="gl-pt-4" data-testid="detail-mode">
        <div
          v-if="sourceRef || selectedService.lastDeployedAt"
          class="gl-mb-5 gl-flex gl-flex-col gl-gap-5 gl-text-sm"
        >
          <div v-if="sourceRef">
            <p class="gl-mb-1 gl-text-xs gl-font-bold gl-uppercase gl-text-secondary">
              {{ s__('ContinuousDeployment|Source') }}
            </p>
            <span class="gl-font-monospace" data-testid="source-ref">{{ sourceRef }}</span>
          </div>

          <div v-if="selectedService.lastDeployedAt">
            <p class="gl-mb-1 gl-text-xs gl-font-bold gl-uppercase gl-text-secondary">
              {{ s__('ContinuousDeployment|Last deployed') }}
            </p>
            <time-ago :time="selectedService.lastDeployedAt" />
          </div>
        </div>

        <environment-breakdown
          v-if="hasEnvironments"
          :environments="serviceEnvironments"
          class="gl-mb-5"
        />

        <div v-if="hasArtifactSources" data-testid="artifact-sources">
          <artifact-source-card
            v-for="source in artifactSources"
            :key="source.id"
            :artifact-source="source"
            class="gl-mb-4"
          />
        </div>
        <p v-else class="gl-text-secondary" data-testid="artifact-sources-empty">
          {{ s__('ContinuousDeployment|No artifact sources configured.') }}
        </p>
      </div>

      <gl-empty-state
        v-else
        :title="s__('ContinuousDeployment|Service not found')"
        :description="
          s__('ContinuousDeployment|It may have been removed or you may not have access to it.')
        "
      />
    </dynamic-panel>
  </mounting-portal>
</template>
