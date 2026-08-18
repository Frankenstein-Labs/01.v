import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import FlowTriggersEdit from 'ee/ai/duo_agents_platform/pages/flow_triggers/flow_triggers_edit.vue';
import updateAiFlowTriggerMutation from 'ee/ai/duo_agents_platform/graphql/mutations/update_ai_flow_trigger.mutation.graphql';
import getAiFlowTriggersQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_ai_flow_triggers.query.graphql';
import FlowTriggerForm from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/flow_trigger_form.vue';
import { setPreviousRoute } from 'ee/ai/duo_agents_platform/router/utils';
import { FLOW_TRIGGERS_INDEX_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import {
  mockAiFlowTriggersResponse,
  mockEmptyAiFlowTriggersResponse,
  mockUpdateFlowTriggerSuccessMutation,
  mockUpdateFlowTriggerErrorMutation,
  mockTrigger,
} from './mocks';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('FlowTriggersEdit', () => {
  let wrapper;
  let updateFlowTriggerMock;
  let getFlowTriggerMock;

  const projectId = 'graphqlid::Project//1';
  const projectPath = 'group/path';
  const agentId = 1;
  const routeParams = { id: agentId };
  const previousRoute = { name: 'flows-show', params: { id: '123' } };

  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    go: jest.fn(),
    push: jest.fn(),
  };

  const createWrapper = ({ queryHandler = mockAiFlowTriggersResponse } = {}) => {
    getFlowTriggerMock = jest.fn().mockResolvedValue(queryHandler);
    updateFlowTriggerMock = jest.fn().mockResolvedValue(mockUpdateFlowTriggerSuccessMutation);
    const apolloProvider = createMockApollo([
      [getAiFlowTriggersQuery, getFlowTriggerMock],
      [updateAiFlowTriggerMutation, updateFlowTriggerMock],
    ]);

    wrapper = shallowMountExtended(FlowTriggersEdit, {
      apolloProvider,
      provide: {
        projectId,
        projectPath,
      },
      mocks: {
        $route: {
          params: routeParams,
        },
        $router: mockRouter,
        $toast: mockToast,
      },
    });
  };

  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findGlEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findForm = () => wrapper.findComponent(FlowTriggerForm);

  describe('Rendering', () => {
    it('renders loading icon while fetching data', async () => {
      createWrapper();

      expect(findGlLoadingIcon().exists()).toBe(true);

      await waitForPromises();

      expect(findGlLoadingIcon().exists()).toBe(false);
    });

    describe('when request succeeds but returns no triggers', () => {
      beforeEach(async () => {
        createWrapper({ queryHandler: mockEmptyAiFlowTriggersResponse });
        await waitForPromises();
      });

      it('renders empty state', () => {
        expect(findGlEmptyState().exists()).toBe(true);
        expect(findGlEmptyState().props('title')).toBe('Trigger not found.');
      });
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        createWrapper();
        await waitForPromises();
      });

      it('does not render empty state', () => {
        expect(findGlEmptyState().exists()).toBe(false);
      });
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        createWrapper({ queryHandler: jest.fn().mockRejectedValue(new Error()) });
        await waitForPromises();
      });

      it('renders empty state', () => {
        expect(findGlEmptyState().exists()).toBe(true);
      });

      it('creates an alert', () => {
        expect(createAlert).toHaveBeenCalled();
      });
    });
  });

  describe('Form Submit', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });
    const { description, configPath, eventTypes, user } = mockTrigger;
    const formValues = {
      description,
      configPath,
      eventTypes,
      user,
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    it('sends an update request', () => {
      submitForm();

      expect(updateFlowTriggerMock).toHaveBeenCalledTimes(1);
      expect(updateFlowTriggerMock).toHaveBeenCalledWith({
        input: { ...formValues, id: mockTrigger.id },
      });
    });

    it('sets a loading state on the form while submitting', async () => {
      expect(findForm().props('isLoading')).toBe(false);

      await submitForm();

      expect(findForm().props('isLoading')).toBe(true);
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        updateFlowTriggerMock.mockRejectedValue(new Error());
        submitForm();
        await waitForPromises();
      });

      it('sets error messages', () => {
        expect(findForm().props('errorMessages')).toEqual([
          'The trigger could not be updated. Try again.',
        ]);
        expect(findForm().props('isLoading')).toBe(false);
      });

      it('allows user to dismiss errors', async () => {
        await findForm().vm.$emit('dismiss-errors');

        expect(findForm().props('errorMessages')).toEqual([]);
      });
    });

    describe('when request succeeds but returns error', () => {
      beforeEach(async () => {
        updateFlowTriggerMock.mockResolvedValue(mockUpdateFlowTriggerErrorMutation);
        submitForm();
        await waitForPromises();
      });

      it('shows an alert', () => {
        expect(findForm().props('errorMessages')).toEqual([
          mockUpdateFlowTriggerErrorMutation.data.aiFlowTriggerUpdate.errors[0],
        ]);
        expect(findForm().props('isLoading')).toBe(false);
      });
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        setPreviousRoute(previousRoute);

        submitForm();
        await waitForPromises();
      });

      it('shows toast', () => {
        expect(mockToast.show).toHaveBeenCalledWith('Trigger updated successfully.');
      });

      it('navigates to previous route when previousRoute exists', () => {
        expect(mockRouter.push).toHaveBeenCalledWith(previousRoute);
      });
    });
  });

  describe('Form Cancel', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('navigates to previous route when previousRoute exists', async () => {
      setPreviousRoute(previousRoute);

      await findForm().vm.$emit('cancel');

      expect(mockRouter.push).toHaveBeenCalledWith(previousRoute);
    });

    it('navigates to flow triggers index when previousRoute does not exist', async () => {
      setPreviousRoute(null);

      await findForm().vm.$emit('cancel');

      expect(mockRouter.push).toHaveBeenCalledWith({ name: FLOW_TRIGGERS_INDEX_ROUTE });
    });
  });
});
