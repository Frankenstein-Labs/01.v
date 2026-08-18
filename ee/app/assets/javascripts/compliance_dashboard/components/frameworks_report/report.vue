<script>
import { GlAlert, GlLink, GlSprintf, GlKeysetPagination, GlToastMixin } from '@gitlab/ui';
import { uniqBy } from 'lodash-es';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { fetchPolicies } from '~/lib/graphql';
import { s__ } from '~/locale';
import { convertToSnakeCase } from '~/lib/utils/text_utility';

import { createAlert } from '~/alert';
import { mergeAdditionalPolicies } from '../../utils';
import deleteComplianceFrameworkMutation from '../../graphql/mutations/delete_compliance_framework.mutation.graphql';
import complianceFrameworksGroupList from './graphql/compliance_frameworks_group_list.query.graphql';
import complianceFrameworksProjectList from './graphql/compliance_frameworks_project_list.query.graphql';
import complianceFrameworkPoliciesQuery from './wizard/graphql/compliance_frameworks_policies.query.graphql';

import FrameworksTable from './frameworks_table.vue';

const FRAMEWORK_LIMIT = 20;

export default {
  name: 'ComplianceFrameworksReport',
  components: {
    GlAlert,
    GlLink,
    GlKeysetPagination,
    GlSprintf,
    FrameworksTable,
  },
  mixins: [GlToastMixin],
  inject: {
    migratePipelineToPolicyPath: {
      type: String,
      default: '#',
    },
    pipelineExecutionPolicyPath: {
      type: String,
      required: false,
      default: '#',
    },
  },
  props: {
    rootAncestor: {
      type: Object,
      required: true,
    },
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
  },

  data() {
    return {
      hasQueryError: false,
      frameworks: { nodes: [] },
      additionalPoliciesByFramework: {},
      searchString: '',
      maintenanceModeDismissed: false,
      cursor: {
        before: null,
        after: null,
      },
      sortKey: 'UPDATED_AT_DESC',
      namespaceId: null,
    };
  },
  apollo: {
    frameworks: {
      query() {
        return this.projectPath ? complianceFrameworksProjectList : complianceFrameworksGroupList;
      },
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      variables() {
        return {
          fullPath: this.projectPath ?? this.groupPath,
          search: this.searchString,
          ...this.cursor,
          [this.cursor.before ? 'last' : 'first']: FRAMEWORK_LIMIT,
          sort: this.sortKey,
        };
      },
      update(data) {
        this.namespaceId = data.namespace.id;

        return data.namespace.complianceFrameworks;
      },
      error(e) {
        Sentry.captureException(e);
        this.hasQueryError = true;
      },
    },
  },
  computed: {
    isLoading() {
      return Boolean(this.$apollo.queries.frameworks.loading);
    },
    frameworksWithPolicies() {
      return this.frameworks.nodes.map((framework) =>
        mergeAdditionalPolicies(framework, this.additionalPoliciesByFramework[framework.id]),
      );
    },
    showMaintenanceModeAlert() {
      return !this.maintenanceModeDismissed;
    },
  },
  methods: {
    onPrevPage() {
      this.additionalPoliciesByFramework = {};
      this.cursor = {
        before: this.frameworks.pageInfo.startCursor,
        after: null,
      };
    },

    onNextPage() {
      this.additionalPoliciesByFramework = {};
      this.cursor = {
        after: this.frameworks.pageInfo.endCursor,
        before: null,
      };
    },

    onSearch(searchString) {
      this.cursor = {
        before: null,
        after: null,
      };
      this.searchString = searchString;
    },
    onSortChanged({ sortBy, sortDesc }) {
      const sortDir = sortDesc ? 'desc' : 'asc';
      this.sortKey = `${convertToSnakeCase(sortBy)}_${sortDir}`.toUpperCase();
    },
    handleOnDismissMaintenanceMode() {
      this.maintenanceModeDismissed = true;
    },
    async loadMorePolicies({ frameworkId, after }) {
      try {
        const { data } = await this.$apollo.query({
          query: complianceFrameworkPoliciesQuery,
          variables: {
            fullPath: this.groupPath ?? this.projectPath,
            complianceFramework: frameworkId,
            after,
          },
        });
        const { nodes, pageInfo } = data.namespace.complianceFrameworks.nodes[0].securityPolicies;
        const existing = this.additionalPoliciesByFramework[frameworkId];
        this.additionalPoliciesByFramework = {
          ...this.additionalPoliciesByFramework,
          [frameworkId]: {
            nodes: uniqBy([...(existing?.nodes ?? []), ...nodes], (p) => `${p.type}:${p.name}`),
            pageInfo,
          },
        };
      } catch (error) {
        createAlert({ message: error, captureError: true, error });
      }
    },
    async refreshFrameworks() {
      try {
        return await this.$apollo.queries.frameworks.refetch();
      } catch (error) {
        createAlert({ message: error, captureError: true, error });
        return null;
      }
    },
    async deleteFramework(id) {
      try {
        const {
          data: { destroyComplianceFramework },
        } = await this.$apollo.mutate({
          mutation: deleteComplianceFrameworkMutation,
          variables: {
            input: {
              id,
            },
          },
        });

        const [error] = destroyComplianceFramework.errors;

        if (error) {
          throw error;
        } else {
          this.refreshFrameworks();
          this.$toast.show(s__('Compliance|Framework deleted successfully'));
        }
      } catch (error) {
        createAlert({ message: error, captureError: true, error });
      }
    },
  },
  i18n: {
    deprecationWarning: {
      title: s__('ComplianceReport|Compliance pipelines are deprecated'),
      message: s__(
        'ComplianceReport|Avoid creating new compliance pipelines and use pipeline execution policies instead. %{linkStart}Pipeline execution policies%{linkEnd} provide the ability to enforce CI/CD jobs, execute security scans, and better manage compliance enforcement in pipelines.',
      ),
      details: s__(
        'ComplianceReport|For more information, see %{linkStart}how to migrate from compliance pipelines to pipeline execution policy actions%{linkEnd}.',
      ),
    },
    queryError: s__(
      'ComplianceReport|Unable to load the compliance framework report. Refresh the page and try again.',
    ),
  },
};
</script>

