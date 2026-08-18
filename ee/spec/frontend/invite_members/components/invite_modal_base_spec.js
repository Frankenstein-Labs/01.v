import { GlModal, GlSprintf } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ContentTransition from '~/invite_members/components/content_transition.vue';
import CEInviteModalBase from '~/invite_members/components/invite_modal_base.vue';
import EEInviteModalBase from 'ee/invite_members/components/invite_modal_base.vue';
import {
  OVERAGE_MODAL_TITLE,
  OVERAGE_MODAL_CONTINUE_BUTTON,
  OVERAGE_MODAL_BACK_BUTTON,
} from 'ee/invite_members/constants';
import { propsData as propsDataCE } from 'jest/invite_members/mock_data/modal_base';
import getReconciliationStatus from 'ee/invite_members/graphql/queries/subscription_eligible.customer.query.graphql';
import getBillableUserCountChanges from 'ee/invite_members/graphql/queries/billable_users_count.query.graphql';
import getGroupMemberRoles from 'ee/invite_members/graphql/queries/group_member_roles.query.graphql';
import getProjectMemberRoles from 'ee/graphql_shared/queries/project_member_roles.query.graphql';
import { createMockClient } from 'helpers/mock_apollo_helper';
import { mockGroupMemberRoles, mockProjectMemberRoles } from '../mock_data';

Vue.use(VueApollo);

const generateReconciliationResponse = (isEligible) => {
  return jest
    .fn()
    .mockResolvedValue({ data: { reconciliation: { eligibleForSeatReconciliation: isEligible } } });
};

