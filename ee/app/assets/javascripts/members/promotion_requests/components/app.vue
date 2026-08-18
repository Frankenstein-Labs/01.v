<script>
import { GlLink, GlSprintf, GlTable, GlKeysetPagination, GlAlert } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __, s__ } from '~/locale';
import UserDate from '~/vue_shared/components/user_date.vue';
import { CONTEXT_TYPE } from '~/members/constants';
import { DEFAULT_PER_PAGE } from '~/api';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ProjectPendingMemberApprovalsQuery from '../graphql/project_pending_member_approvals.query.graphql';
import GroupPendingMemberApprovalsQuery from '../graphql/group_pending_member_approvals.query.graphql';
import UserAvatar from './user_avatar.vue';

const FIELDS = [
  {
    key: 'user',
    label: __('User'),
  },
  {
    key: 'requested_role',
    label: s__('Members|Requested Role'),
    tdClass: '!gl-align-middle',
  },
  {
    key: 'requested_by',
    label: s__('Members|Requested By'),
    tdClass: '!gl-align-middle',
  },
  {
    key: 'requested_on',
    label: s__('Members|Requested On'),
    tdClass: '!gl-align-middle',
  },
];

export default {
  name: 'PromotionRequestsTabApp',
  components: {
    GlTable,
    GlKeysetPagination,
    GlAlert,
    UserAvatar,
    UserDate,
    GlLink,
    GlSprintf,
  },
  inject: ['context', 'group', 'project'],
  data() {
    return {
      isLoading: true,
      error: null,
      pendingMemberApprovals: {},
      cursor: {
        first: DEFAULT_PER_PAGE,
        last: null,
        after: null,
        before: null,
      },
    };
  },
  apollo: {
    // NOTE: Promotion requests may exist in two different contexts: group and project member
    // management pages. Pending promotions data interface is the same for both contexts, but the
    // queries are different.
    pendingMemberApprovals: {
      query() {
        return this.context === CONTEXT_TYPE.GROUP
          ? GroupPendingMemberApprovalsQuery
          : ProjectPendingMemberApprovalsQuery;
      },
      variables() {
        const fullPath = this.context === CONTEXT_TYPE.GROUP ? this.group.path : this.project.path;
        return {
          ...this.cursor,
          fullPath,
        };
      },
      update(data) {
        return this.context === CONTEXT_TYPE.GROUP
          ? data.group.pendingMemberApprovals
          : data.project.pendingMemberApprovals;
      },
      error(error) {
        this.isLoading = false;
        this.error = s__(
          'PromotionRequests|An error occurred while loading promotion requests. Reload the page to try again.',
        );
        Sentry.captureException({ error, component: this.$options.name });
      },
      result() {
        this.isLoading = false;
      },
    },
  },
  methods: {
    onPrev(before) {
      this.isLoading = true;
      this.cursor = {
        first: DEFAULT_PER_PAGE,
        last: null,
        before,
      };
    },
    onNext(after) {
      this.isLoading = true;
      this.cursor = {
        first: null,
        last: DEFAULT_PER_PAGE,
        after,
      };
    },
  },
  helpDocsPath: helpPagePath('/administration/settings/sign_up_restrictions', {
    anchor: 'turn-on-administrator-approval-for-role-promotions',
  }),
  description: s__(
    'Members|Role promotions must be approved by an administrator. This setting can be changed in the Admin area. %{linkStart}Learn more%{linkEnd}.',
  ),
  FIELDS,
};
</script>
<template>
  <div>
    <gl-alert
      v-if="error"
      variant="danger"
      sticky
      :dismissible="false"
      class="gl-top-10 gl-z-1 gl-my-4"
      >{{ error }}</gl-alert
    >
    <gl-table
      :busy="isLoading"
      :items="pendingMemberApprovals.nodes"
      :fields="$options.FIELDS"
      caption-top
    >
      <template #table-caption>
        <div class="gl-mt-3" data-testid="description">
          <gl-sprintf :message="$options.description">
            <template #link="{ content }">
              <gl-link :href="$options.helpDocsPath" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </div>
      </template>
      <template #cell(user)="{ item }">
        <user-avatar :user="item.user" />
      </template>
      <template #cell(requested_role)="{ item }">
        {{ item.newAccessLevel.stringValue }}
      </template>
      <template #cell(requested_by)="{ item }">
        <a :href="item.requestedBy.webUrl">{{ item.requestedBy.name }}</a>
      </template>
      <template #cell(requested_on)="{ item }">
        <user-date :date="item.createdAt" />
      </template>
    </gl-table>
    <div class="gl-mt-4 gl-flex gl-flex-col gl-items-center">
      <gl-keyset-pagination
        v-bind="pendingMemberApprovals.pageInfo"
        :disabled="isLoading"
        @prev="onPrev"
        @next="onNext"
      />
    </div>
  </div>
</template>
