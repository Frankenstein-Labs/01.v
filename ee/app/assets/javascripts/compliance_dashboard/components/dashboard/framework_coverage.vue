<script>
import {
  GlButton,
  GlEmptyState,
  GlKeysetPagination,
  GlProgressBar,
  GlTable,
  GlTooltipDirective,
} from '@gitlab/ui';

import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { ROUTE_NEW_FRAMEWORK, ROUTE_PROJECTS, i18n } from '../../constants';
import FrameworkBadge from '../shared/framework_badge.vue';

export const FRAMEWORKS_PER_PAGE = 20;

export default {
  name: 'FrameworkCoverage',
  components: {
    GlButton,
    GlEmptyState,
    GlKeysetPagination,
    GlProgressBar,
    GlTable,
    FrameworkBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin()],
  props: {
    summary: {
      type: Object,
      required: true,
    },
    isTopLevelGroup: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      page: 0,
      sortBy: 'coverage',
      sortDesc: true,
    };
  },
  computed: {
    canAdminComplianceFramework() {
      return this.glAbilities.adminComplianceFramework;
    },
    tableFields() {
      return [
        {
          key: 'framework',
          label: s__('ComplianceReport|Framework'),
          thClass: 'gl-w-4/12',
        },
        {
          key: 'coverage',
          label: sprintf(s__('ComplianceReport|Project coverage (%%)')),
          sortable: true,
          thClass: 'gl-text-right',
        },
      ];
    },
    allItems() {
      return this.summary.details.map((details) => ({
        framework: details.framework,
        isCentralized: this.isCentralizedFramework(details.framework),
        coveredCount: details.coveredCount,
        totalProjects: this.summary.totalProjects,
        coverage: this.coveragePercent(details),
      }));
    },
    sortedItems() {
      const direction = this.sortDesc ? -1 : 1;
      return this.allItems.toSorted((a, b) => direction * (a.coverage - b.coverage));
    },
    visibleItems() {
      const start = this.page * FRAMEWORKS_PER_PAGE;
      return this.sortedItems.slice(start, start + FRAMEWORKS_PER_PAGE);
    },
    showPagination() {
      return this.allItems.length > FRAMEWORKS_PER_PAGE;
    },
    hasPreviousPage() {
      return this.page > 0;
    },
    hasNextPage() {
      return (this.page + 1) * FRAMEWORKS_PER_PAGE < this.allItems.length;
    },
  },
  methods: {
    isCentralizedFramework(framework) {
      const frameworkNamespaceId = getIdFromGraphQLId(framework.namespaceId);
      const groupId = getIdFromGraphQLId(this.summary.groupId);

      return frameworkNamespaceId !== groupId;
    },
    coveragePercent(item) {
      if (!this.summary.totalProjects) {
        return 0;
      }

      return Math.round((item.coveredCount / this.summary.totalProjects) * 100);
    },
    coverageTooltip(item) {
      return sprintf(s__('ComplianceReport|%{coveredCount}/%{totalProjects} projects covered'), {
        coveredCount: item.coveredCount,
        totalProjects: item.totalProjects,
      });
    },
    handleSortChanged({ sortBy, sortDesc }) {
      this.sortBy = sortBy;
      this.sortDesc = sortDesc;
      this.page = 0;
    },
    handleRowClicked() {
      this.$router.push({ name: ROUTE_PROJECTS });
    },
    newFramework() {
      this.$router.push({ name: ROUTE_NEW_FRAMEWORK });
    },
  },
  i18n,
};
</script>
<template>
  <div v-if="summary.details.length">
    <gl-table
      :fields="tableFields"
      :items="visibleItems"
      stacked="md"
      no-local-sorting
      :sort-by="sortBy"
      :sort-desc="sortDesc"
      @sort-changed="handleSortChanged"
      @row-clicked="handleRowClicked"
    >
      <template #cell(framework)="{ item }">
        <framework-badge :framework="item.framework" popover-mode="hidden" />
        <span v-if="item.isCentralized">{{ s__('ComplianceReport|(CSP)') }}</span>
      </template>
      <template #cell(coverage)="{ item }">
        <div class="gl-flex gl-items-center gl-gap-6">
          <gl-progress-bar
            class="gl-grow"
            :value="item.coveredCount"
            :max="item.totalProjects || 1"
          />
          <span v-gl-tooltip :title="coverageTooltip(item)" class="gl-whitespace-nowrap">
            {{ item.coverage }}%
          </span>
        </div>
      </template>
    </gl-table>
    <div v-if="showPagination" class="gl-mt-5 gl-flex gl-justify-center">
      <gl-keyset-pagination
        :has-previous-page="hasPreviousPage"
        :has-next-page="hasNextPage"
        @prev="page -= 1"
        @next="page += 1"
      />
    </div>
  </div>
  <gl-empty-state
    v-else
    :title="s__('ComplianceReport|There are no compliance frameworks.')"
    :description="s__('ComplianceReport|Start by adding a compliance framework to your group.')"
    class="gl-m-0 gl-pt-3"
  >
    <template #actions>
      <gl-button
        v-if="canAdminComplianceFramework && isTopLevelGroup"
        category="primary"
        variant="confirm"
        @click="newFramework"
      >
        {{ $options.i18n.newFramework }}
      </gl-button>
    </template>
  </gl-empty-state>
</template>
