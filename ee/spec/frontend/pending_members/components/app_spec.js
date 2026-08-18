import {
  GlKeysetPagination,
  GlBadge,
  GlEmptyState,
  GlModal,
  GlLoadingIcon,
  GlAlert,
  GlButton,
} from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  pendingMembersResponse,
  pendingMembersResponseEmpty,
} from 'ee_jest/pending_members/mock_data';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PendingMembersApp from 'ee/pending_members/components/app.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import pendingMembersQuery from 'ee/pending_members/components/pending_members.query.graphql';

Vue.use(VueApollo);

const pendingMembersHandler = jest.fn().mockResolvedValue(pendingMembersResponse);
const approvePendingGroupMemberSpy = jest.fn();
const approveAllPendingMembersSpy = jest.fn();

describe('PendingMembersApp', () => {
  let wrapper;

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findPendingMembers = () => wrapper.findAllByTestId('pending-members-content');
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findApproveAllModal = () => wrapper.findComponentByTestId('approve-all-modal');

  const approveMemberAtIndex = (index) => {
    findPendingMembers().at(index).findComponent(GlModal).vm.$emit('primary');
  };

  const createComponent = ({ stubs = {}, userCapSet = false } = {}) => {
    const mockApollo = createMockApollo([[pendingMembersQuery, pendingMembersHandler]], {
      Mutation: {
        approvePendingGroupMember: approvePendingGroupMemberSpy,
        approveAllPendingGroupMembers: approveAllPendingMembersSpy,
      },
    });

    wrapper = shallowMountExtended(PendingMembersApp, {
      stubs,
      apolloProvider: mockApollo,
      provide: { namespacePath: 'name', namespaceId: '1', userCapSet },
    });
  };

  describe('approve all members modal', () => {
    describe('when user cap is not set', () => {
      beforeEach(() => {
        createComponent();
      });

      it('passes correct text to modal', async () => {
        await waitForPromises();

        expect(findApproveAllModal().props('title')).toBe('Approve 3 pending members');
        expect(findApproveAllModal().text()).toContain(
          'Approved members will use an additional 3 seats in your subscription.',
        );
      });
    });

    describe('when user cap is set', () => {
      beforeEach(() => {
        createComponent({ userCapSet: true });
      });

      it('passes correct text to modal', async () => {
        await waitForPromises();

        expect(findApproveAllModal().props('title')).toBe('Approve 3 pending members');
        expect(findApproveAllModal().text()).toContain(
          'Approved members will use an additional 3 seats in your subscription, which may override your user cap.',
        );
      });
    });
  });

  describe('when loading', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not render pending members', () => {
      expect(findPendingMembers()).toHaveLength(0);
    });

    it('does not render empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('does not render an alert', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when there are pending members', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('does not render loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders correct number of pending members', () => {
      expect(findPendingMembers()).toHaveLength(3);
    });

    it('pagination is rendered and passed correct values', () => {
      const pagination = findPagination();

      expect(pagination.props()).toMatchObject({
        hasPreviousPage: false,
        hasNextPage: true,
        startCursor: 'MTE',
        endCursor: 'MjA',
        prevButtonLink: null,
        navigationLabel: 'Pagination',
        nextButtonLink: null,
        disabled: false,
      });
    });

    it('render badge for approved invited member', () => {
      expect(wrapper.findAllComponents(GlBadge)).toHaveLength(1);
    });
  });

  describe('when there are no pending members', () => {
    beforeEach(async () => {
      pendingMembersHandler.mockResolvedValue(pendingMembersResponseEmpty);
      createComponent();
      await waitForPromises();
    });

    it('does not render pending members', () => {
      expect(findPendingMembers()).toHaveLength(0);
    });

    it('renders empty state', async () => {
      await waitForPromises();

      expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
      expect(wrapper.findComponent(GlEmptyState).props('title')).toBe(
        'There are no pending members left to approve. High five!',
      );
    });
  });

  describe('when pending members query fails', () => {
    beforeEach(async () => {
      pendingMembersHandler.mockRejectedValue(new Error('An error occurred'));
      createComponent();
      await waitForPromises();
    });

    it('does not render loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('does not render pending members', () => {
      expect(findPendingMembers()).toHaveLength(0);
    });

    it('does not render empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('renders an alert with error text', () => {
      expect(findAlert().exists()).toBe(true);
      expect(wrapper.text()).toContain('An error occurred while loading pending members list');
    });
  });

  describe('approve a pending member', () => {
    const approveMemberButton = () => findPendingMembers().at(0).findComponent(GlButton);

    beforeEach(async () => {
      pendingMembersHandler.mockResolvedValue(pendingMembersResponse);
      createComponent();
      await waitForPromises();
    });

    it('renders loading icon for member being approved', async () => {
      approveMemberAtIndex(0);
      await nextTick();

      expect(approveMemberButton().props('loading')).toBe(true);
    });

    it('calls the approvePendingMemberMutation and refetches the query', async () => {
      await approveMemberAtIndex(0);
      await waitForPromises();

      expect(approvePendingGroupMemberSpy).toHaveBeenCalledWith(
        expect.any(Object),
        {
          id: 'gid://gitlab/GroupMember/98',
          namespaceId: '1',
          namespacePath: 'name',
        },
        expect.any(Object),
        expect.any(Object),
      );
      expect(approveMemberButton().props('loading')).toBe(false);
      expect(pendingMembersHandler).toHaveBeenCalledTimes(2);
    });

    it('renders an error if the mutation fails', async () => {
      approvePendingGroupMemberSpy.mockRejectedValue(new Error('Mutation failed'));
      await approveMemberAtIndex(0);
      await waitForPromises();

      expect(wrapper.findComponent(GlAlert).exists()).toBe(true);
      expect(approveMemberButton().props('loading')).toBe(false);
    });
  });

  describe('approve all pending members', () => {
    beforeEach(async () => {
      pendingMembersHandler.mockResolvedValue(pendingMembersResponse);
      createComponent();
      await waitForPromises();
    });

    it('renders loading icon for all pending members', async () => {
      findApproveAllModal().vm.$emit('primary');
      await nextTick();

      expect(
        findPendingMembers().wrappers.every((member) =>
          member.findComponent(GlButton).props('loading'),
        ),
      ).toBe(true);
    });

    it('calls the approveAllPendingMembersMutation', async () => {
      findApproveAllModal().vm.$emit('primary');
      await waitForPromises();

      expect(approveAllPendingMembersSpy).toHaveBeenCalledWith(
        expect.any(Object),
        {
          namespaceId: '1',
        },
        expect.any(Object),
        expect.any(Object),
      );
      expect(wrapper.text()).toContain('All members were successfully approved');
    });

    it('renders an error if the mutation fails', async () => {
      approveAllPendingMembersSpy.mockRejectedValueOnce(new Error('Mutation failed'));

      findApproveAllModal().vm.$emit('primary');
      await waitForPromises();

      expect(wrapper.findComponent(GlAlert).exists()).toBe(true);
    });
  });

  describe('dismissAlert', () => {
    beforeEach(async () => {
      pendingMembersHandler.mockResolvedValue(pendingMembersResponse);
      createComponent();
      await waitForPromises();

      findApproveAllModal().vm.$emit('primary');
      await waitForPromises();
    });

    it('shows an alert when triggered', () => {
      expect(wrapper.findComponent(GlAlert).exists()).toBe(true);
      expect(wrapper.findComponent(GlAlert).text()).toContain(
        'All members were successfully approved',
      );
    });

    it('dismisses the alert when dismissAlert is called', async () => {
      wrapper.findComponent(GlAlert).vm.$emit('dismiss');
      await nextTick();

      expect(wrapper.findComponent(GlAlert).exists()).toBe(false);
    });
  });

  describe('pagination', () => {
    beforeEach(() => {
      createComponent();
      return waitForPromises();
    });

    it('reacts to change to next page', async () => {
      const pagination = findPagination();
      pagination.vm.$emit('next');
      await nextTick();

      expect(pendingMembersHandler).toHaveBeenCalledWith({
        groupPath: 'name',
        first: 10,
        after: 'MjA',
        last: 10,
      });
    });

    it('reacts to change to previous page', async () => {
      const pagination = findPagination();
      pagination.vm.$emit('prev');
      await nextTick();

      expect(pendingMembersHandler).toHaveBeenCalledWith({
        groupPath: 'name',
        last: 10,
        before: 'MTE',
        first: 10,
      });
    });
  });
});