<template>
  <section class="gl-flex gl-flex-col">
    <gl-alert
      v-if="showMaintenanceModeAlert"
      variant="warning"
      class="gl-my-3"
      data-testid="maintenance-mode-alert"
      :dismissible="true"
      :title="$options.i18n.deprecationWarning.title"
      @dismiss="handleOnDismissMaintenanceMode"
    >
      <p>
        <gl-sprintf :message="$options.i18n.deprecationWarning.message">
          <template #link="{ content }">
            <gl-link :href="pipelineExecutionPolicyPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>

      <gl-sprintf :message="$options.i18n.deprecationWarning.details">
        <template #link="{ content }">
          <gl-link :href="migratePipelineToPolicyPath" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>

    <gl-alert
      v-if="hasQueryError"
      variant="danger"
      class="gl-my-3"
      :dismissible="false"
      data-testid="query-error-alert"
    >
      {{ $options.i18n.queryError }}
    </gl-alert>

    <template v-else>
      <frameworks-table
        :root-ancestor="rootAncestor"
        :group-path="groupPath"
        :project-path="projectPath"
        :is-loading="isLoading"
        :frameworks="frameworksWithPolicies"
        :namespace-id="namespaceId"
        @search="onSearch"
        @sort-changed="onSortChanged"
        @delete-framework="deleteFramework"
        @update-frameworks="refreshFrameworks"
        @load-more-policies="loadMorePolicies"
      />

      <gl-keyset-pagination
        v-bind="frameworks.pageInfo"
        class="gl-mt-6 gl-self-center"
        @prev="onPrevPage"
        @next="onNextPage"
      />
    </template>
  </section>
</template>
