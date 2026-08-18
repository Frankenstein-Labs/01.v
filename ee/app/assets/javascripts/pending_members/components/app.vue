<script>
import {
  GlAlert,
  GlAvatarLabeled,
  GlAvatarLink,
  GlBadge,
  GlButton,
  GlEmptyState,
  GlKeysetPagination,
  GlModal,
  GlModalDirective,
  GlLoadingIcon,
} from '@gitlab/ui';
import EmptyTodosSvg from '@gitlab/svgs/dist/illustrations/empty-todos-md.svg';
import { n__, sprintf } from '~/locale';
import { AVATAR_SIZE } from 'ee/usage_quotas/seats/constants';
import {
  PENDING_MEMBERS_TITLE,
  AWAITING_MEMBER_SIGNUP_TEXT,
  LABEL_APPROVE,
  LABEL_APPROVE_ALL,
  LABEL_CONFIRM,
  LABEL_CONFIRM_APPROVE,
  PENDING_MEMBERS_LIST_ERROR,
  APPROVAL_ERROR_MESSAGE,
  APPROVAL_SUCCESSFUL_MESSAGE,
  PER_PAGE,
  ALL_MEMBERS_APPROVAL_SUCCESSFUL_MESSAGE,
  ALL_MEMBERS_APPROVAL_ERROR_MESSAGE,
} from 'ee/pending_members/constants';
import pendingMembersQuery from './pending_members.query.graphql';
import approvePendingGroupMemberMutation from './approve_pending_member.mutation.graphql';
import approveAllPendingGroupMembersMutation from './approve_all_pending_members.mutation.graphql';

export default {
  name: 'PendingMembersApp',
  components: {
    GlAlert,
    GlAvatarLabeled,
    GlAvatarLink,
    GlBadge,
    GlButton,
    GlEmptyState,
    GlKeysetPagination,
    GlModal,
    GlLoadingIcon,
  },
  directives: {
    GlModalDirective,
  },
  i18n: {
    labelConfirmApprove: (count) =>
      n__('Approve a pending member', 'Approve %d pending members', count),
    labelConfirmApproveAll: (count) =>
      n__(
        'Approved members will use an additional seat in your subscription.',
        'Approved members will use an additional %d seats in your subscription.',
        count,
      ),
    labelConfirmApproveAllWithUserCapSet: (count) =>
      n__(
        'Approved members will use an additional seat in your subscription, which may override your user cap.',
        'Approved members will use an additional %d seats in your subscription, which may override your user cap.',
        count,
      ),
  },
  inject: ['namespacePath', 'namespaceId', 'userCapSet'],
  data() {
    return {
      hasError: false,
      alertMessage: null,
      alertVariant: null,
      approveAllMembersLoading: false,
      rawPendingMembers: { nodes: [] },
      loadingPendingMembers: [],
      cursor: {
        first: PER_PAGE,
        after: null,
      },
    };
  },
  apollo: {
    rawPendingMembers: {
      query: pendingMembersQuery,
      variables() {
        return {
          groupPath: this.namespacePath,
          ...this.cursor,
        };
      },
      update(data) {
        const pendingMembers = data?.group?.pendingMembers;

        return {
          nodes: pendingMembers?.nodes || [],
          pageInfo: pendingMembers?.pageInfo || {},
        };
      },
      error() {
        this.hasError = true;
        this.alertMessage = PENDING_MEMBERS_LIST_ERROR;
        this.alertVariant = 'danger';
      },
    },
  },
  computed: {
    showPagination() {
      return (
        this.pendingMembersPageInfo?.hasPreviousPage || this.pendingMembersPageInfo?.hasNextPage
      );
    },
    approveAllPopoverTitle() {
      return this.$options.i18n.labelConfirmApprove(this.total);
    },
    approveAllPopoverBody() {
      if (this.userCapSet) {
        return this.$options.i18n.labelConfirmApproveAllWithUserCapSet(this.total);
      }
      return this.$options.i18n.labelConfirmApproveAll(this.total);
    },
    pendingMembers() {
      return this.rawPendingMembers.nodes
        .map((member) => {
          return {
            ...member,
            loading: this.loadingPendingMembers.includes(member.id),
          };
        })
        .filter((member) => member.invited || !member.approved);
    },
    total() {
      return this.pendingMembers.length;
    },
    isLoading() {
      return this.$apollo.queries.rawPendingMembers.loading;
    },
    pendingMembersPageInfo() {
      return this.rawPendingMembers?.pageInfo;
    },
  },
  methods: {
    avatarLabel(member) {
      if (member.invited) {
        return member.email;
      }
      return member.name ?? '';
    },
    approveUserQuestion(member) {
      return sprintf(LABEL_CONFIRM_APPROVE, {
        user: member.name || member.email,
      });
    },
    setMemberAsLoading(id) {
      this.loadingPendingMembers.push(id);
    },
    resetMemberLoading(id) {
      this.loadingPendingMembers = this.loadingPendingMembers.filter((m) => m !== id);
    },
    showAlert({ memberId, alertMessage, alertVariant }) {
      if (memberId) {
        const member = this.rawPendingMembers.nodes.find((m) => m.id === memberId);
        this.alertMessage = sprintf(alertMessage, {
          user: member.name || member.email,
        });
      } else {
        this.alertMessage = alertMessage;
      }

      this.alertVariant = alertVariant;
    },
    nextPage() {
      this.cursor = {
        first: PER_PAGE,
        after: this.pendingMembersPageInfo.endCursor,
      };
    },
    prevPage() {
      this.cursor = {
        last: PER_PAGE,
        before: this.pendingMembersPageInfo.startCursor,
      };
    },
    async approveMember(id) {
      this.setMemberAsLoading(id);

      try {
        await this.$apollo.mutate({
          mutation: approvePendingGroupMemberMutation,
          variables: {
            namespaceId: this.namespaceId,
            namespacePath: this.namespacePath,
            id,
          },
          refetchQueries: [pendingMembersQuery],
        });
        this.showAlert({
          memberId: id,
          alertMessage: APPROVAL_SUCCESSFUL_MESSAGE,
          alertVariant: 'info',
        });
      } catch (error) {
        this.showAlert({
          memberId: id,
          alertMessage: APPROVAL_ERROR_MESSAGE,
          alertVariant: 'danger',
        });
      } finally {
        this.resetMemberLoading(id);
      }

      this.loadingPendingMembers = this.loadingPendingMembers.filter((m) => m !== id);
    },
    async approveAllPendingMembers() {
      this.loadingPendingMembers = this.rawPendingMembers.nodes.map((m) => m.id);
      try {
        await this.$apollo.mutate({
          mutation: approveAllPendingGroupMembersMutation,
          variables: {
            namespaceId: this.namespaceId,
          },
          refetchQueries: [pendingMembersQuery],
        });
        this.showAlert({
          alertMessage: ALL_MEMBERS_APPROVAL_SUCCESSFUL_MESSAGE,
          alertVariant: 'info',
        });
      } catch (error) {
        this.showAlert({
          alertMessage: ALL_MEMBERS_APPROVAL_ERROR_MESSAGE,
          alertVariant: 'danger',
        });
      } finally {
        this.loadingPendingMembers = [];
      }
    },
    dismissAlert() {
      this.alertMessage = null;
      this.alertVariant = null;
    },
  },
  avatarSize: AVATAR_SIZE,
  AWAITING_MEMBER_SIGNUP_TEXT,
  LABEL_APPROVE,
  LABEL_APPROVE_ALL,
  LABEL_CONFIRM,
  PENDING_MEMBERS_TITLE,
  EmptyTodosSvg,
};
</script>

