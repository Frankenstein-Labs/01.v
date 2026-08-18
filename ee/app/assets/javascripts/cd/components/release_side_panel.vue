<script>
import { GlBadge, GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_CD_VERSION_SET } from 'ee/graphql_shared/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DynamicPanel from '~/vue_shared/components/dynamic_panel.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import {
  worstRolloutHealth,
  healthVariant,
  healthLabel,
  rolloutStateVariant,
  rolloutStateLabel,
} from '../utils';
import cdVersionSetQuery from '../graphql/cd_version_set.query.graphql';
import TriggerDeployment from './trigger_deployment.vue';

export default {
  name: 'ReleaseSidePanel',
  components: {
    GlBadge,
    GlEmptyState,
    GlLoadingIcon,
    DynamicPanel,
    MountingPortal,
    TimeAgo,
    TriggerDeployment,
  },
  props: {
    releaseId: {
      type: String,
      required: true,
    },
  },
  emits: ['close', 'deploy-triggered'],
  data() {
    return {
      versionSet: null,
      organizationId: null,
    };
  },
  apollo: {
    versionSet: {
      query: cdVersionSetQuery,
      variables() {
        return { id: this.versionSetGid };
      },
      update: (data) => {
        return data?.organization?.cdVersionSet ?? null;
      },
      result({ data }) {
        this.organizationId = data?.organization?.id ?? this.organizationId;
      },
      error(error) {
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    versionSetGid() {
      return convertToGraphQLId(TYPENAME_CD_VERSION_SET, this.releaseId);
    },
    selectedRelease() {
      return this.versionSet;
    },
    isLoading() {
      return this.$apollo.queries.versionSet.loading;
    },
    hasDeployments() {
      return this.selectedRelease?.rollouts?.nodes?.length > 0;
    },
    deployments() {
      const nodes = this.selectedRelease?.rollouts?.nodes ?? [];

      return nodes.map((rollout) => rollout.iid);
    },
    authorUsername() {
      return this.selectedRelease?.author?.username ?? null;
    },
    latestRollout() {
      return this.selectedRelease?.latestRollout?.nodes?.[0] ?? null;
    },
    rolloutState() {
      return this.latestRollout?.state ?? null;
    },
    latestRolloutHealth() {
      return worstRolloutHealth(this.latestRollout);
    },
    entries() {
      const nodes = this.selectedRelease?.versionSetEntries?.nodes ?? [];

      return nodes.map((entry) => ({
        service: entry.service?.name,
        version: entry.version?.name,
        sourceRef: entry.artifactSource?.sourceRef,
      }));
    },
    hasEntries() {
      return this.entries.length > 0;
    },
  },
  methods: {
    healthVariant,
    healthLabel,
    rolloutStateVariant,
    rolloutStateLabel,
  },
};
</script>

<template>
  <mounting-portal mount-to="#contextual-panel-portal" append>
    <dynamic-panel data-testid="release-side-panel" @close="$emit('close')">
      <template v-if="selectedRelease" #header>
        <div class="gl-py-3">
          <p
            class="gl-mb-2 gl-text-xs gl-font-bold gl-uppercase gl-tracking-wider gl-text-status-brand"
          >
            {{ s__('ContinuousDeployment|Release') }}
          </p>
          <h3 class="gl-my-0 gl-text-base" data-testid="release-title">
            {{ selectedRelease.name }}
          </h3>
        </div>
      </template>

      <gl-loading-icon v-if="isLoading" size="lg" class="gl-mt-5" />

      <template v-else-if="selectedRelease">
        <p
          v-if="selectedRelease.description"
          class="gl-mb-4 gl-mt-2 gl-rounded-base gl-border-1 gl-border-solid gl-border-purple-100 gl-bg-purple-50 gl-p-3 gl-text-sm gl-text-subtle"
          data-testid="release-description"
        >
          {{ selectedRelease.description }}
        </p>
        <div
          class="gl-mt-4 gl-flex gl-gap-2 gl-border-b-1 gl-border-b-default gl-pb-4 gl-border-b-solid"
          data-testid="release-header-badges"
        >
          <gl-badge
            v-if="rolloutStateLabel(rolloutState)"
            :variant="rolloutStateVariant(rolloutState)"
            data-testid="release-status-badge"
          >
            {{ rolloutStateLabel(rolloutState) }}
          </gl-badge>
          <gl-badge
            :variant="healthVariant(latestRolloutHealth)"
            data-testid="release-health-badge"
          >
            {{ healthLabel(latestRolloutHealth) }}
          </gl-badge>
        </div>

        <div
          class="gl-mt-4 gl-border-b-1 gl-border-b-default gl-pb-4 gl-border-b-solid"
          data-testid="release-meta"
        >
          <div class="gl-grid gl-grid-cols-1 gl-gap-3 gl-text-sm @sm:gl-grid-cols-2">
            <div v-if="authorUsername">
              <p class="gl-mb-1 gl-text-xs gl-font-bold gl-uppercase gl-text-secondary">
                {{ s__('ContinuousDeployment|Bundled by') }}
              </p>
              <span data-testid="release-author">@{{ authorUsername }}</span>
            </div>
            <div>
              <p class="gl-mb-1 gl-text-xs gl-font-bold gl-uppercase gl-text-secondary">
                {{ s__('ContinuousDeployment|Created') }}
              </p>
              <time-ago
                v-if="selectedRelease.createdAt"
                :time="selectedRelease.createdAt"
                data-testid="release-created"
              />
            </div>
          </div>
        </div>

        <div v-if="hasDeployments" class="gl-mt-4">
          <p
            class="gl-mb-2 gl-text-xs gl-font-bold gl-uppercase gl-tracking-wider gl-text-secondary"
            data-testid="deployments-title"
          >
            {{ s__('ContinuousDeployment|Deployments') }}
          </p>

          <ul
            class="gl-m-0 gl-flex gl-list-none gl-gap-3 gl-p-0 gl-text-sm"
            data-testid="deployment-ids"
          >
            <li v-for="id in deployments" :key="id">#{{ id }}</li>
          </ul>
        </div>

        <div class="gl-mt-4">
          <p
            class="gl-mb-2 gl-text-xs gl-font-bold gl-uppercase gl-tracking-wider gl-text-secondary"
            data-testid="services-title"
          >
            {{ s__('ContinuousDeployment|Services in this release') }}
          </p>

          <ul
            v-if="hasEntries"
            class="gl-border gl-m-0 gl-list-none gl-rounded-lg gl-border-default gl-p-0"
          >
            <li
              v-for="(entry, index) in entries"
              :key="index"
              class="gl-border-b gl-flex gl-items-center gl-justify-between gl-border-default gl-px-3 gl-py-2 last:gl-border-b-0"
              data-testid="service-row"
            >
              <span class="gl-flex gl-flex-col gl-text-sm">
                <span class="gl-font-semibold">{{ entry.service }}</span>
                <span class="gl-font-monospace gl-text-subtle">{{ entry.sourceRef }}</span>
              </span>
              <code
                class="gl-mb-0 gl-rounded-base gl-border-none gl-bg-subtle gl-px-2 gl-py-1 gl-text-sm gl-text-secondary"
                >{{ entry.version }}</code
              >
            </li>
          </ul>
          <p v-else class="gl-text-xs gl-text-subtle">
            {{ s__('ContinuousDeployment|No services in this release.') }}
          </p>
        </div>

        <trigger-deployment
          v-if="organizationId"
          class="gl-mt-4"
          :organization-id="organizationId"
          :version-set-id="versionSetGid"
          :release-name="selectedRelease.name"
          @deploy-triggered="$emit('deploy-triggered')"
        />
      </template>

      <gl-empty-state
        v-else
        :title="s__('ContinuousDeployment|Release not found')"
        :description="
          s__('ContinuousDeployment|It may have been removed or you may not have access to it.')
        "
      />
    </dynamic-panel>
  </mounting-portal>
</template>
