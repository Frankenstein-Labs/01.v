import { GlModal, GlLink } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import GuestOverageConfirmation from 'ee/members/components/table/drawer/guest_overage_confirmation.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import getBillableUserCountChanges from 'ee/invite_members/graphql/queries/billable_users_count.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { upgradedMember } from '../../mock_data';

Vue.use(VueApollo);

describe('Guest overage confirmation', () => {
  let wrapper;
  const mockMember = { ...upgradedMember, usingLicense: false };
  const customRole = { ...mockMember.customRoles[0], accessLevel: 20, occupiesSeat: true };
  const showStub = jest.fn();

  const getResponseHandler = ({
    willIncreaseOverage = true,
    seatsInSubscription = 1,
    newBillableUserCount = 2,
  } = {}) =>
    jest.fn().mockResolvedValue({
      data: {
        group: {
          name: 'Test Group',
          gitlabSubscriptionsPreviewBillableUserChange: {
            willIncreaseOverage,
            seatsInSubscription,
            newBillableUserCount,
          },
        },
      },
    });

  const findModal = () => wrapper.findComponent(GlModal);

  const createWrapper = ({
    groupPath = 'group-path',
    responseHandler = getResponseHandler(),
    showOverageOnRolePromotion = true,
    member = mockMember,
    role = customRole,
  } = {}) => {
    wrapper = mountExtended(GuestOverageConfirmation, {
      apolloProvider: createMockApollo([[getBillableUserCountChanges, responseHandler]]),
      propsData: { groupPath, member, role },
      provide: { glFeatures: { showOverageOnRolePromotion } },
      stubs: {
        GlModal: stubComponent(GlModal, { methods: { show: showStub } }),
      },
    });

    wrapper.vm.checkOverage();
    return waitForPromises();
  };

  describe('modal properties', () => {
    it('creates the modal with expected props', () => {
      createWrapper();

      expect(findModal().props()).toMatchObject({
        title: 'You are about to incur additional charges',
        actionPrimary: { text: 'Continue with overages' },
        actionCancel: { text: 'Cancel' },
        size: 'sm',
        noFocusOnShow: true,
      });
    });

    it('shows Learn more link with the expected text and URL', () => {
      createWrapper();
      const link = findModal().findComponent(GlLink);

      expect(link.text()).toBe('Learn more');
      expect(link.attributes()).toMatchObject({
        href: '/help/subscriptions/quarterly_reconciliation',
        target: '_blank',
      });
    });

    describe('modal text', () => {
      it.each`
        seatsInSubscription | newBillableUserCount | expectedText
        ${1}                | ${1}                 | ${'Your subscription includes 1 seat. If you continue, the Test Group group will have 1 seat in use and will be billed for the overage. Learn more'}
        ${1}                | ${2}                 | ${'Your subscription includes 1 seat. If you continue, the Test Group group will have 2 seats in use and will be billed for the overage. Learn more'}
        ${2}                | ${1}                 | ${'Your subscription includes 2 seats. If you continue, the Test Group group will have 1 seat in use and will be billed for the overage. Learn more'}
        ${2}                | ${3}                 | ${'Your subscription includes 2 seats. If you continue, the Test Group group will have 3 seats in use and will be billed for the overage. Learn more'}
      `(
        'shows expected text when $newBillableUserCount / $seatsInSubscription seats will be used',
        async ({ seatsInSubscription, newBillableUserCount, expectedText }) => {
          const responseHandler = getResponseHandler({ seatsInSubscription, newBillableUserCount });
          await createWrapper({ responseHandler });

          expect(findModal().text()).toMatchInterpolatedText(expectedText);
        },
      );
    });
  });

  describe('overage check', () => {
    describe('when there is an error', () => {
      const error = new Error();

      beforeEach(() => {
        const responseHandler = jest.fn().mockRejectedValue(error);
        return createWrapper({ responseHandler });
      });

      it('emits a busy = false event', () => {
        expect(wrapper.emitted('busy')[1][0]).toBe(false);
      });

      it('emits an error event', () => {
        expect(wrapper.emitted('error')[0][0]).toEqual(error);
      });
    });

    describe('query parameters', () => {
      it.each`
        memberType | member                                      | data
        ${'user'}  | ${{ ...mockMember, sharedWithGroup: null }} | ${{ addUserIds: [238], addGroupId: null }}
        ${'group'} | ${{ ...mockMember, sharedWithGroup: {} }}   | ${{ addUserIds: null, addGroupId: 238 }}
      `(
        'calls overage check query with the expected data for a $memberType member',
        ({ member, data }) => {
          const responseHandler = getResponseHandler();
          createWrapper({ responseHandler, member });

          expect(responseHandler).toHaveBeenCalledWith({
            addUserEmails: [],
            fullPath: 'group-path',
            role: 'REPORTER',
            memberRoleId: 101,
            ...data,
          });
        },
      );
    });

    describe('skips query call and confirms overage check when', () => {
      it.each`
        phrase                                   | data
        ${'the feature flag is off'}             | ${{ showOverageOnRolePromotion: false }}
        ${`there's no group path`}               | ${{ groupPath: '' }}
        ${'the member is already using a seat'}  | ${{ member: { ...mockMember, usingLicense: true } }}
        ${'the member is a LDAP user'}           | ${{ member: { ...mockMember, canOverride: true } }}
        ${'the new role does not occupy a seat'} | ${{ role: { ...customRole, occupiesSeat: false } }}
      `('$phrase', async ({ data }) => {
        const responseHandler = getResponseHandler();
        await createWrapper({ ...data, responseHandler });

        expect(responseHandler).not.toHaveBeenCalled();
        expect(showStub).not.toHaveBeenCalled();
        expect(wrapper.emitted('confirm')).toHaveLength(1);
      });
    });

    describe('does not show modal after query call and confirms overage check when', () => {
      it.each`
        phrase                                             | data
        ${`there won't be an overage`}                     | ${{ willIncreaseOverage: false }}
        ${`seatsInSubscription data is unexpectedly null`} | ${{ seatsInSubscription: null }}
        ${`newBillableUserCount is unexpectedly null`}     | ${{ newBillableUserCount: null }}
      `('$phrase', async ({ data }) => {
        const responseHandler = getResponseHandler(data);
        await createWrapper({ responseHandler });

        expect(responseHandler).toHaveBeenCalledTimes(1);
        expect(showStub).not.toHaveBeenCalled();
      });
    });
  });

  describe('when warning modal should be shown', () => {
    it('shows the modal', async () => {
      await createWrapper();

      expect(showStub).toHaveBeenCalledTimes(1);
    });

    describe.each`
      trigger          | expectedEvent
      ${'ok'}          | ${'confirm'}
      ${'cancel'}      | ${'cancel'}
      ${'esc'}         | ${'cancel'}
      ${'backdrop'}    | ${'cancel'}
      ${'headerclose'} | ${'cancel'}
      ${null}          | ${'cancel'}
    `(`when modal is closed by trigger '$trigger'`, ({ trigger, expectedEvent }) => {
      beforeEach(async () => {
        await createWrapper();
        findModal().vm.$emit('hide', { trigger });
      });

      it(`emits ${expectedEvent} event`, () => {
        expect(wrapper.emitted(expectedEvent)).toHaveLength(1);
      });

      it('emits busy = false event', () => {
        expect(wrapper.emitted('busy')[1][0]).toBe(false);
      });
    });
  });
});
