import { GlAlert, GlKeysetPagination } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import RolePromotionRequestsApp from 'ee/admin/role_promotion_requests/components/app.vue';
import PromotionRequestsTable from 'ee/admin/role_promotion_requests/components/promotion_requests_table.vue';
import usersQueuedForLicenseSeat from 'ee/admin/role_promotion_requests/graphql/users_queued_for_license_seat.query.graphql';
import processUserLicenseSeatRequestMutation from 'ee/admin/role_promotion_requests/graphql/process_user_license_seat_request.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { DEFAULT_PER_PAGE } from '~/api';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import showGlobalToast from '~/vue_shared/plugins/global_toast';
import {
  FAILURE_REASON,
  defaultProvide,
  processUserLicenseSeatRequestMutationFailure,
  processUserLicenseSeatRequestMutationPartialSuccess,
  processUserLicenseSeatRequestMutationSuccess,
  selfManagedUsersQueuedForRolePromotion,
} from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/vue_shared/plugins/global_toast', () => jest.fn());

describe('RolePromotionRequestsApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findPromotionRequestsTable = () => wrapper.findComponent(PromotionRequestsTable);
  const findGlKeysetPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findAllGlAlerts = () => wrapper.findAllComponents(GlAlert);
  const findGlAlert = () => wrapper.findComponent(GlAlert);

  const getUsersQueuedForLicenseSeatHandler = jest.fn();
  const processUserBillablePromotionRequestHandler = jest.fn();

  const createComponent = () => {
    wrapper = shallowMountExtended(RolePromotionRequestsApp, {
      apolloProvider: createMockApollo([
        [usersQueuedForLicenseSeat, getUsersQueuedForLicenseSeatHandler],
        [processUserLicenseSeatRequestMutation, processUserBillablePromotionRequestHandler],
      ]),
      provide: defaultProvide,
    });
  };

  describe('Displaying pending promotion requests', () => {
    const result =
      selfManagedUsersQueuedForRolePromotion.data.selfManagedUsersQueuedForRolePromotion;

    beforeEach(async () => {
      getUsersQueuedForLicenseSeatHandler.mockResolvedValue(selfManagedUsersQueuedForRolePromotion);
      createComponent();
      await waitForPromises();
    });

    it('will display the PromotionRequestsTable', () => {
      const table = findPromotionRequestsTable();
      expect(table.props()).toEqual({
        list: result.nodes,
        isLoading: false,
      });
    });

    describe('approve and reject actions', () => {
      const userId = result.nodes[0].user.id;
      const approve = (id) => findPromotionRequestsTable().vm.$emit('approve', id);
      const reject = (id) => findPromotionRequestsTable().vm.$emit('reject', id);

      beforeEach(() => {
        processUserBillablePromotionRequestHandler.mockResolvedValue(
          processUserLicenseSeatRequestMutationSuccess,
        );
      });

      describe('Approval', () => {
        it('will call mutation with approval', () => {
          approve(userId);
          expect(processUserBillablePromotionRequestHandler).toHaveBeenCalledWith({
            status: 'APPROVED',
            userId,
          });
        });

        it('will display approval success state', async () => {
          approve(userId);
          await waitForPromises();
          expect(showGlobalToast).toHaveBeenCalledWith('User has been promoted to a billable role');
        });

        it('will refetch the list', async () => {
          expect(getUsersQueuedForLicenseSeatHandler).toHaveBeenCalledTimes(1);
          approve(userId);
          await waitForPromises();
          expect(getUsersQueuedForLicenseSeatHandler).toHaveBeenCalledTimes(2);
        });

        it('will display partial success state', async () => {
          processUserBillablePromotionRequestHandler.mockResolvedValue(
            processUserLicenseSeatRequestMutationPartialSuccess,
          );
          approve(userId);
          await waitForPromises();
          expect(showGlobalToast).toHaveBeenCalledWith(
            'User has been promoted to a billable role. Some errors occurred',
          );
        });

        it('will display an alert if the mutation fails', async () => {
          processUserBillablePromotionRequestHandler.mockResolvedValue(
            processUserLicenseSeatRequestMutationFailure,
          );
          approve(userId);
          await waitForPromises();
          expect(findGlAlert().text()).toBe(FAILURE_REASON);
        });

        describe('with multiple alerts', () => {
          const otherUserId = result.nodes[1].user.id;

          it('will display an alert for each mutation fail', async () => {
            processUserBillablePromotionRequestHandler.mockResolvedValue(
              processUserLicenseSeatRequestMutationFailure,
            );
            approve(userId);
            approve(otherUserId);
            await waitForPromises();
            expect(findAllGlAlerts()).toHaveLength(2);
          });

          it('will dismiss relevant error message after a successful action', async () => {
            processUserBillablePromotionRequestHandler.mockResolvedValue(
              processUserLicenseSeatRequestMutationFailure,
            );
            approve(userId);
            approve(otherUserId);
            await waitForPromises();
            processUserBillablePromotionRequestHandler.mockResolvedValue(
              processUserLicenseSeatRequestMutationPartialSuccess,
            );
            approve(userId);
            await waitForPromises();
            expect(findAllGlAlerts()).toHaveLength(1);
          });
        });
      });

      describe('Rejection', () => {
        it('will call mutation with rejection', () => {
          reject(userId);
          expect(processUserBillablePromotionRequestHandler).toHaveBeenCalledWith({
            status: 'DENIED',
            userId,
          });
        });

        it('will display rejection success state', async () => {
          reject(userId);
          await waitForPromises();
          expect(showGlobalToast).toHaveBeenCalledWith('User promotion has been rejected');
        });

        it('will display partial success state', async () => {
          processUserBillablePromotionRequestHandler.mockResolvedValue(
            processUserLicenseSeatRequestMutationPartialSuccess,
          );
          reject(userId);
          await waitForPromises();
          expect(showGlobalToast).toHaveBeenCalledWith(
            'User promotion has been rejected. Some errors occurred',
          );
        });

        it('will display an alert if the mutation fails', async () => {
          processUserBillablePromotionRequestHandler.mockResolvedValue(
            processUserLicenseSeatRequestMutationFailure,
          );
          reject(userId);
          await waitForPromises();
          expect(findGlAlert().text()).toBe(FAILURE_REASON);
        });
      });

      describe('error handling', () => {
        it('will display an alert if the network fails', async () => {
          processUserBillablePromotionRequestHandler.mockRejectedValue(new Error('error'));
          approve(userId);
          await waitForPromises();
          expect(findGlAlert().text()).toBe('An error occurred while processing the request');
          expect(Sentry.captureException).toHaveBeenCalled();
        });
      });
    });

    describe('pagination', () => {
      it('will display the pagination', () => {
        const pagination = findGlKeysetPagination();
        const { endCursor, hasNextPage, hasPreviousPage, startCursor } = result.pageInfo;

        expect(pagination.props()).toEqual(
          expect.objectContaining({ endCursor, hasNextPage, hasPreviousPage, startCursor }),
        );
      });

      it('will emit pagination', async () => {
        const pagination = findGlKeysetPagination();
        const after = result.pageInfo.endCursor;
        pagination.vm.$emit('next', after);
        await waitForPromises();
        expect(getUsersQueuedForLicenseSeatHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after,
            first: null,
            last: DEFAULT_PER_PAGE,
          }),
        );
      });
    });
  });

  describe('Loading state', () => {
    beforeEach(async () => {
      getUsersQueuedForLicenseSeatHandler.mockReturnValue(new Promise(() => {}));
      createComponent();
      await waitForPromises();
    });

    it('will set isLoading on PromotionRequestsTable props', () => {
      const table = findPromotionRequestsTable();
      expect(table.props()).toEqual(expect.objectContaining({ isLoading: true }));
    });

    it('will set disabled on the GlKeysetPagination props', () => {
      const pagination = findGlKeysetPagination();
      expect(pagination.props()).toEqual(expect.objectContaining({ disabled: true }));
    });
  });

  describe('Error state', () => {
    beforeEach(async () => {
      jest.spyOn(Sentry, 'captureException');
      getUsersQueuedForLicenseSeatHandler.mockRejectedValue({ error: Error('Error') });
      createComponent();
      await waitForPromises();
    });

    afterEach(() => {
      Sentry.captureException.mockRestore();
    });

    it('will display an error alert', () => {
      expect(findGlAlert().exists()).toBe(true);
    });

    it('will report the error to Sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalledTimes(1);
    });
  });
});
