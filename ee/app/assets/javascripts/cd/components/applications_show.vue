<script>
import { GlAlert, GlButton, GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { TYPENAME_CD_APPLICATION } from 'ee/graphql_shared/constants';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  PAGE_SIZE_SM,
  PAGE_SIZE_MD,
  STATUS_ALL,
  DEPLOYMENT_STATUS_FILTERS,
  RELEASE_STATUS_FILTERS,
} from '../constants';
import cdApplicationQuery from '../graphql/cd_application.query.graphql';
import cdApplicationServicesQuery from '../graphql/cd_application_services.query.graphql';
import cdServiceUpdatedSubscription from '../graphql/cd_service_updated.subscription.graphql';
import cdDeploymentUpdatedSubscription from '../graphql/cd_deployment_updated.subscription.graphql';
import cdApplicationReleasesQuery from '../graphql/cd_application_releases.query.graphql';
import cdApplicationDeploymentsQuery from '../graphql/cd_application_deployments.query.graphql';
import cdApplicationLinksQuery from '../graphql/cd_application_links.query.graphql';
import ApplicationHeader from './application_header.vue';
import OverviewCard from './overview_card.vue';
import ServicesTable from './services_table.vue';
import ReleasesTable from './releases_table.vue';
import DeploymentsTable from './deployments_table.vue';
import ApplicationFlow from './application_flow.vue';
import ApplicationLinks from './application_links.vue';
import FilterBar from './shared/filter_bar.vue';

const RELEASE_PANEL_ROUTE = { name: 'release_detail_route', param: 'releaseId' };
const SERVICE_PANEL_ROUTE = { name: 'service_detail_route', param: 'serviceId' };

const DEFAULT_FILTERS = {
  deployments: { search: '', statusId: STATUS_ALL },
  releases: { search: '', statusId: STATUS_ALL },
};

const DEFAULT_PAGE_SIZE = {
  services: PAGE_SIZE_SM,
  deployments: PAGE_SIZE_SM,
  releases: PAGE_SIZE_SM,
  links: PAGE_SIZE_MD,
};