<template>
  <div>
    <div class="gl-flex gl-justify-between">
      <h1 class="page-title gl-text-size-h-display">{{ $options.PENDING_MEMBERS_TITLE }}</h1>
      <div v-if="!isLoading" class="gl-self-center">
        <gl-button
          v-gl-modal-directive="`approve-all-confirmation-modal`"
          :loading="approveAllMembersLoading"
          data-testid="approve-all-button"
        >
          {{ $options.LABEL_APPROVE_ALL }}
        </gl-button>
        <gl-modal
          :modal-id="`approve-all-confirmation-modal`"
          :title="approveAllPopoverTitle"
          no-fade
          data-testid="approve-all-modal"
          @primary="approveAllPendingMembers"
        >
          <p>{{ approveAllPopoverBody }}</p>
        </gl-modal>
      </div>
    </div>

    <div v-if="isLoading" class="loading gl-text-center">
      <gl-loading-icon class="!gl-mt-7" size="lg" />
    </div>
    <template v-else>
      <div>
        <gl-alert v-if="alertMessage" :variant="alertVariant" @dismiss="dismissAlert">
          {{ alertMessage }}
        </gl-alert>
        <gl-empty-state
          v-if="!pendingMembers.length && !hasError"
          :title="s__('PendingMembers|There are no pending members left to approve. High five!')"
          :svg-path="$options.EmptyTodosSvg"
          :svg-height="220"
          class="gl-py-8"
        />
        <div
          v-for="item in pendingMembers"
          v-else
          :key="item.id"
          class="gl-flex gl-justify-between gl-border-0 !gl-border-b-1 gl-border-solid gl-border-default gl-p-5"
          data-testid="pending-members-content"
        >
          <gl-avatar-link target="blank" :href="item.webUrl" :alt="item.name">
            <gl-avatar-labeled
              :src="item.avatarUrl"
              :size="$options.avatarSize"
              :label="avatarLabel(item)"
            >
              <template #meta>
                <gl-badge v-if="item.invited && item.approved" variant="neutral">
                  {{ $options.AWAITING_MEMBER_SIGNUP_TEXT }}
                </gl-badge>
              </template>
            </gl-avatar-labeled>
          </gl-avatar-link>
          <gl-button
            v-gl-modal-directive="`approve-confirmation-modal-${item.id}`"
            :loading="item.loading"
            :disabled="item.approved"
            data-testid="approve-member-button"
          >
            {{ $options.LABEL_APPROVE }}
          </gl-button>
          <gl-modal
            :modal-id="`approve-confirmation-modal-${item.id}`"
            :title="$options.LABEL_CONFIRM"
            no-fade
            @primary="approveMember(item.id)"
          >
            <p>{{ approveUserQuestion(item) }}</p>
          </gl-modal>
        </div>
      </div>
    </template>
    <div v-if="showPagination" class="gl-mt-5 gl-text-center">
      <gl-keyset-pagination
        v-if="showPagination"
        v-bind="pendingMembersPageInfo"
        @prev="prevPage"
        @next="nextPage"
      />
    </div>
  </div>
</template>
