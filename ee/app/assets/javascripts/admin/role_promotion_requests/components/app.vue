<script>
import { GlKeysetPagination, GlAlert } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { DEFAULT_PER_PAGE } from '~/api';
import showGlobalToast from '~/vue_shared/plugins/global_toast';
import { s__ } from '~/locale';
import usersQueuedForLicenseSeat from '../graphql/users_queued_for_license_seat.query.graphql';
import processUserLicenseSeatRequestMutation from '../graphql/process_user_license_seat_request.mutation.graphql';
import PromotionRequestsTable from './promotion_requests_table.vue';

export default {
  name: 'RolePromotionRequestsApp',
  components: {
    PromotionRequestsTable,
    GlKeysetPagination,
    GlAlert,
  },
  data() {
    return {
      isLoading: true,
      errors: [],
      usersQueuedForLicenseSeat: {},
      cursor: {
        first: DEFAULT_PER_PAGE,
        last: null,
        after: null,
        before: null,
      },
    };
  },
  apollo: {
    usersQueuedForLicenseSeat: {
      query: usersQueuedForLicenseSeat,
      variables() {
        return {
          ...this.cursor,
        };
      },
      update(data) {
        return data.selfManagedUsersQueuedForRolePromotion;
      },
      error(error) {
        this.isLoading = false;
        this.errors.push({
          index: uniqueId(),
          message: s__(
            'PromotionRequests|An error occured while loading the role promotion requests. Refresh the page to try again',
          ),
          dismissable: false,
        });
        Sentry.captureException({ error, component: this.$options.name });
      },
      result() {
        this.isLoading = false;
      },
    },
  },
  methods: {
    dismissError(error) {
      this.errors = this.errors.filter((e) => e !== error);
    },
    clearErrorsByUserId(userId) {
      this.errors = this.errors.filter((e) => e.userId !== userId);
    },
    onPrev(before) {
      this.cursor = {
        first: DEFAULT_PER_PAGE,
        last: null,
        before,
      };
    },
    onNext(after) {
      this.cursor = {
        first: null,
        last: DEFAULT_PER_PAGE,
        after,
      };
    },
    approve(userId) {
      return this.updateUserLicenseSeatRequest(userId, 'APPROVED');
    },
    reject(userId) {
      return this.updateUserLicenseSeatRequest(userId, 'DENIED');
    },
    /**
     * @param {string} userId
     * @param {'APPROVED'|'DENIED'} status
     */
    async updateUserLicenseSeatRequest(userId, status) {
      this.isLoading = true;
      let response;
      try {
        response = await this.$apollo.mutate({
          mutation: processUserLicenseSeatRequestMutation,
          variables: {
            userId,
            status,
          },
        });
        this.clearErrorsByUserId(userId);
      } catch (requestError) {
        this.clearErrorsByUserId(userId);
        // Change request had some network / unexpected errors
        // we don't quite know if the user has become billable or not
        this.errors.push({
          index: uniqueId(),
          userId,
          message: s__('PromotionRequests|An error occurred while processing the request'),
          dismissable: true,
        });
        Sentry.captureException({ error: requestError, component: this.$options.name });
        this.isLoading = false;
        return;
      }

      /** @type {'FAILURE'|'SUCCESS'|'PARTIAL_SUCCESS'} */
      const { result } = response.data.processUserBillablePromotionRequest;
      /** @type {{errors: string[]}} */
      const { errors: responseErrors } = response.data.processUserBillablePromotionRequest;

      // Change request failed because all underlying promotion requests failed
      // The user remains non-billable
      if (result === 'FAILURE') {
        if (!responseErrors.length) {
          this.errors.push({
            index: uniqueId(),
            userId,
            message: s__('PromotionRequests|An error occurred while processing the request'),
            dismissable: true,
          });
        } else {
          responseErrors.forEach((mutationError) => {
            this.errors.push({
              index: uniqueId(),
              userId,
              message: mutationError,
              dismissable: true,
            });
          });
        }
        this.isLoading = false;
        return;
      }

      // Change request was approved, with:
      // - PARTIAL_SUCCESS — some underlying promotion requests were approved
      // - SUCCESS — all underlying promotion requests were approved
      // The user is billable now, we can update the list
      const message = {
        APPROVED__SUCCESS: s__('PromotionRequests|User has been promoted to a billable role'),
        APPROVED__PARTIAL_SUCCESS: s__(
          'PromotionRequests|User has been promoted to a billable role. Some errors occurred',
        ),
        DENIED__SUCCESS: s__('PromotionRequests|User promotion has been rejected'),
        DENIED__PARTIAL_SUCCESS: s__(
          'PromotionRequests|User promotion has been rejected. Some errors occurred',
        ),
      }[`${status}__${result}`];

      showGlobalToast(message);

      await this.$apollo.queries.usersQueuedForLicenseSeat.refetch();
    },
  },
};
</script>

<template>
  <section>
    <gl-alert
      v-for="error in errors"
      :key="error.index"
      variant="danger"
      sticky
      :dismissable="error.dismissable"
      class="gl-top-10 gl-z-1 gl-my-4"
      @dismiss="dismissError(error)"
    >
      {{ error.message }}
    </gl-alert>

    <promotion-requests-table
      :is-loading="isLoading"
      :list="usersQueuedForLicenseSeat.nodes"
      @approve="approve"
      @reject="reject"
    />

    <div class="gl-mt-4 gl-flex gl-items-center gl-justify-center">
      <gl-keyset-pagination
        v-bind="usersQueuedForLicenseSeat.pageInfo"
        :disabled="isLoading"
        @prev="onPrev"
        @next="onNext"
      />
    </div>
  </section>
</template>
