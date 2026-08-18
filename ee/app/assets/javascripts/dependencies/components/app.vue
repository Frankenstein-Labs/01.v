<script>
import { GlEmptyState, GlLoadingIcon, GlSprintf, GlLink, GlTooltipDirective } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { getTimeago } from '~/lib/utils/datetime_utility';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { NAMESPACE_PROJECT } from '../constants';
import { SORT_FIELD_SEVERITY } from '../store/constants';
import DependenciesActions from './dependencies_actions.vue';
import SbomReportsErrorsAlert from './sbom_reports_errors_alert.vue';
import PaginatedDependenciesTable from './paginated_dependencies_table.vue';
import DependencyExportDropdown from './dependency_export_dropdown.vue';
import { isTrackedRefFilterEnabled, buildDefaultTrackedRefFilter } from './filtered_search/utils';

export default {
  name: 'DependenciesApp',
  components: {
    DependenciesActions,
    GlEmptyState,
    GlLoadingIcon,
    GlSprintf,
    GlLink,
    PaginatedDependenciesTable,
    SbomReportsErrorsAlert,
    HelpIcon,
    DependencyExportDropdown,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    hasDependencies: {},
    emptyStateSvgPath: {},
    documentationPath: {},
    endpoint: {},
    exportEndpoint: {},
    namespaceType: {},
    latestSuccessfulScanPath: {},
    scanFinishedAt: {},
    fullPath: {},
    projectFullPath: {
      default: '',
    },
    defaultBranchContext: {
      default: () => null,
    },
  },
  props: {
    sbomReportsErrors: {
      type: Array,
      required: true,
    },
  },
  computed: {
    ...mapState(['pageInfo', 'initialized']),
    shouldFetchDependenciesViaGraphQL() {
      return this.isProjectNamespace || this.glFeatures.groupDependenciesGraphql;
    },
    showSbomReportsErrors() {
      return this.sbomReportsErrors.length > 0;
    },
    isProjectNamespace() {
      return this.namespaceType === NAMESPACE_PROJECT;
    },
    message() {
      return this.isProjectNamespace
        ? s__(
            'Dependencies|Software Bill of Materials (SBOM) based on the %{linkStart}latest successful%{linkEnd} scan',
          )
        : s__(
            'Dependencies|Software Bill of Materials (SBOM) based on the latest successful scan of each project.',
          );
    },
    generatedAtTimeAgo() {
      return this.scanFinishedAt ? getTimeago().format(this.scanFinishedAt) : '';
    },
  },
  created() {
    this.setFullPath(this.fullPath);
    this.setDependenciesEndpoint(this.endpoint);
    this.setExportDependenciesEndpoint(this.exportEndpoint);
    this.setNamespaceType(this.namespaceType);
    this.setPageInfo(this.pageInfo);
    this.setSortField(SORT_FIELD_SEVERITY);

    if (
      isTrackedRefFilterEnabled({
        glFeatures: this.glFeatures,
        projectFullPath: this.projectFullPath,
        defaultBranchContext: this.defaultBranchContext,
      })
    ) {
      this.setSearchFilterParameters(buildDefaultTrackedRefFilter(this.defaultBranchContext));
    }

    this.fetchInitialDependencies();
  },
  methods: {
    ...mapActions([
      'setDependenciesEndpoint',
      'setExportDependenciesEndpoint',
      'setNamespaceType',
      'setPageInfo',
      'setSortField',
      'setFullPath',
      'setSearchFilterParameters',
      'fetchDependencies',
      'fetchDependenciesViaGraphQL',
    ]),
    fetchInitialDependencies() {
      if (this.shouldFetchDependenciesViaGraphQL) {
        this.fetchDependenciesViaGraphQL();
      } else {
        this.fetchDependencies({ page: 1 });
      }
    },
  },
  i18n: {
    emptyStateTitle: __('View dependency details for your project'),
    emptyStateDescription: __(
      'The dependency list details information about the components used within your project.',
    ),
    emptyStateLinkText: __('More Information'),
  },
};
</script>

<template>
  <gl-loading-icon v-if="!initialized" size="lg" class="!gl-mt-6" />

  <gl-empty-state
    v-else-if="!hasDependencies"
    :title="$options.i18n.emptyStateTitle"
    :svg-path="emptyStateSvgPath"
    :svg-height="null"
    data-testid="dependency-list-empty-state-description-content"
  >
    <template #description>
      {{ $options.i18n.emptyStateDescription }}
      <gl-link target="_blank" :href="documentationPath">
        {{ $options.i18n.emptyStateLinkText }}
      </gl-link>
    </template>
  </gl-empty-state>

  <section v-else>
    <sbom-reports-errors-alert
      v-if="showSbomReportsErrors"
      :errors="sbomReportsErrors"
      class="gl-my-5"
    />

    <header class="gl-my-5 gl-items-start @md/panel:gl-flex">
      <div class="gl-mr-auto">
        <div class="gl-mb-2 gl-flex gl-items-center">
          <h2 class="h4 gl-mb-0 gl-mt-0">
            {{ __('Dependencies') }}
          </h2>
          <gl-link
            class="gl-ml-3"
            target="_blank"
            :href="documentationPath"
            :aria-label="__('Dependencies help page link')"
          >
            <help-icon />
          </gl-link>
        </div>
        <p class="gl-mb-0">
          <gl-sprintf :message="message">
            <template #link="{ content }">
              <gl-link
                v-if="latestSuccessfulScanPath"
                ref="scanLink"
                :href="latestSuccessfulScanPath"
                >{{ content }}
              </gl-link>
              <template v-else>{{ content }}</template>
            </template>
          </gl-sprintf>
          <span v-if="generatedAtTimeAgo" data-testid="time-ago-message">
            <span aria-hidden="true">&bull;</span>
            <span class="gl-text-subtle">{{ generatedAtTimeAgo }}</span>
          </span>
        </p>
      </div>

      <dependency-export-dropdown v-if="exportEndpoint" :container="namespaceType" />
    </header>

    <dependencies-actions class="gl-mt-3" />

    <article>
      <paginated-dependencies-table />
    </article>
  </section>
</template>
