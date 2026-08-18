import { shallowMount } from '@vue/test-utils';
import { GlToggle } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Tracking from '~/tracking';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CodeSuggestionsAddonAssignment from 'ee/usage_quotas/code_suggestions/components/code_suggestions_addon_assignment.vue';
import { DUO_PRO, DUO_ENTERPRISE, DUO_AMAZON_Q } from 'ee/constants/duo';
import getAddOnEligibleUsers from 'ee/usage_quotas/add_on/graphql/saas_add_on_eligible_users.query.graphql';
import userAddOnAssignmentCreateMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_create.mutation.graphql';
import userAddOnAssignmentRemoveMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_remove.mutation.graphql';
import {
  mockAddOnEligibleUsers,
  mockUserWithAddOnAssignment,
  mockUserWithNoAddOnAssignment,
} from 'ee_jest/usage_quotas/code_suggestions/mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('CodeSuggestionsAddonAssignment', () => {
  let wrapper;

  const userIdForAssignment = mockUserWithNoAddOnAssignment.id;
  const userIdForUnassignment = mockUserWithAddOnAssignment.id;

  const duoProAddOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/2';
  const duoEnterpriseAddOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3';
  const duoAmazonQAddOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/4';

  const duoProAddOn = { addOnPurchase: { name: DUO_PRO } };
  const duoEnterpriseAddOn = { addOnPurchase: { name: DUO_ENTERPRISE } };
  const duoAmazonQAddOn = { addOnPurchase: { name: DUO_AMAZON_Q } };

  const duoProAddOnPurchase = {
    id: duoProAddOnPurchaseId,
    name: DUO_PRO,
    purchasedQuantity: 3,
    assignedQuantity: 2,
    __typename: 'AddOnPurchase',
  };
  const duoEnterpriseAddOnPurchase = {
    id: duoEnterpriseAddOnPurchaseId,
    name: DUO_ENTERPRISE,
    purchasedQuantity: 3,
    assignedQuantity: 2,
    __typename: 'AddOnPurchase',
  };
  const duoAmazonQAddOnPurchase = {
    id: duoAmazonQAddOnPurchaseId,
    name: DUO_AMAZON_Q,
    purchasedQuantity: 3,
    assignedQuantity: 2,
    __typename: 'AddOnPurchase',
  };

  const duoProAddOnEligibleUsersQueryVariables = {
    fullPath: 'namespace/full-path',
    addOnType: DUO_PRO,
    addOnPurchaseIds: [duoProAddOnPurchaseId],
  };
  const duoEnterpriseAddOnEligibleUsersQueryVariables = {
    fullPath: 'namespace/full-path',
    addOnType: DUO_ENTERPRISE,
    addOnPurchaseIds: [duoEnterpriseAddOnPurchaseId],
  };
  const duoAmazonQAddOnEligibleUsersQueryVariables = {
    fullPath: 'namespace/full-path',
    addOnType: DUO_AMAZON_Q,
    addOnPurchaseIds: [duoAmazonQAddOnPurchaseId],
  };

  const duoProAddOnAssignmentSuccess = {
    clientMutationId: '1',
    errors: [],
    addOnPurchase: duoProAddOnPurchase,
    user: {
      id: userIdForAssignment,
      addOnAssignments: {
        nodes: duoProAddOn,
        __typename: 'UserAddOnAssignmentConnection',
      },
      __typename: 'AddOnUser',
    },
  };
  const duoEnterpriseAddOnAssignmentSuccess = {
    clientMutationId: '1',
    errors: [],
    addOnPurchase: duoEnterpriseAddOnPurchase,
    user: {
      id: userIdForAssignment,
      addOnAssignments: {
        nodes: duoEnterpriseAddOn,
        __typename: 'UserAddOnAssignmentConnection',
      },
      __typename: 'AddOnUser',
    },
  };
  const duoAmazonQAddOnAssignmentSuccess = {
    clientMutationId: '1',
    errors: [],
    addOnPurchase: duoAmazonQAddOnPurchase,
    user: {
      id: userIdForAssignment,
      addOnAssignments: {
        nodes: duoAmazonQAddOn,
        __typename: 'UserAddOnAssignmentConnection',
      },
      __typename: 'AddOnUser',
    },
  };

  const duoProAddOnUnassignmentSuccess = {
    clientMutationId: '1',
    errors: [],
    addOnPurchase: duoProAddOnPurchase,
    user: {
      id: userIdForUnassignment,
      addOnAssignments: {
        nodes: [],
        __typename: 'UserAddOnAssignmentConnection',
      },
      __typename: 'AddOnUser',
    },
  };

  const knownAddOnAssignmentError = {
    clientMutationId: '1',
    errors: ['NO_SEATS_AVAILABLE'],
    addOnPurchase: null,
    user: null,
  };
  const unknownAddOnAssignmentError = {
    clientMutationId: '1',
    errors: ['AN_ERROR'],
    addOnPurchase: null,
    user: null,
  };
  const nonStringAddOnAssignmentError = {
    clientMutationId: '1',
    errors: [null],
    addOnPurchase: null,
    user: null,
  };

  const duoProAssignAddOnHandler = jest.fn().mockResolvedValue({
    data: { userAddOnAssignmentCreate: duoProAddOnAssignmentSuccess },
  });
  const duoEnterpriseAssignAddOnHandler = jest.fn().mockResolvedValue({
    data: { userAddOnAssignmentCreate: duoEnterpriseAddOnAssignmentSuccess },
  });
  const duoAmazonQAssignAddOnHandler = jest.fn().mockResolvedValue({
    data: { userAddOnAssignmentCreate: duoAmazonQAddOnAssignmentSuccess },
  });

  const duoProUnassignAddOnHandler = jest.fn().mockResolvedValue({
    data: { userAddOnAssignmentRemove: duoProAddOnUnassignmentSuccess },
  });

  const createMockApolloProvider = (
    addOnAssignmentCreateHandler,
    addOnAssignmentRemoveHandler,
    addOnAssignmentQueryVariables,
  ) => {
    const mockApollo = createMockApollo([
      [userAddOnAssignmentCreateMutation, addOnAssignmentCreateHandler],
      [userAddOnAssignmentRemoveMutation, addOnAssignmentRemoveHandler],
    ]);

    // Needed to check if cache update is successful on successful mutation
    mockApollo.clients.defaultClient.cache.writeQuery({
      query: getAddOnEligibleUsers,
      variables: addOnAssignmentQueryVariables,
      data: mockAddOnEligibleUsers.data,
    });

    return mockApollo;
  };

  let mockApolloClient;

  const createComponent = ({
    props = {},
    addOnAssignmentCreateHandler = duoProAssignAddOnHandler,
    addOnAssignmentRemoveHandler = duoProUnassignAddOnHandler,
    addOnAssignmentQueryVariables = duoProAddOnEligibleUsersQueryVariables,
  } = {}) => {
    mockApolloClient = createMockApolloProvider(
      addOnAssignmentCreateHandler,
      addOnAssignmentRemoveHandler,
      addOnAssignmentQueryVariables,
    );
    wrapper = shallowMount(CodeSuggestionsAddonAssignment, {
      apolloProvider: mockApolloClient,
      propsData: {
        addOnAssignments: [],
        userId: userIdForAssignment,
        addOnPurchaseId: duoProAddOnPurchaseId,
        activeDuoTier: DUO_PRO,
        ...props,
      },
    });
  };

  const getAddOnAssignmentStatusForUserFromCache = (
    userId,
    variables = duoProAddOnEligibleUsersQueryVariables,
  ) => {
    return mockApolloClient.clients.defaultClient.cache
      .readQuery({ query: getAddOnEligibleUsers, variables })
      .namespace.addOnEligibleUsers.nodes.find((node) => node.id === userId).addOnAssignments.nodes;
  };

  const findToggle = () => wrapper.findComponent(GlToggle);

  it('shows correct label on the toggle', () => {
    createComponent();
    expect(findToggle().props('label')).toBe('GitLab Duo Pro status');
  });

  describe('with Duo Enterprise add-on enabled', () => {
    beforeEach(() => {
      return createComponent({ props: { activeDuoTier: DUO_ENTERPRISE } });
    });

    it('shows correct label on the toggle', () => {
      expect(findToggle().props('label')).toBe('GitLab Duo Enterprise status');
    });
  });

  describe('with Duo with Amazon Q add-on enabled', () => {
    beforeEach(() => {
      return createComponent({ props: { activeDuoTier: DUO_AMAZON_Q } });
    });

    it('shows correct label on the toggle', () => {
      expect(findToggle().props('label')).toBe('GitLab Duo with Amazon Q status');
    });
  });

  describe.each([
    {
      title: 'when there are assigned add-ons',
      addOnAssignments: [duoProAddOn],
      toggleProps: { disabled: false, value: true },
    },
    {
      title: 'when there are no assigned add-ons',
      addOnAssignments: [],
      toggleProps: { disabled: false, value: false },
    },
  ])('$title', ({ addOnAssignments, toggleProps }) => {
    beforeEach(() => {
      createComponent({ props: { addOnAssignments } });
    });

    it('renders add-on toggle with appropriate props', () => {
      expect(findToggle().props()).toEqual(expect.objectContaining(toggleProps));
    });
  });

  describe('when assigning a Duo Pro add-on', () => {
    beforeEach(() => {
      jest.spyOn(Tracking, 'event');

      createComponent({
        props: { addOnAssignments: [], userId: userIdForAssignment },
      });
      findToggle().vm.$emit('change', true);
    });

    it('shows loading state for the toggle', () => {
      expect(findToggle().props('isLoading')).toBe(true);
    });

    it('updates the cache with latest add-on assignment status', async () => {
      await waitForPromises();

      expect(getAddOnAssignmentStatusForUserFromCache(userIdForAssignment)).toEqual(duoProAddOn);
    });

    it('does not show loading state once updated', async () => {
      await waitForPromises();

      expect(findToggle().props('isLoading')).toBe(false);
    });

    it('calls add-on assignment mutation with appropriate params', () => {
      expect(duoProAssignAddOnHandler).toHaveBeenCalledWith({
        addOnPurchaseId: duoProAddOnPurchaseId,
        userId: userIdForAssignment,
      });
    });

    it('does not call add-on un-assignment mutation', () => {
      expect(duoProUnassignAddOnHandler).not.toHaveBeenCalled();
    });

    it('tracks the `enable_gitlab_duo_pro_for_seat` event', async () => {
      await waitForPromises();

      expect(Tracking.event).toHaveBeenCalledWith(
        undefined,
        'enable_gitlab_duo_pro_for_seat',
        expect.any(Object),
      );
    });
  });

  describe('when assigning a Duo Enterprise add-on', () => {
    beforeEach(() => {
      createComponent({
        props: {
          addOnAssignments: [],
          activeDuoTier: DUO_ENTERPRISE,
          userId: userIdForAssignment,
          addOnPurchaseId: duoEnterpriseAddOnPurchaseId,
        },
        addOnAssignmentCreateHandler: duoEnterpriseAssignAddOnHandler,
        addOnAssignmentQueryVariables: duoEnterpriseAddOnEligibleUsersQueryVariables,
      });

      findToggle().vm.$emit('change', true);
    });

    it('updates the cache with latest add-on assignment status', async () => {
      await waitForPromises();

      expect(
        getAddOnAssignmentStatusForUserFromCache(
          userIdForAssignment,
          duoEnterpriseAddOnEligibleUsersQueryVariables,
        ),
      ).toEqual(duoEnterpriseAddOn);
    });

    it('calls add-on assignment mutation with appropriate params', () => {
      expect(duoEnterpriseAssignAddOnHandler).toHaveBeenCalledWith({
        addOnPurchaseId: duoEnterpriseAddOnPurchaseId,
        userId: userIdForAssignment,
      });
    });

    it('does not call add-on un-assignment mutation', () => {
      expect(duoProUnassignAddOnHandler).not.toHaveBeenCalled();
    });
  });

  describe('when assigning a Duo with Amazon Q add-on', () => {
    beforeEach(() => {
      createComponent({
        props: {
          addOnAssignments: [],
          activeDuoTier: DUO_AMAZON_Q,
          userId: userIdForAssignment,
          addOnPurchaseId: duoAmazonQAddOnPurchaseId,
        },
        addOnAssignmentCreateHandler: duoAmazonQAssignAddOnHandler,
        addOnAssignmentQueryVariables: duoAmazonQAddOnEligibleUsersQueryVariables,
      });

      findToggle().vm.$emit('change', true);
    });

    it('updates the cache with latest add-on assignment status', async () => {
      await waitForPromises();

      expect(
        getAddOnAssignmentStatusForUserFromCache(
          userIdForAssignment,
          duoAmazonQAddOnEligibleUsersQueryVariables,
        ),
      ).toEqual(duoAmazonQAddOn);
    });

    it('calls add-on assignment mutation with appropriate params', () => {
      expect(duoAmazonQAssignAddOnHandler).toHaveBeenCalledWith({
        addOnPurchaseId: duoAmazonQAddOnPurchaseId,
        userId: userIdForAssignment,
      });
    });

    it('does not call add-on un-assignment mutation', () => {
      expect(duoProUnassignAddOnHandler).not.toHaveBeenCalled();
    });
  });

  describe('when error occurs while assigning add-on', () => {
    const addOnAssignments = [];

    it('emits an event with the error code from response for a known error', async () => {
      createComponent({
        props: { addOnAssignments },
        addOnAssignmentCreateHandler: jest
          .fn()
          .mockResolvedValue({ data: { userAddOnAssignmentCreate: knownAddOnAssignmentError } }),
      });
      findToggle().vm.$emit('change', true);

      await waitForPromises();

      expect(wrapper.emitted('clear-error')).toEqual([[]]);
      expect(wrapper.emitted('handle-error')).toEqual([['NO_SEATS_AVAILABLE']]);
    });

    it('emits an event with generic error code for a non string error code', async () => {
      createComponent({
        props: { addOnAssignments },
        addOnAssignmentCreateHandler: jest.fn().mockResolvedValue({
          data: { userAddOnAssignmentCreate: nonStringAddOnAssignmentError },
        }),
      });
      findToggle().vm.$emit('change', true);

      await waitForPromises();

      expect(wrapper.emitted('clear-error')).toEqual([[]]);
      expect(wrapper.emitted('handle-error')).toEqual([['CANNOT_ASSIGN_ADDON']]);
    });

    it('emits an event with generic error code for an unknown error', async () => {
      createComponent({
        props: { addOnAssignments },
        addOnAssignmentCreateHandler: jest
          .fn()
          .mockResolvedValue({ data: { userAddOnAssignmentCreate: unknownAddOnAssignmentError } }),
      });
      findToggle().vm.$emit('change', true);

      await waitForPromises();

      expect(wrapper.emitted('clear-error')).toEqual([[]]);
      expect(wrapper.emitted('handle-error')).toEqual([['CANNOT_ASSIGN_ADDON']]);
    });

    it('emits an event with the generic error code', async () => {
      createComponent({
        props: { addOnAssignments },
        addOnAssignmentCreateHandler: jest.fn().mockRejectedValue(new Error('An error')),
      });
      findToggle().vm.$emit('change', true);

      await waitForPromises();

      expect(wrapper.emitted('clear-error')).toEqual([[]]);
      expect(wrapper.emitted('handle-error')).toEqual([['CANNOT_ASSIGN_ADDON']]);
    });

    it('captures error on Sentry for generic errors', async () => {
      const error = new Error('An error');
      createComponent({
        props: { addOnAssignments },
        addOnAssignmentCreateHandler: jest.fn().mockRejectedValue(error),
      });
      findToggle().vm.$emit('change', true);

      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });
  });

  describe('when un-assigning an add-on', () => {
    beforeEach(() => {
      jest.spyOn(Tracking, 'event');

      createComponent({
        props: { addOnAssignments: [duoProAddOn], userId: userIdForUnassignment },
      });
      findToggle().vm.$emit('change', false);
    });

    it('shows loading state for the toggle', () => {
      expect(findToggle().props('isLoading')).toBe(true);
    });

    it('updates the cache with latest add-on assignment status', async () => {
      await waitForPromises();

      expect(getAddOnAssignmentStatusForUserFromCache(userIdForUnassignment)).toEqual([]);
    });

    it('does not show loading state once updated', async () => {
      await waitForPromises();

      expect(findToggle().props('isLoading')).toBe(false);
    });

    it('calls add-on un-assignment mutation with appropriate params', () => {
      expect(duoProUnassignAddOnHandler).toHaveBeenCalledWith({
        addOnPurchaseId: duoProAddOnPurchaseId,
        userId: userIdForUnassignment,
      });
    });

    it('does not call add-on assignment mutation', () => {
      expect(duoProAssignAddOnHandler).not.toHaveBeenCalled();
    });

    it('tracks the `disable_gitlab_duo_pro_for_seat` event', async () => {
      await waitForPromises();

      expect(Tracking.event).toHaveBeenCalledWith(
        undefined,
        'disable_gitlab_duo_pro_for_seat',
        expect.any(Object),
      );
    });
  });

  describe('when error occurs while un-assigning add-on', () => {
    const addOnAssignments = [duoProAddOn];

    it('emits an event with the error code from response for a known error', async () => {
      createComponent({
        props: { addOnAssignments },
        addOnAssignmentRemoveHandler: jest
          .fn()
          .mockResolvedValue({ data: { userAddOnAssignmentRemove: knownAddOnAssignmentError } }),
      });
      findToggle().vm.$emit('change', false);

      await waitForPromises();

      expect(wrapper.emitted('clear-error')).toEqual([[]]);
      expect(wrapper.emitted('handle-error')).toEqual([['NO_SEATS_AVAILABLE']]);
    });

    it('emits an event with generic error code for a non string error code', async () => {
      createComponent({
        props: { addOnAssignments },
        addOnAssignmentRemoveHandler: jest.fn().mockResolvedValue({
          data: { userAddOnAssignmentRemove: nonStringAddOnAssignmentError },
        }),
      });
      findToggle().vm.$emit('change', true);

      await waitForPromises();

      expect(wrapper.emitted('clear-error')).toEqual([[]]);
      expect(wrapper.emitted('handle-error')).toEqual([['CANNOT_UNASSIGN_ADDON']]);
    });

    it('emits an event with generic error code for an unknown error', async () => {
      createComponent({
        props: { addOnAssignments },
        addOnAssignmentRemoveHandler: jest
          .fn()
          .mockResolvedValue({ data: { userAddOnAssignmentRemove: unknownAddOnAssignmentError } }),
      });
      findToggle().vm.$emit('change', false);

      await waitForPromises();

      expect(wrapper.emitted('clear-error')).toEqual([[]]);
      expect(wrapper.emitted('handle-error')).toEqual([['CANNOT_UNASSIGN_ADDON']]);
    });

    it('emits an event with the generic error code', async () => {
      createComponent({
        props: { addOnAssignments },
        addOnAssignmentRemoveHandler: jest.fn().mockRejectedValue(new Error('An error')),
      });
      findToggle().vm.$emit('change', false);

      await waitForPromises();

      expect(wrapper.emitted('clear-error')).toEqual([[]]);
      expect(wrapper.emitted('handle-error')).toEqual([['CANNOT_UNASSIGN_ADDON']]);
    });
  });
});
