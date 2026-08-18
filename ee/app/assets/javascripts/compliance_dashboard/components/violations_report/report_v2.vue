<script>
import {
  GlAlert,
  GlLoadingIcon,
  GlTable,
  GlLink,
  GlKeysetPagination,
  GlToastMixin,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__, sprintf } from '~/locale';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { LONG_DATE_FORMAT_WITH_TZ } from '~/vue_shared/constants';
import { ComplianceViolationStatusDropdown } from 'ee/vue_shared/compliance';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import ComplianceFrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';
import groupComplianceViolationsQuery from 'ee/compliance_violations/graphql/compliance_violations.query.graphql';
import updateProjectComplianceViolation from 'ee/compliance_violations/graphql/mutations/update_project_compliance_violation.mutation.graphql';
import complianceRequirementControlsQuery from 'ee/compliance_dashboard/graphql/compliance_requirement_controls.query.graphql';
import { humanize } from '~/lib/utils/text_utility';
import { statusesInfo } from '../standards_adherence_report/components/details_drawer/statuses_info';
import FiltersBar from './components/filters_bar.vue';

export const VIOLATION_PAGE_SIZE = 20;

export default {
  name: 'ComplianceViolationsReportV2',
  components: {
    GlAlert,
    GlLoadingIcon,
    GlTable,
    GlLink,
    GlKeysetPagination,
    ComplianceViolationStatusDropdown,
    ComplianceFrameworkBadge,
    FiltersBar,
  },
  mixins: [GlToastMixin],
  props: {
    groupPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      queryError: false,
      violations: { nodes: [] },
      isStatusUpdating: false,
      filters: {},
      cursor: {
        before: null,
        after: null,
      },
      controlDefinitions: [],
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.violations.loading;
    },
    emptyText() {
      return this.$options.i18n.noViolationsFound;
    },
    graphqlFilters() {
      const { projectId, controlId, status, createdAfter, createdBefore } = this.filters;
      const filters = {
        ...(projectId && { projectId }),
        ...(controlId && { controlId }),
        ...(status && { status: [status] }),
        ...(createdAfter && { createdAfter }),
        ...(createdBefore && { createdBefore }),
      };
      return Object.keys(filters).length > 0 ? filters : undefined;
    },
  },
  methods: {
    handleFiltersChange(newFilters) {
      this.filters = newFilters;
      this.cursor = {
        before: null,
        after: null,
      };
    },

    onPrevPage() {
      this.cursor = {
        before: this.violations.pageInfo.startCursor,
        after: null,
      };
    },

    onNextPage() {
      this.cursor = {
        after: this.violations.pageInfo.endCursor,
        before: null,
      };
    },

    async handleStatusChange(newStatus, violation) {
      this.isStatusUpdating = true;
      try {
        const result = await this.$apollo.mutate({
          mutation: updateProjectComplianceViolation,
          variables: {
            input: {
              id: violation.id,
              status: newStatus.toUpperCase(),
            },
          },
        });

        if (result.data?.updateProjectComplianceViolation?.errors?.length > 0) {
          throw new Error(result.data.updateProjectComplianceViolation.errors.join(', '));
        }

        this.$toast.show(this.$options.i18n.statusUpdateSuccess, {
          variant: 'success',
        });
      } catch (error) {
        this.$toast.show(this.$options.i18n.statusUpdateError, {
          variant: 'danger',
        });
      } finally {
        this.isStatusUpdating = false;
      }
    },
    getFormattedDate(dateString) {
      return formatDate(dateString, LONG_DATE_FORMAT_WITH_TZ, true);
    },
    getViolationDetailsPath(violation) {
      if (!violation || !violation.id) {
        return '#';
      }

      if (!violation.project) {
        return '#';
      }

      const projectPath = violation.project.fullPath || violation.project.path_with_namespace;
      if (!projectPath) {
        return '#';
      }

      try {
        const violationId = getIdFromGraphQLId(violation.id);
        if (!violationId) {
          return '#';
        }

        return `/${projectPath}/-/security/compliance_violations/${violationId}`;
      } catch (error) {
        return '#';
      }
    },
    getProjectPath(project) {
      if (!project) {
        return '#';
      }

      const projectPath = project.fullPath || project.path_with_namespace;
      if (!projectPath) {
        return '#';
      }

      return `/${projectPath}`;
    },
    parseCustomMessage(details) {
      if (!details) return null;
      if (typeof details === 'string') {
        try {
          const parsed = JSON.parse(details);
          return parsed.custom_message || null;
        } catch (error) {
          return null;
        }
      }

      return null;
    },
    getAuditEventTitle(auditEvent) {
      if (!auditEvent) {
        return '';
      }

      const { targetDetails, eventName } = auditEvent || {};
      const customMessage = this.parseCustomMessage(auditEvent?.details) || '';

      if (targetDetails || customMessage || eventName) {
        return `${targetDetails} : ${customMessage || eventName}`;
      }

      return this.$options.i18n.auditEventGeneric;
    },
    getAuditEventAuthor(auditEvent) {
      if (!auditEvent) {
        return '';
      }

      const name = auditEvent.author?.name || auditEvent.author?.username;

      if (name) {
        return sprintf(this.$options.i18n.auditEventAuthor, { name });
      }

      return this.$options.i18n.auditEventUnknownAuthor;
    },
    getComplianceControlTitle(control) {
      if (!control || !control.name || control.name === '') {
        return this.$options.i18n.invalidControl;
      }

      // First try statusesInfo for standards adherence display names
      const statusInfo = statusesInfo[control.name];
      if (statusInfo?.title) {
        return statusInfo.title;
      }

      // Use externalControlName if available
      if (control.externalControlName) {
        return control.externalControlName;
      }

      // Try to find the control definition with proper display name
      const definition = this.controlDefinitions.find((def) => def.id === control.name);
      if (definition?.name) {
        return definition.name;
      }

      // Fallback: format the control name for better readability
      return humanize(control.name);
    },
  },
  apollo: {
    violations: {
      query: groupComplianceViolationsQuery,
      variables() {
        return {
          fullPath: this.groupPath,
          ...this.cursor,
          [this.cursor.before ? 'last' : 'first']: VIOLATION_PAGE_SIZE,
          filters: this.graphqlFilters,
        };
      },
      update(data) {
        return data?.group?.projectComplianceViolations;
      },
      error(e) {
        Sentry.captureException(e);
        this.queryError = true;
      },
    },
    controlDefinitions: {
      query: complianceRequirementControlsQuery,
      update: (data) => data.complianceRequirementControls.controlExpressions || [],
    },
  },
  fields: [
    {
      key: 'status',
      label: s__('ComplianceReport|Status'),
      thClass: 'gl-w-1/7 !gl-p-5',
      tdClass: '!gl-align-top',
      sortable: true,
    },
    {
      key: 'complianceControl',
      label: s__('ComplianceReport|Violated control and framework'),
      thClass: 'gl-w-1/5 !gl-p-5',
      tdClass: '!gl-align-top',
      sortable: true,
    },
    {
      key: 'auditEvent',
      label: s__('ComplianceReport|Audit Event'),
      thClass: 'gl-w-1/3 !gl-p-5',
      tdClass: '!gl-align-top',
      sortable: false,
    },
    {
      key: 'project',
      label: __('Project'),
      thClass: 'gl-w-1/6 !gl-p-5',
      tdClass: '!gl-align-top',
      sortable: true,
    },
    {
      key: 'createdAt',
      label: s__('ComplianceReport|Date detected'),
      thClass: 'gl-w-1/8 !gl-p-5',
      tdClass: '!gl-align-top',
      sortable: true,
    },
    {
      key: 'actions',
      label: s__('ComplianceReport|Action'),
      thClass: 'gl-w-1/8 !gl-p-5',
      tdClass: '!gl-align-top',
      sortable: false,
    },
  ],
  i18n: {
    queryError: s__(
      'ComplianceReport|Unable to load the compliance violations report. Refresh the page and try again.',
    ),
    noViolationsFound: s__('ComplianceReport|No violations found'),
    statusUpdateError: s__('ComplianceReport|Failed to update violation status. Please try again.'),
    statusUpdateSuccess: s__('ComplianceReport|Violation status updated successfully.'),
    viewDetails: s__('ComplianceReport|Details'),
    changeStatus: s__('ComplianceReport|Change status'),
    noAuditEvent: s__('ComplianceReport|No audit event available'),
    auditEventGeneric: s__('ComplianceReport|Generic Audit event'),
    auditEventAuthor: s__('ComplianceReport|By %{name}'),
    auditEventUnknownAuthor: s__('ComplianceReport|Unknown author'),
    invalidControl: s__('ComplianceReport|Invalid control'),
  },
};
</script>