describe('EEInviteModalBase', () => {
  let wrapper;
  let listenerSpy;
  let mockApollo;

  const defaultReconciliationMock = generateReconciliationResponse(true);
  const defaultBillableMock = jest.fn().mockResolvedValue({
    data: {
      group: {
        id: 12345,
        name: 'Root Group',
        gitlabSubscriptionsPreviewBillableUserChange: {
          willIncreaseOverage: true,
          newBillableUserCount: 2,
          seatsInSubscription: 1,
        },
      },
    },
  });

  const groupMemberRolesResponse = jest.fn().mockResolvedValue(mockGroupMemberRoles);
  const projectMemberRolesResponse = jest.fn().mockResolvedValue(mockProjectMemberRoles);

  const createComponent = ({
    props = {},
    overageMembersModalAvailable = true,
    inviteWithCustomRoleEnabled = false,
    queryHandler = defaultReconciliationMock,
    getBillableUserCountChangesQueryHandler = defaultBillableMock,
    showModal = true,
  } = {}) => {
    const mockCustomersDotClient = createMockClient([[getReconciliationStatus, queryHandler]]);
    const mockGitlabClient = createMockClient([
      [getBillableUserCountChanges, getBillableUserCountChangesQueryHandler],
      [getGroupMemberRoles, groupMemberRolesResponse],
      [getProjectMemberRoles, projectMemberRolesResponse],
    ]);
    mockApollo = new VueApollo({
      defaultClient: mockCustomersDotClient,
      clients: { customersDotClient: mockCustomersDotClient, gitlabClient: mockGitlabClient },
    });

    wrapper = shallowMountExtended(EEInviteModalBase, {
      propsData: {
        ...propsDataCE,
        fullPath: 'mygroup',
        accessLevels: { validRoles: propsDataCE.accessLevels },
        ...props,
      },
      apolloProvider: mockApollo,
      provide: {
        overageMembersModalAvailable,
        inviteWithCustomRoleEnabled,
        rootGroupPath: 'root-group',
      },
      stubs: {
        GlSprintf,
        CeInviteModalBase: CEInviteModalBase,
        ContentTransition,
        GlModal: stubComponent(GlModal, {
          template:
            '<div><slot name="modal-title"></slot><slot></slot><slot name="modal-footer"></slot></div>',
        }),
      },
      listeners: {
        submit: (...args) => listenerSpy('submit', ...args),
        reset: (...args) => listenerSpy('reset', ...args),
        foo: (...args) => listenerSpy('foo', ...args),
      },
    });

    if (showModal) {
      wrapper.findComponent(CEInviteModalBase).vm.$emit('shown');
    }
  };

  beforeEach(() => {
    listenerSpy = jest.fn();
  });

  const findCEBase = () => wrapper.findComponent(CEInviteModalBase);
  const findModal = () => wrapper.findComponent(GlModal);
  const findInitialModalContent = () => wrapper.findByTestId('invite-modal-initial-content');
  const findOverageModalContent = () => wrapper.findByTestId('invite-modal-overage-content');
  const findModalTitle = () => findModal().props('title');
  const findActionButton = () => wrapper.findComponentByTestId('invite-modal-submit');
  const findCancelButton = () => wrapper.findComponentByTestId('invite-modal-cancel');

  const emitClickFromModal = (findButton) => () =>
    findButton().vm.$emit('click', { preventDefault: jest.fn() });

  const clickInviteButton = emitClickFromModal(findActionButton);
  const clickBackButton = emitClickFromModal(findCancelButton);

  describe('fetching custom roles', () => {
    it('fetches roles only after the modal is shown', async () => {
      createComponent({ showModal: false });
      await nextTick();

      expect(groupMemberRolesResponse).not.toHaveBeenCalled();

      findCEBase().vm.$emit('shown');
      await nextTick();

      expect(groupMemberRolesResponse).toHaveBeenCalledTimes(1);
    });

    it('sets the `isLoadingRoles` while fetching', async () => {
      createComponent();
      // Need to wait one tick for the query to start loading, because it's controlled by skip().
      await nextTick();

      expect(findCEBase().props('isLoadingRoles')).toBe(true);

      await waitForPromises();

      expect(findCEBase().props('isLoadingRoles')).toBe(false);
    });

    describe('when `isProject` is true', () => {
      it('queries the project', async () => {
        createComponent({ props: { isProject: true } });
        await waitForPromises();

        expect(findCEBase().props('accessLevels')).toMatchObject({
          customRoles: [
            {
              baseAccessLevel: 10,
              memberRoleId: 103,
              name: 'My role project 1',
              description: 'My role project 1 description',
            },
          ],
        });
      });
    });

    describe('when `isProject` is false', () => {
      it('queries the group', async () => {
        createComponent();
        await waitForPromises();

        expect(findCEBase().props('accessLevels')).toMatchObject({
          customRoles: [
            {
              baseAccessLevel: 10,
              memberRoleId: 100,
              name: 'My role group 1',
              description: 'My role group 1 description',
            },
            {
              baseAccessLevel: 20,
              memberRoleId: 101,
              name: 'My role group 2',
              description: 'My role group 2 description',
            },
          ],
        });
      });
    });

    describe('when `isGroupInvite` is true', () => {
      describe('when inviteWithCustomRoleEnabled is true', () => {
        it('fetches custom roles when modal is shown', async () => {
          createComponent({
            props: { isGroupInvite: true },
            inviteWithCustomRoleEnabled: true,
          });

          expect(groupMemberRolesResponse).toHaveBeenCalledTimes(0);
          expect(projectMemberRolesResponse).toHaveBeenCalledTimes(0);

          await waitForPromises();

          expect(groupMemberRolesResponse).toHaveBeenCalledTimes(1);
          expect(projectMemberRolesResponse).toHaveBeenCalledTimes(0);
        });
      });

      describe('when inviteWithCustomRoleEnabled is false', () => {
        it('does not fetch custom roles even when modal is shown', async () => {
          createComponent({
            props: { isGroupInvite: true },
            inviteWithCustomRoleEnabled: false,
          });

          expect(groupMemberRolesResponse).toHaveBeenCalledTimes(0);
          expect(projectMemberRolesResponse).toHaveBeenCalledTimes(0);

          await waitForPromises();

          expect(groupMemberRolesResponse).toHaveBeenCalledTimes(0);
          expect(projectMemberRolesResponse).toHaveBeenCalledTimes(0);
        });
      });
    });
  });

  describe('default', () => {
    beforeEach(() => {
      createComponent({ props: { invalidFeedbackMessage: 'error appeared', isLoading: true } });
    });

    it('passes attrs to CE base', () => {
      const { accessLevels, ...restPropsDataCE } = propsDataCE;
      expect(findCEBase().props()).toMatchObject({
        ...restPropsDataCE,
        currentSlot: 'default',
        extraSlots: EEInviteModalBase.EXTRA_SLOTS,
        invalidFeedbackMessage: 'error appeared',
        isLoading: true,
      });
    });

    it("doesn't show the overage content", () => {
      expect(findOverageModalContent().isVisible()).toBe(false);
    });

    it('when reset is emitted on base, emits reset', () => {
      expect(wrapper.emitted('reset')).toBeUndefined();

      findCEBase().vm.$emit('reset');

      expect(wrapper.emitted('reset')).toHaveLength(1);
    });

    it("doesn't call api on initial render", () => {
      expect(defaultReconciliationMock).not.toHaveBeenCalled();
    });

    describe('(integration) when invite is clicked', () => {
      beforeEach(async () => {
        clickInviteButton();
        await nextTick();
        await waitForPromises();
      });

      it('does not change title', () => {
        expect(findModalTitle()).toBe(propsDataCE.modalTitle);
      });

      it('shows initial modal content', () => {
        expect(findInitialModalContent().isVisible()).toBe(true);
      });

      it('emits submit', () => {
        expect(wrapper.emitted('submit')).toEqual([[{ accessLevel: 20, expiresAt: undefined }]]);
      });
    });
  });

  describe('when a custom role is selected', () => {
    describe('when overageMembersModalAvailable is true', () => {
      beforeEach(async () => {
        createComponent({
          props: { defaultAccessLevel: 10, defaultMemberRoleId: 100, newUsersToInvite: [123] },
          overageMembersModalAvailable: true,
        });
        await waitForPromises();
      });

      it('submits the `memberRoleId`', async () => {
        clickInviteButton();
        await waitForPromises();

        expect(defaultBillableMock).toHaveBeenCalledWith(
          expect.objectContaining({ memberRoleId: 100 }),
        );

        clickInviteButton();
        await waitForPromises();

        expect(wrapper.emitted('submit')).toEqual([
          [{ accessLevel: 10, expiresAt: undefined, memberRoleId: 100 }],
        ]);
      });
    });

    describe('when overageMembersModalAvailable is false', () => {
      beforeEach(async () => {
        createComponent({
          props: { defaultAccessLevel: 10, defaultMemberRoleId: 100, newUsersToInvite: [123] },
          overageMembersModalAvailable: false,
        });
        await waitForPromises();
      });

      it('submits the `memberRoleId` without calling getBillableUserCountChanges', async () => {
        clickInviteButton();
        await waitForPromises();

        expect(defaultBillableMock).not.toHaveBeenCalled();
        expect(wrapper.emitted('submit')).toEqual([
          [{ accessLevel: 10, expiresAt: undefined, memberRoleId: 100 }],
        ]);
      });
    });
  });

  describe('with a group to invite, and invite is clicked', () => {
    describe('when overageMembersModalAvailable is true', () => {
      beforeEach(async () => {
        createComponent({
          props: { newGroupToInvite: 123, rootGroupId: '54321' },
          overageMembersModalAvailable: true,
        });
        clickInviteButton();
        await nextTick();
        await waitForPromises();
      });

      it('calls graphql API and passes correct parameters', () => {
        expect(defaultBillableMock).toHaveBeenCalledWith({
          fullPath: 'root-group',
          addGroupId: 123,
          addUserEmails: [],
          addUserIds: [],
          role: 'REPORTER',
        });
        expect(defaultReconciliationMock).toHaveBeenCalledTimes(1);
        expect(defaultReconciliationMock).toHaveBeenCalledWith({ namespaceId: 54321 });
      });
    });

    describe('when getBillableUserCountChanges query fails', () => {
      beforeEach(async () => {
        createComponent({
          props: { newGroupToInvite: 123, rootGroupId: '54321' },
          overageMembersModalAvailable: true,
          getBillableUserCountChangesQueryHandler: jest.fn().mockRejectedValueOnce(),
        });
        clickInviteButton();
        await nextTick();
        await waitForPromises();
      });

      it('emits submit one time', () => {
        expect(wrapper.emitted('submit')).toHaveLength(1);
      });
    });

    describe('when getBillableUserCountChanges is successful with invalid data structure', () => {
      beforeEach(async () => {
        createComponent({
          props: { newGroupToInvite: 123, rootGroupId: '54321' },
          overageMembersModalAvailable: true,
          getBillableUserCountChangesQueryHandler: jest.fn().mockResolvedValueOnce({}),
        });
        clickInviteButton();
        await nextTick();
        await waitForPromises();
      });

      it('emits submit one time', () => {
        expect(wrapper.emitted('submit')).toHaveLength(1);
      });
    });

    describe('when overageMembersModalAvailable is false', () => {
      beforeEach(async () => {
        createComponent({
          props: { newGroupToInvite: 123, rootGroupId: '54321' },
          overageMembersModalAvailable: false,
        });
        clickInviteButton();
        await nextTick();
        await waitForPromises();
      });

      it('calls does not call graphql API', () => {
        expect(defaultBillableMock).not.toHaveBeenCalled();
        expect(defaultReconciliationMock).not.toHaveBeenCalled();
      });
    });
  });

  describe('with overageMembersModalAvailable is true, and invite is clicked', () => {
    beforeEach(async () => {
      createComponent({
        props: { newUsersToInvite: [123] },
        overageMembersModalAvailable: true,
      });
      clickInviteButton();
      await waitForPromises();
    });

    it('does not emit submit', () => {
      expect(wrapper.emitted().submit).toBeUndefined();
    });

    it('renders the modal with the correct title', () => {
      expect(findModalTitle()).toBe(OVERAGE_MODAL_TITLE);
    });

    it('renders the Back button text correctly', () => {
      const actionButton = findActionButton();

      expect(actionButton.text()).toBe(OVERAGE_MODAL_CONTINUE_BUTTON);

      expect(actionButton.props()).toMatchObject({
        variant: 'confirm',
        disabled: false,
        loading: false,
      });
    });

    it('renders the Continue button text correctly', () => {
      expect(findCancelButton().text()).toBe(OVERAGE_MODAL_BACK_BUTTON);
    });

    it('shows the info text', () => {
      expect(findModal().text()).toContain(
        'Your subscription includes 1 seat. If you continue, the Root Group group will have 2 seats in use and will be billed for the overage.',
      );
    });

    it('does not show the initial modal content', () => {
      expect(findInitialModalContent().isVisible()).toBe(false);
    });

    describe('when switches back to the initial modal', () => {
      beforeEach(() => clickBackButton());

      it('shows the initial modal', () => {
        expect(findModal().props('title')).toBe(propsDataCE.modalTitle);
        expect(findInitialModalContent().isVisible()).toBe(true);
      });

      it("doesn't show the overage content", () => {
        expect(findOverageModalContent().isVisible()).toBe(false);
      });
    });
  });

  describe('when invite is clicked and hasErrorDuringInvite is true', () => {
    beforeEach(async () => {
      createComponent({
        props: { newUsersToInvite: [123], hasErrorDuringInvite: true },
        overageMembersModalAvailable: true,
      });
      clickInviteButton();
      await waitForPromises();
    });

    it('does not show the overage modal', () => {
      expect(findInitialModalContent().isVisible()).toBe(true);
      expect(findOverageModalContent().isVisible()).toBe(false);
    });
  });

  describe.each([true, false])(
    'when the group is not eligible to show overage and overageMembersModalAvailable is %s',
    (overageMembersModalAvailable) => {
      beforeEach(async () => {
        createComponent({
          overageMembersModalAvailable,
          queryHandler: generateReconciliationResponse(false),
        });

        clickInviteButton();
        await nextTick();
      });

      it('shows the initial modal', () => {
        expect(findModal().props('title')).toBe(propsDataCE.modalTitle);
        expect(findInitialModalContent().isVisible()).toBe(true);
      });

      it("doesn't show the overage content", () => {
        expect(findOverageModalContent().isVisible()).toBe(false);
      });
    },
  );

  describe('when group eligibility API request fails', () => {
    beforeEach(async () => {
      createComponent({
        queryHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
      });

      clickInviteButton();
      await nextTick();
      await waitForPromises();
    });

    it('emits submit event', () => {
      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')).toEqual([[{ accessLevel: 20, expiresAt: undefined }]]);
    });

    it('shows the initial modal', () => {
      expect(findModal().props('title')).toBe(propsDataCE.modalTitle);
      expect(findInitialModalContent().isVisible()).toBe(true);
    });

    it("doesn't show the overage content", () => {
      expect(findOverageModalContent().isVisible()).toBe(false);
    });
  });

  describe('invalid feedback message', () => {
    it('does not show in initial modal', () => {
      createComponent({
        props: { newUsersToInvite: [123] },
        overageMembersModalAvailable: true,
      });

      expect(findModal().props('title')).toBe(propsDataCE.modalTitle);
      expect(findCEBase().props('invalidFeedbackMessage')).toBe('');
    });

    it('does not show after invite if invalidFeedbackMessage prop is not passed', async () => {
      createComponent({
        props: { newUsersToInvite: [123] },
        overageMembersModalAvailable: true,
      });

      clickInviteButton();
      await waitForPromises();

      expect(findModal().props('title')).toBe(OVERAGE_MODAL_TITLE);
      expect(findCEBase().props('invalidFeedbackMessage')).toBe('');
    });

    it('shows if invalidFeedbackMessage prop is passed', () => {
      createComponent({
        props: { newUsersToInvite: [123], invalidFeedbackMessage: 'invalid message' },
        overageMembersModalAvailable: true,
      });

      expect(findModal().props('title')).toBe(propsDataCE.modalTitle);
      expect(findCEBase().props('invalidFeedbackMessage')).toBe('invalid message');
    });
  });
});
