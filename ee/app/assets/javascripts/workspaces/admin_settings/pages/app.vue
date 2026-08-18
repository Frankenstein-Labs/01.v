<script>
import {
  GlBadge,
  GlTableLite,
  GlSkeletonLoader,
  GlLink,
  GlAlert,
  GlSprintf,
  GlKeysetPagination,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import { helpPagePath } from '~/helpers/help_page_helper';

import AvailabilityPopover from '../components/availability_popover.vue';
import ClusterAgentAvailabilityToggle from '../components/availability_toggle.vue';
import GetOrganizationWorkspacesClusterAgentsQuery from '../components/get_organization_workspaces_cluster_agents_query.vue';

export default {
  name: 'WorkspacesAgentAvailabilityApp',
  components: {
    SettingsBlock,
    GetOrganizationWorkspacesClusterAgentsQuery,
    AvailabilityPopover,
    ClusterAgentAvailabilityToggle,
    GlTableLite,
    GlBadge,
    GlSkeletonLoader,
    GlLink,
    GlAlert,
    GlSprintf,
    GlKeysetPagination,
  },
  inject: {
    organizationId: {
      type: String,
      default: '',
    },
    defaultExpanded: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    helpUrl() {
      return helpPagePath('user/workspace/gitlab_agent_configuration');
    },
  },
  methods: {
    getStatusBadgeMetadata(item) {
      const { isConnected } = item;
      return {
        text: isConnected ? s__('Workspaces|Connected') : s__('Workspaces|Not connected'),
        variant: isConnected ? 'success' : 'neutral',
      };
    },
  },
  fields: [
    {
      key: 'name',
      label: s__('Workspaces|Name'),
    },
    {
      key: 'group',
      label: s__('Workspaces|Group'),
    },
    {
      key: 'project',
      label: s__('Workspaces|Project'),
    },
    {
      key: 'status',
      label: s__('Workspaces|Status'),
    },
    {
      key: 'availability',
      label: s__('Workspaces|Availability'),
    },
  ],
};
</script>
<template>
  <settings-block
    :title="s__('Workspaces|Available agents for workspaces')"
    :default-expanded="defaultExpanded"
  >
    <template #description>
      <gl-sprintf
        :message="
          s__(
            'Workspaces|Configure which Kubernetes agents are available for new workspaces. %{learnMore}',
          )
        "
      >
        <template #learnMore>
          <gl-link :href="helpUrl" target="_blank">{{
            s__('Workspaces|Learn more about agents.')
          }}</gl-link>
        </template>
      </gl-sprintf>
    </template>
    <template #default>
      <get-organization-workspaces-cluster-agents-query :organization-id="organizationId">
        <template #default="{ loading, pagination, agents, error }">
          <div>
            <gl-alert v-if="error" variant="danger" :dismissible="false"
              >{{ s__('Workspaces|Could not load agents. Refresh the page to try again.') }}
            </gl-alert>
            <gl-skeleton-loader v-else-if="loading" :lines="5" :width="600" />
            <div
              v-else-if="!loading && !agents.length"
              data-testid="agent-availability-empty-state"
            >
              {{ s__('Workspaces|No agents found.') }}
            </div>
            <div v-else class="gl-flex gl-flex-col gl-items-center gl-gap-3">
              <gl-table-lite
                responsive
                :items="agents"
                :fields="$options.fields"
                :aria-busy="loading"
              >
                <template #head(availability)="{ label }">
                  <div class="gl-flex gl-items-center gl-gap-3">
                    <span>{{ label }}</span>
                    <availability-popover />
                  </div>
                </template>
                <template #cell(name)="{ item }">
                  <gl-link
                    data-testid="agent-link"
                    class="gl-font-bold"
                    :href="item.url"
                    target="_blank"
                    >{{ item.name }}</gl-link
                  >
                </template>
                <template #cell(status)="{ item }">
                  <gl-badge :variant="getStatusBadgeMetadata(item).variant">{{
                    getStatusBadgeMetadata(item).text
                  }}</gl-badge>
                </template>
                <template #cell(availability)="{ item }">
                  <cluster-agent-availability-toggle
                    :agent-id="item.id"
                    :is-mapped="item.isMapped"
                  />
                </template>
              </gl-table-lite>
              <gl-keyset-pagination
                v-if="!loading && pagination.show"
                :has-next-page="pagination.hasNextPage"
                :has-previous-page="pagination.hasPreviousPage"
                @prev="pagination.prevPage"
                @next="pagination.nextPage"
              />
            </div>
          </div>
        </template>
      </get-organization-workspaces-cluster-agents-query>
    </template>
  </settings-block>
</template>