<template>
  <section class="gl-flex gl-flex-col">
    <gl-alert v-if="queryError" variant="danger" class="gl-mt-3" :dismissible="false">
      {{ $options.i18n.queryError }}
    </gl-alert>

    <filters-bar :group-path="groupPath" class="gl-mb-5" @update:filters="handleFiltersChange" />

    <gl-table
      ref="table"
      :fields="$options.fields"
      :items="violations.nodes"
      :busy="isLoading"
      :empty-text="emptyText"
      show-empty
      stacked="lg"
      hover
      class="compliance-violations-table"
    >
      <template #cell(status)="{ item }">
        <div class="" data-testid="compliance-violation-status">
          <compliance-violation-status-dropdown
            class="gl-align-baseline"
            :value="item.status.toLowerCase()"
            :loading="isStatusUpdating"
            @change="(newStatus) => handleStatusChange(newStatus, item)"
          />
        </div>
      </template>

      <template #cell(complianceControl)="{ item }">
        <div class="gl-font-weight-semibold gl-mb-2">
          {{ getComplianceControlTitle(item.complianceControl) }}
        </div>
        <compliance-framework-badge
          v-if="
            item.complianceControl &&
            item.complianceControl.complianceRequirement &&
            item.complianceControl.complianceRequirement.framework
          "
          :framework="item.complianceControl.complianceRequirement.framework"
          popover-mode="details"
        />
      </template>

      <template #cell(auditEvent)="{ item }">
        <div v-if="item.auditEvent">
          <div class="gl-font-weight-semibold gl-mb-2">
            {{ getAuditEventTitle(item.auditEvent) }}
          </div>
          <div class="gl-text-sm gl-text-subtle">
            {{ getAuditEventAuthor(item.auditEvent) }}
          </div>
        </div>
        <div v-else class="gl-text-sm gl-text-subtle">
          {{ $options.i18n.noAuditEvent }}
        </div>
      </template>

      <template #cell(project)="{ item }">
        <gl-link :href="getProjectPath(item.project)" class="gl-font-weight-semibold">
          {{ item.project.name }}
        </gl-link>
      </template>

      <template #cell(createdAt)="{ item }">
        {{ getFormattedDate(item.createdAt) }}
      </template>

      <template #cell(actions)="{ item }">
        <gl-link class="gl-cursor-pointer gl-text-blue-500" :href="getViolationDetailsPath(item)">
          {{ $options.i18n.viewDetails }}
        </gl-link>
      </template>

      <template #table-busy>
        <gl-loading-icon size="lg" color="dark" class="gl-my-5" />
      </template>
    </gl-table>

    <gl-keyset-pagination
      v-bind="violations.pageInfo"
      class="gl-mt-7 gl-self-center"
      @prev="onPrevPage"
      @next="onNextPage"
    />
  </section>
</template>
