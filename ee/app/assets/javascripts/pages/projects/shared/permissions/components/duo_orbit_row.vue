<script>
import { GlButton } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { getTimeago } from '~/lib/utils/datetime_utility';
import { s__, sprintf } from '~/locale';
import DuoReadinessRow from '~/pages/projects/shared/permissions/components/duo_readiness_row.vue';
import { STATUS_DONE, STATUS_TODO } from '~/pages/projects/shared/permissions/constants';
import { fetchGraphStatus } from 'ee/orbit/api/orbit_api';
import orbitUpdateMutation from 'ee/orbit/graphql/mutations/orbit_update.mutation.graphql';

export default {
  name: 'DuoOrbitRow',
  components: { GlButton, DuoReadinessRow },
  props: {
    orbit: {
      type: Object,
      required: true,
    },
    projectFullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      enabled: this.orbit.enabled,
      enabling: false,
      lastIndexedAt: null,
    };
  },
  computed: {
    status() {
      return this.enabled ? STATUS_DONE : STATUS_TODO;
    },
    description() {
      if (!this.enabled) {
        return this.orbit.canEnable
          ? s__(
              'DuoAgentPlatform|A knowledge graph that helps agents reason across your whole project.',
            )
          : s__(
              'DuoAgentPlatform|A knowledge graph that helps agents reason across your whole project. Only a Group Owner can turn it on.',
            );
      }

      if (this.lastIndexedAt) {
        return sprintf(s__('DuoAgentPlatform|Indexed %{timeAgo}. Agents get repo-wide context.'), {
          timeAgo: getTimeago().format(this.lastIndexedAt),
        });
      }

      return s__('DuoAgentPlatform|Agents get repo-wide context.');
    },
  },
  created() {
    if (this.enabled) {
      this.loadStatus();
    }
  },
  methods: {
    async loadStatus() {
      try {
        const { data } = await fetchGraphStatus(this.projectFullPath);
        this.lastIndexedAt = data?.indexing?.last_completed_at || null;
      } catch {
        this.lastIndexedAt = null;
      }
    },
    async enable() {
      this.enabling = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: orbitUpdateMutation,
          variables: { input: { groupPath: this.orbit.rootGroupPath, enabled: true } },
        });

        const [error] = data?.orbitUpdate?.errors ?? [];
        if (error) {
          throw new Error(error);
        }

        this.enabled = true;
        this.loadStatus();
      } catch (error) {
        createAlert({
          message: s__('DuoAgentPlatform|Something went wrong while turning on GitLab Orbit.'),
          error,
          captureError: true,
        });
      } finally {
        this.enabling = false;
      }
    },
  },
  i18n: {
    title: s__('DuoAgentPlatform|GitLab Orbit'),
    enable: s__('DuoAgentPlatform|Enable'),
    queryGraph: s__('DuoAgentPlatform|Query graph'),
  },
};
</script>

<template>
  <duo-readiness-row
    :title="$options.i18n.title"
    :description="description"
    :status="status"
    data-testid="orbit-row"
  >
    <gl-button
      v-if="enabled"
      category="tertiary"
      size="small"
      :href="orbit.graphPath"
      data-testid="orbit-query-graph-button"
    >
      {{ $options.i18n.queryGraph }}
    </gl-button>
    <gl-button
      v-else-if="orbit.canEnable"
      category="secondary"
      size="small"
      :loading="enabling"
      data-testid="orbit-enable-button"
      @click="enable"
    >
      {{ $options.i18n.enable }}
    </gl-button>
  </duo-readiness-row>
</template>
