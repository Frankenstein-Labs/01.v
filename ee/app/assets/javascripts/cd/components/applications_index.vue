<script>
import { GlButton, GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import {
  STATUS_AWAITING_APPROVAL,
  STATUS_DEGRADED,
  STATUS_DEPLOYING,
  STATUS_HEALTHY,
  statusSortOrderMap,
} from '../constants';
import cdApplicationsQuery from '../graphql/cd_applications.query.graphql';
import ApplicationCard from './application_card.vue';
import NewApplicationPanel from './new_application_panel.vue';
import FilterBar from './shared/filter_bar.vue';

export default {
  name: 'ApplicationsIndex',
  components: {
    ApplicationCard,
    FilterBar,
    GlButton,
    GlEmptyState,
    GlLoadingIcon,
    NewApplicationPanel,
    PageHeading,
  },
  data() {
    return {
      organization: null,
      isPanelOpen: false,
      searchTerm: '',
      selectedStatus: null,
    };
  },
  apollo: {
    organization: {
      query: cdApplicationsQuery,
      variables() {
        return {
          search: this.searchTerm.trim(),
          statuses: this.selectedStatus,
        };
      },
    },
  },
  computed: {
    applications() {
      return this.organization?.cdApplications.nodes || [];
    },
    displayedApplications() {
      return this.applications.toSorted(
        (a, b) => statusSortOrderMap[a.status] - statusSortOrderMap[b.status],
      );
    },
    isLoading() {
      return this.$apollo.queries.organization.loading;
    },
    organizationId() {
      return this.organization?.id;
    },
    showFilterEmptyState() {
      return this.searchTerm || this.selectedStatus;
    },
    statusButtons() {
      return [
        {
          text: s__('ContinuousDeployment|All'),
          id: null,
          count: this.applications.length,
        },
        {
          id: STATUS_AWAITING_APPROVAL,
          count: this.applications.filter((app) => app.status === STATUS_AWAITING_APPROVAL).length,
          text: s__('ContinuousDeployment|Awaiting approval'),
        },
        {
          id: STATUS_DEGRADED,
          count: this.applications.filter((app) => app.status === STATUS_DEGRADED).length,
          text: s__('ContinuousDeployment|Degraded'),
        },
        {
          id: STATUS_DEPLOYING,
          count: this.applications.filter((app) => app.status === STATUS_DEPLOYING).length,
          text: s__('ContinuousDeployment|Deploying'),
        },
        {
          id: STATUS_HEALTHY,
          count: this.applications.filter((app) => app.status === STATUS_HEALTHY).length,
          text: s__('ContinuousDeployment|Healthy'),
        },
      ];
    },
  },
  methods: {
    clearFilters() {
      this.searchTerm = '';
      this.selectedStatus = null;
    },
    refetchQuery() {
      this.$apollo.queries.organization.refetch();
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('ContinuousDeployment|Applications')">
      <template #actions>
        <gl-button variant="confirm" @click="isPanelOpen = true">
          {{ s__('ContinuousDeployment|New application') }}
        </gl-button>
      </template>
    </page-heading>

    <filter-bar
      :filters="statusButtons"
      :search-placeholder="s__('ContinuousDeployment|Search by name or description')"
      :search-term="searchTerm"
      :selected-filter-id="selectedStatus"
      @filter-selected="selectedStatus = $event"
      @search="searchTerm = $event"
    />

    <gl-loading-icon v-if="isLoading" size="lg" class="gl-mt-5" />

    <template v-else-if="displayedApplications.length">
      <!-- eslint-disable-next-line tailwindcss/no-arbitrary-value -->
      <div class="gl-mt-5 gl-grid gl-grid-cols-[repeat(auto-fill,minmax(16rem,1fr))] gl-gap-3">
        <application-card
          v-for="application in displayedApplications"
          :key="application.id"
          :application="application"
        />
      </div>
    </template>

    <gl-empty-state
      v-else-if="showFilterEmptyState"
      illustration-name="empty-search-md"
      :title="s__('ContinuousDeployment|No applications match your filters')"
      :description="__('To widen your search, change or remove filters above.')"
    >
      <template #actions>
        <gl-button variant="confirm" @click="clearFilters">
          {{ s__('ContinuousDeployment|Clear filters') }}
        </gl-button>
      </template>
    </gl-empty-state>

    <gl-empty-state
      v-else
      illustration-name="empty-dashboard-md"
      :title="s__('ContinuousDeployment|No applications yet')"
      :description="
        s__(
          'ContinuousDeployment|Create applications to track them and deploy them to environments',
        )
      "
    >
      <template #actions>
        <gl-button variant="confirm" @click="isPanelOpen = true">
          {{ s__('ContinuousDeployment|New application') }}
        </gl-button>
      </template>
    </gl-empty-state>

    <new-application-panel
      :open="isPanelOpen"
      :organization-id="organizationId"
      @close="isPanelOpen = false"
      @create="refetchQuery"
    />
  </div>
</template>