export default {
  name: 'ApplicationsShow',
  components: {
    GlAlert,
    ApplicationHeader,
    GlButton,
    GlLoadingIcon,
    GlEmptyState,
    OverviewCard,
    ApplicationFlow,
    FilterBar,
  },
  props: {
    id: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      application: null,
      services: [],
      servicesPageInfo: {},
      releases: [],
      releasesPageInfo: {},
      deployments: [],
      deploymentEnvironments: [],
      deploymentsPageInfo: {},
      links: [],
      linksPageInfo: {},
      pagination: Object.fromEntries(
        Object.entries(DEFAULT_PAGE_SIZE).map(([key, pageSize]) => [
          key,
          { pageSize, after: null, before: null },
        ]),
      ),
      hasError: false,
      servicesError: false,
      releasesError: false,
      deploymentsError: false,
      linksError: false,
      expandedSections: {},
      filters: Object.fromEntries(
        Object.entries(DEFAULT_FILTERS).map(([key, value]) => [key, { ...value }]),
      ),
      selectedDeploymentId: null,
      preselectedDeploymentId: null,
      recentDeploymentId: null,
      relatedReleaseId: null,
      recentReleaseId: null,
    };
  },
  apollo: {
    application: {
      query: cdApplicationQuery,
      variables() {
        return { id: this.applicationId };
      },
      update: (data) => data?.organization?.cdApplication ?? null,
      error() {
        this.hasError = true;
      },
      watchLoading(isLoading) {
        // Clear a stale error when a new fetch starts (e.g. on refetch).
        if (isLoading) {
          this.hasError = false;
        }
      },
    },
    services: {
      query: cdApplicationServicesQuery,
      variables() {
        return { id: this.applicationId, ...this.pageVariables('services') };
      },
      update: (data) => data?.organization?.cdApplication?.services?.nodes ?? [],
      result({ data }) {
        this.servicesPageInfo = data?.organization?.cdApplication?.services?.pageInfo ?? {};
      },
      error(error) {
        this.servicesError = true;
        Sentry.captureException(error);
      },
      watchLoading(isLoading) {
        if (isLoading) {
          this.servicesError = false;
        }
      },
      subscribeToMore: {
        document: cdServiceUpdatedSubscription,
        variables() {
          return { applicationId: this.applicationId };
        },
      },
    },
    releases: {
      query: cdApplicationReleasesQuery,
      variables() {
        return {
          id: this.applicationId,
          ...this.pageVariables('releases'),
          search: this.filters.releases.search || null,
          statuses: this.statusesFor('releases'),
        };
      },
      update: (data) => data?.organization?.cdApplication?.versionSets?.nodes ?? [],
      result({ data }) {
        this.releasesPageInfo = data?.organization?.cdApplication?.versionSets?.pageInfo ?? {};
      },
      error(error) {
        this.releasesError = true;
        Sentry.captureException(error);
      },
      watchLoading(isLoading) {
        if (isLoading) {
          this.releasesError = false;
        }
      },
    },
    deployments: {
      query: cdApplicationDeploymentsQuery,
      variables() {
        return {
          id: this.applicationId,
          ...this.pageVariables('deployments'),
          search: this.filters.deployments.search || null,
          statuses: this.statusesFor('deployments'),
        };
      },
      update: (data) => data?.organization?.cdApplication?.rollouts?.nodes ?? [],
      result({ data }) {
        const application = data?.organization?.cdApplication;
        this.deploymentEnvironments = application?.environments?.nodes ?? [];
        this.deploymentsPageInfo = application?.rollouts?.pageInfo ?? {};
      },
      error(error) {
        this.deploymentsError = true;
        Sentry.captureException(error);
      },
      watchLoading(isLoading) {
        if (isLoading) {
          this.deploymentsError = false;
        }
      },
      subscribeToMore: {
        document: cdDeploymentUpdatedSubscription,
        variables() {
          return { applicationId: this.applicationId };
        },
      },
    },
    links: {
      query: cdApplicationLinksQuery,
      variables() {
        return {
          applicationId: this.applicationId,
          ...this.pageVariables('links'),
        };
      },
      update: (data) => data?.organization?.cdApplication?.links?.nodes ?? [],
      result({ data }) {
        this.linksPageInfo = data?.organization?.cdApplication?.links?.pageInfo ?? {};
      },
      error(error) {
        this.linksError = true;
        Sentry.captureException(error);
      },
      watchLoading(isLoading) {
        if (isLoading) {
          this.linksError = false;
        }
      },
    },
  },
  computed: {
    applicationId() {
      return convertToGraphQLId(TYPENAME_CD_APPLICATION, this.id);
    },
    openReleaseId() {
      return this.idFromRoute(RELEASE_PANEL_ROUTE, this.releases);
    },
    selectedReleaseId() {
      return this.openReleaseId ?? this.relatedReleaseId;
    },
    openServiceId() {
      return this.idFromRoute(SERVICE_PANEL_ROUTE, this.services);
    },
    isLoading() {
      return this.$apollo.queries.application.loading;
    },
    servicesLoading() {
      return this.$apollo.queries.services.loading;
    },
    releasesLoading() {
      return this.$apollo.queries.releases.loading;
    },
    deploymentsLoading() {
      return this.$apollo.queries.deployments.loading;
    },
    linksLoading() {
      return this.$apollo.queries.links.loading;
    },
    // Declarative, data-driven section config resolved against current state:
    // each section owns its identity, labels, expand state, and (optionally) the
    // component + props/listeners used to render its body.
    sections() {
      const isExpanded = (key) => Boolean(this.expandedSections[key]);
      return [
        {
          key: 'services',
          title: s__('ContinuousDeployment|Services'),
          expandLabel: s__('ContinuousDeployment|Expand services'),
          collapseLabel: s__('ContinuousDeployment|Collapse services'),
          expanded: isExpanded('services'),
          loading: this.servicesLoading,
          error: this.servicesError,
          errorMessage: s__('ContinuousDeployment|Failed to load services. Reload to try again.'),
          component: ServicesTable,
          contentProps: {
            services: this.services,
            full: isExpanded('services'),
            selectedId: this.openServiceId,
            'data-testid': isExpanded('services')
              ? 'services-expanded-table'
              : 'services-mini-table',
          },
          contentListeners: { select: this.openService },
          pageInfo: this.servicesPageInfo,
          pageSize: this.pagination.services.pageSize,
        },
        {
          key: 'deployments',
          title: s__('ContinuousDeployment|Deployments'),
          expandLabel: s__('ContinuousDeployment|Expand deployments'),
          collapseLabel: s__('ContinuousDeployment|Collapse deployments'),
          expanded: isExpanded('deployments'),
          loading: this.deploymentsLoading,
          error: this.deploymentsError,
          errorMessage: s__(
            'ContinuousDeployment|Failed to load deployments. Reload to try again.',
          ),
          component: DeploymentsTable,
          contentProps: {
            deployments: this.deployments,
            environments: this.deploymentEnvironments,
            full: isExpanded('deployments'),
            selectedId: this.selectedDeploymentId ?? this.preselectedDeploymentId,
            recentId: this.recentDeploymentId,
          },
          contentListeners: { select: this.onDeploymentSelect },
          filterBar: {
            filters: DEPLOYMENT_STATUS_FILTERS,
            selectedFilterId: this.filters.deployments.statusId,
            searchTerm: this.filters.deployments.search,
            searchPlaceholder: s__('ContinuousDeployment|Filter deployments…'),
            searchFirst: true,
          },
          filterListeners: {
            search: (term) => this.onSectionSearch('deployments', term),
            'filter-selected': (id) => this.onSectionFilter('deployments', id),
          },
          pageInfo: this.deploymentsPageInfo,
          pageSize: this.pagination.deployments.pageSize,
          emptyText: this.deployments.length ? '' : this.emptyTextFor('deployments'),
        },
        {
          key: 'releases',
          title: s__('ContinuousDeployment|Releases'),
          expandLabel: s__('ContinuousDeployment|Expand releases'),
          collapseLabel: s__('ContinuousDeployment|Collapse releases'),
          expanded: isExpanded('releases'),
          loading: this.releasesLoading,
          error: this.releasesError,
          errorMessage: s__('ContinuousDeployment|Failed to load releases. Reload to try again.'),
          component: ReleasesTable,
          contentProps: {
            releases: this.releases,
            full: isExpanded('releases'),
            selectedId: this.selectedReleaseId,
            recentId: this.recentReleaseId,
          },
          contentListeners: { select: this.openRelease },
          filterBar: {
            filters: RELEASE_STATUS_FILTERS,
            selectedFilterId: this.filters.releases.statusId,
            searchTerm: this.filters.releases.search,
            searchPlaceholder: s__('ContinuousDeployment|Filter releases…'),
            searchFirst: true,
          },
          filterListeners: {
            search: (term) => this.onSectionSearch('releases', term),
            'filter-selected': (id) => this.onSectionFilter('releases', id),
          },
          pageInfo: this.releasesPageInfo,
          pageSize: this.pagination.releases.pageSize,
          emptyText: this.releases.length ? '' : this.emptyTextFor('releases'),
        },
        {
          key: 'links',
          title: s__('ContinuousDeployment|Links'),
          expandLabel: s__('ContinuousDeployment|Expand links'),
          collapseLabel: s__('ContinuousDeployment|Collapse links'),
          expanded: isExpanded('links'),
          loading: this.linksLoading,
          error: this.linksError,
          errorMessage: s__('ContinuousDeployment|Failed to load links. Reload to try again.'),
          component: ApplicationLinks,
          contentProps: {
            applicationId: this.applicationId,
            links: this.links,
            full: isExpanded('links'),
          },
          contentListeners: {
            expand: this.expandLinks,
            created: this.onLinkCreated,
            updated: this.onLinkUpdated,
            deleted: this.onLinkDeleted,
          },
          pageInfo: this.linksPageInfo,
        },
      ];
    },
    orderedSections() {
      // Expanded sections float to the top; stable sort keeps the rest in order.
      return [...this.sections].sort((a, b) => Number(b.expanded) - Number(a.expanded));
    },
  },
  methods: {
    idFromRoute({ name, param }, items) {
      if (this.$route.name !== name) return null;

      const routeId = this.$route.params[param];
      return items.find((item) => String(getIdFromGraphQLId(item.id)) === routeId)?.id ?? null;
    },
    toggleExpansion(section) {
      const isCollapsing = this.expandedSections[section.key];
      this.expandedSections = {
        ...this.expandedSections,
        [section.key]: !isCollapsing,
      };
      if (isCollapsing) {
        this.resetSectionState(section.key);
      }
    },
    resetSectionState(key) {
      if (this.pagination[key]) {
        this.setPage(key, { pageSize: DEFAULT_PAGE_SIZE[key], after: null, before: null });
      }
      if (DEFAULT_FILTERS[key]) {
        this.filters[key] = { ...DEFAULT_FILTERS[key] };
      }
    },
    openNewRelease() {
      this.$router.push({ name: 'release_new_route', params: { id: this.id } });
    },
    onReleaseCreated(versionSetId) {
      this.recentReleaseId = versionSetId;
      this.expandedSections = { ...this.expandedSections, releases: true };
      this.resetSectionState('releases');
      this.$nextTick(() => {
        this.$apollo.queries.releases.refetch();
      });
      this.closePanel();
    },
    async onDeployTriggered(rolloutId) {
      this.recentDeploymentId = rolloutId ?? null;
      this.expandedSections = { ...this.expandedSections, deployments: true };
      this.resetSectionState('deployments');

      await this.$nextTick();
      this.$apollo.queries.deployments.refetch();
      this.$apollo.queries.releases.refetch();
      this.closePanel();
    },
    onLinkCreated() {
      this.resetSectionState('links');
      this.$nextTick(() => {
        this.$apollo.queries.links.refetch();
      });
    },
    onLinkUpdated() {
      this.$apollo.queries.links.refetch();
    },
    onLinkDeleted() {
      if (this.links.length <= 1 && this.linksPageInfo.hasPreviousPage) {
        this.setPage('links', { after: null, before: this.linksPageInfo.startCursor });
      } else {
        this.$apollo.queries.links.refetch();
      }
    },
    expandLinks() {
      this.expandedSections = { ...this.expandedSections, links: true };
    },
    pageVariables(key) {
      const { pageSize, after, before } = this.pagination[key];
      if (before) {
        return { first: null, after: null, last: pageSize, before };
      }
      return { first: pageSize, after, last: null, before: null };
    },
    setPage(key, changes) {
      this.pagination = {
        ...this.pagination,
        [key]: { ...this.pagination[key], ...changes },
      };
    },
    onSectionNext(section, after) {
      this.setPage(section.key, { after, before: null });
    },
    onSectionPrev(section, before) {
      this.setPage(section.key, { after: null, before });
    },
    onSectionPageSize(section, pageSize) {
      this.setPage(section.key, { pageSize, after: null, before: null });
    },
    openService(service) {
      this.$router.push({
        name: 'service_detail_route',
        params: { id: this.id, serviceId: String(getIdFromGraphQLId(service.id)) },
      });
    },
    openRelease(release) {
      this.recentReleaseId = null;
      this.$router.push({
        name: 'release_detail_route',
        params: { id: this.id, releaseId: String(getIdFromGraphQLId(release.id)) },
      });
    },
    onSectionSearch(key, term) {
      this.filters[key].search = term;
      this.setPage(key, { after: null, before: null });
    },
    onSectionFilter(key, statusId) {
      this.filters[key].statusId = statusId;
      this.setPage(key, { after: null, before: null });
    },
    statusesFor(key) {
      const { statusId } = this.filters[key];
      return statusId === STATUS_ALL ? null : [statusId];
    },
    emptyTextFor(key) {
      const { search, statusId } = this.filters[key];
      const isFiltered = Boolean(search) || statusId !== STATUS_ALL;
      const messages = {
        deployments: {
          filtered: s__('ContinuousDeployment|No deployments match your filter.'),
          empty: s__('ContinuousDeployment|No deployments available.'),
        },
        releases: {
          filtered: s__('ContinuousDeployment|No releases match your filter.'),
          empty: s__('ContinuousDeployment|No releases available.'),
        },
      };
      return isFiltered ? messages[key].filtered : messages[key].empty;
    },
    onDeploymentSelect(deployment) {
      this.selectedDeploymentId = deployment.id;
      this.recentDeploymentId = null;
    },
    onRolloutSelected({ id, versionSetId }) {
      this.preselectedDeploymentId = id;
      this.relatedReleaseId = versionSetId;
    },
    closePanel() {
      this.$router.push({ name: 'applications_show_route', params: { id: this.id } });
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="isLoading" size="lg" class="gl-mt-5" />

    <gl-alert
      v-else-if="hasError"
      variant="danger"
      :dismissible="false"
      class="gl-mt-5"
      data-testid="applications-show-error-alert"
    >
      {{ s__('ContinuousDeployment|Failed to load the application. Please try again later.') }}
    </gl-alert>

    <gl-empty-state
      v-else-if="!application"
      :title="s__('ContinuousDeployment|Application not found')"
      :description="
        s__(
          'ContinuousDeployment|The application may have been removed or you may not have access to it.',
        )
      "
      data-testid="applications-show-empty-state"
    />

    <template v-else>
      <application-header :application="application">
        <template #actions>
          <gl-button variant="confirm" data-testid="new-release-button" @click="openNewRelease">
            {{ s__('ReleaseCreation|Create release') }}
          </gl-button>
        </template>
      </application-header>

      <application-flow
        :application-id="applicationId"
        :selected-deployment-id="selectedDeploymentId"
        class="gl-mt-5"
        @rollout-selected="onRolloutSelected"
      />

      <!-- Expandable overview cards: one flex-wrap container; expanded cards take a
           full row (gl-basis-full), collapsed cards share the row (gl-grow gl-basis-0). -->
      <div class="gl-mt-5 gl-flex gl-flex-wrap gl-gap-4" data-testid="overview-cards">
        <overview-card
          v-for="section in orderedSections"
          :key="section.key"
          :title="section.title"
          :expanded="section.expanded"
          :expand-aria-label="section.expandLabel"
          :collapse-aria-label="section.collapseLabel"
          :loading="Boolean(section.loading)"
          :error="Boolean(section.error)"
          :error-message="section.errorMessage"
          :page-info="section.pageInfo"
          :page-size="section.pageSize"
          :empty-text="section.emptyText"
          :data-testid="section.expanded ? `${section.key}-card-expanded` : `${section.key}-card`"
          @toggle="toggleExpansion(section)"
          @next="onSectionNext(section, $event)"
          @prev="onSectionPrev(section, $event)"
          @page-size-change="onSectionPageSize(section, $event)"
        >
          <template v-if="section.filterBar && section.expanded" #filters>
            <filter-bar v-bind="section.filterBar" class="gl-mb-3" v-on="section.filterListeners" />
          </template>
          <component
            :is="section.component"
            v-if="section.component"
            v-bind="section.contentProps"
            v-on="section.contentListeners"
          />
        </overview-card>
      </div>

      <router-view
        @close="closePanel"
        @created="onReleaseCreated"
        @deploy-triggered="onDeployTriggered"
      />
    </template>
  </div>
</template>
