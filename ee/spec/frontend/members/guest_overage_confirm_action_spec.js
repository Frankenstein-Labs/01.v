import { guestOverageConfirmAction } from 'ee/members/guest_overage_confirm_action';
import waitForPromises from 'helpers/wait_for_promises';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { MEMBER_ACCESS_LEVELS, GUEST_OVERAGE_MODAL_FIELDS } from 'ee/members/constants';
import * as createDefaultClient from '~/lib/graphql';

jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal');
const increaseOverageResponse = {
  data: {
    group: {
      gitlabSubscriptionsPreviewBillableUserChange: {
        willIncreaseOverage: true,
        newBillableUserCount: 2,
        seatsInSubscription: 1,
      },
    },
  },
};

const noBillableUserCountResponse = {
  data: {
    group: {
      gitlabSubscriptionsPreviewBillableUserChange: {
        willIncreaseOverage: true,
        seatsInSubscription: 1,
      },
    },
  },
};
const noSeatsInSubscriptionResponse = {
  data: {
    group: {
      gitlabSubscriptionsPreviewBillableUserChange: {
        willIncreaseOverage: true,
        newBillableUserCount: 1,
      },
    },
  },
};
const willIncreaseFalseResponse = {
  data: {
    group: {
      gitlabSubscriptionsPreviewBillableUserChange: {
        willIncreaseOverage: false,
        newBillableUserCount: 2,
        seatsInSubscriptionResponse: 1,
      },
    },
  },
};

const upgradeGuestToReporter = {
  oldAccessLevel: MEMBER_ACCESS_LEVELS.GUEST,
  newRoleName: 'Reporter',
  newMemberRoleId: null,
  group: {
    name: 'GroupName',
    path: 'GroupPath/',
  },
  memberId: 1,
  memberType: 'user',
};

describe('guestOverageConfirmAction', () => {
  beforeEach(() => {
    gon.features = { showOverageOnRolePromotion: true };
  });

  describe('when overage modal should not be shown', () => {
    describe('when showOverageOnRolePromotion feature flag is set to false', () => {
      beforeEach(() => {
        gon.features = { showOverageOnRolePromotion: false };
      });

      it('returns true', async () => {
        const confirmReturn = await guestOverageConfirmAction(upgradeGuestToReporter);

        expect(confirmReturn).toBe(true);
      });
    });

    describe('when current access level is above guest', () => {
      it('returns true', async () => {
        const upgradeReporterToOwner = {
          ...upgradeGuestToReporter,
          oldAccessLevel: 20,
          newRoleName: 'Owner',
        };
        const confirmReturn = await guestOverageConfirmAction(upgradeReporterToOwner);

        expect(confirmReturn).toBe(true);
      });
    });

    describe.each([
      ['any data', null],
      ['defined seatsInSubscription', noSeatsInSubscriptionResponse],
      ['defined newBillableUserCount', noBillableUserCountResponse],
      ['`willIncreaseOverage` true', willIncreaseFalseResponse],
    ])('when query does not return %p', (name, resolvedValue) => {
      beforeEach(() => {
        createDefaultClient.default = jest.fn(() => ({
          query: jest.fn().mockResolvedValue(resolvedValue),
        }));
      });

      it('returns true', async () => {
        const confirmReturn = await guestOverageConfirmAction(upgradeGuestToReporter);

        expect(confirmReturn).toBe(true);
      });
    });

    describe('when query returns valid overage response', () => {
      describe('when guestOverageConfirmAction params are invalid', () => {
        beforeEach(() => {
          createDefaultClient.default = jest.fn(() => ({
            query: jest.fn().mockResolvedValue(increaseOverageResponse),
          }));
        });

        it('returns true', async () => {
          const confirmReturn = await guestOverageConfirmAction({});

          expect(confirmReturn).toBe(true);
        });
      });
    });
  });

  describe('when overage modal should be shown', () => {
    beforeEach(() => {
      createDefaultClient.default = jest.fn(() => ({
        query: jest.fn().mockResolvedValue(increaseOverageResponse),
      }));
    });

    describe('upgrading to a static role', () => {
      it('calls confirmAction', async () => {
        guestOverageConfirmAction(upgradeGuestToReporter);
        await waitForPromises();

        expect(confirmAction).toHaveBeenCalled();
      });
    });

    describe('upgrading to a custom role', () => {
      it('calls confirmAction', async () => {
        const upgradeGuestToCustomGuest = {
          ...upgradeGuestToReporter,
          newRoleName: 'Guest',
          newMemberRoleId: 101,
        };
        guestOverageConfirmAction(upgradeGuestToCustomGuest);
        await waitForPromises();

        expect(confirmAction).toHaveBeenCalled();
      });
    });

    describe('calls confirmAction with', () => {
      beforeEach(() => {
        guestOverageConfirmAction(upgradeGuestToReporter);
      });

      describe('modalHtmlMessage set with', () => {
        const overageData =
          increaseOverageResponse.data.group.gitlabSubscriptionsPreviewBillableUserChange;

        it('correct newBillableUserCount', () => {
          const newSeats = overageData.newBillableUserCount;
          expect(confirmAction).toHaveBeenCalledWith(
            '',
            expect.objectContaining({
              modalHtmlMessage: expect.stringContaining(`${newSeats}`),
            }),
          );
        });

        it('correct seatsInSubscription', () => {
          const currentSeats = overageData.seatsInSubscription;
          expect(confirmAction).toHaveBeenCalledWith(
            '',
            expect.objectContaining({
              modalHtmlMessage: expect.stringContaining(`${currentSeats}`),
            }),
          );
        });

        it('correct group name', () => {
          expect(confirmAction).toHaveBeenCalledWith(
            '',
            expect.objectContaining({
              modalHtmlMessage: expect.stringContaining(upgradeGuestToReporter.group.name),
            }),
          );
        });
      });

      it('correct arguments', () => {
        expect(confirmAction).toHaveBeenCalledWith(
          '',
          expect.objectContaining({
            title: GUEST_OVERAGE_MODAL_FIELDS.TITLE,
            primaryBtnText: GUEST_OVERAGE_MODAL_FIELDS.CONTINUE_BUTTON_LABEL,
            cancelBtnText: GUEST_OVERAGE_MODAL_FIELDS.BACK_BUTTON_LABEL,
          }),
        );
      });
    });
  });
});
