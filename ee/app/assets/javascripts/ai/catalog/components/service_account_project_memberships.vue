<script>
import {
  GlIcon,
  GlLink,
  GlKeysetPagination,
  GlTable,
  GlTooltipDirective,
  GlLoadingIcon,
} from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import { fetchPolicies } from '~/lib/graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__ } from '~/locale';
import DynamicPanel from '~/vue_shared/components/dynamic_panel.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { PAGE_SIZE } from '../constants';
import serviceAccountProjectMembershipsQuery from '../graphql/queries/service_account_project_memberships.query.graphql';
import ServiceAccountAvatar from './service_account_avatar.vue';

export default {
  name: 'ServiceAccountProjectMemberships',
  components: {
    GlIcon,
    GlLink,
    GlKeysetPagination,
    GlTable,
    GlLoadingIcon,
    DynamicPanel,
    ErrorsAlert,
    MountingPortal,
    ServiceAccountAvatar,
    UserDate,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    serviceAccount: {
      type: Object,
      required: true,
    },
    isOpen: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['close'],
  apollo: {
    projectMemberships: {
      query: serviceAccountProjectMembershipsQuery,
      skip() {
        return !this.isOpen;
      },
      variables() {
        return {
          userId: this.serviceAccount.id,
          first: PAGE_SIZE,
          after: null,
          before: null,
          last: null,
        };
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => data?.user?.projectMemberships?.nodes ?? [],
      result({ data }) {
        this.pageInfo = data?.user?.projectMemberships?.pageInfo;
      },
      error(error) {
        this.handleError(error);
      },
    },
  },
  data() {
    return {
      projectMemberships: [],
      errors: [],
      pageInfo: null,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.projectMemberships.loading;
    },
  },
  methods: {
    handleClose() {
      this.$emit('close');
    },
    handleError(error) {
      this.errors = [this.$options.errorMessage];
      Sentry.captureException(error);
    },
    handleNextPage() {
      this.$apollo.queries.projectMemberships
        .refetch({
          ...this.$apollo.queries.projectMemberships.variables,
          before: null,
          after: this.pageInfo.endCursor,
          first: PAGE_SIZE,
          last: null,
        })
        .catch((error) => {
          this.handleError(error);
        });
    },
    handlePrevPage() {
      this.$apollo.queries.projectMemberships
        .refetch({
          ...this.$apollo.queries.projectMemberships.variables,
          after: null,
          before: this.pageInfo.startCursor,
          first: null,
          last: PAGE_SIZE,
        })
        .catch((error) => {
          this.handleError(error);
        });
    },
  },
  fields: [
    {
      key: 'project',
      label: __('Name'),
      isRowHeader: true,
    },
    {
      key: 'accessLevel.humanAccess',
      label: s__('AICatalog|Access level'),
      isRowHeader: true,
      class: 'gl-whitespace-nowrap',
    },
    {
      key: 'createdAt',
      label: __('Activity'),
      isRowHeader: true,
      thAlignRight: true,
    },
  ],
  errorMessage: s__('AICatalog|Failed to load project memberships. Please try again.'),
};
</script>

<template>
  <mounting-portal v-if="isOpen" mount-to="#contextual-panel-portal" append>
    <dynamic-panel @close="handleClose">
      <template #header>
        <h2 class="panel-header-inner-text gl-my-0">
          {{ s__('AICatalog|Projects using this service account') }}
        </h2>
      </template>
      <service-account-avatar :service-account="serviceAccount" class="gl-mt-2" />
      <p class="gl-mt-4 gl-text-subtle">
        {{
          s__(
            'AICatalog|Only projects you can view are displayed. Members of the top-level group with at least the Maintainer role can view all projects.',
          )
        }}
      </p>
      <errors-alert :errors="errors" @dismiss="errors = []" />
      <gl-table
        :fields="$options.fields"
        :items="projectMemberships"
        :busy="isLoading"
        stacked="md"
        show-empty
      >
        <template #empty>
          {{
            s__(
              "AICatalog|This service account has no associated projects you can view. It might be used in projects that you can't view.",
            )
          }}
        </template>
        <template #cell(project)="{ item: { project } }">
          <gl-link :href="project.webUrl">
            {{ project.nameWithNamespace }}
          </gl-link>
        </template>
        <template #cell(createdAt)="{ item: { createdAt } }">
          <div class="gl-flex gl-justify-end gl-gap-3">
            <gl-icon
              v-gl-tooltip
              class="-gl-mr-2 gl-ml-2 gl-shrink-0 gl-text-subtle"
              name="assignee"
              :title="s__('AICatalog|Service account created')"
            />
            <user-date :date="serviceAccount.createdAt" class="gl-whitespace-nowrap" />
          </div>
          <div class="gl-flex gl-justify-end gl-gap-3">
            <gl-icon
              v-gl-tooltip
              class="gl-shrink-0 gl-text-subtle"
              name="check"
              :title="s__('AICatalog|Access granted')"
            />
            <user-date :date="createdAt" class="gl-whitespace-nowrap" />
          </div>
        </template>
        <template #table-busy>
          <gl-loading-icon size="lg" class="gl-my-5" />
        </template>
      </gl-table>
      <gl-keyset-pagination
        v-if="pageInfo && !isLoading"
        v-bind="pageInfo"
        class="gl-my-6 gl-flex gl-justify-center"
        @prev="handlePrevPage"
        @next="handleNextPage"
      />
    </dynamic-panel>
  </mounting-portal>
</template>
