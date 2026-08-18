import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import FlowTriggersNew from 'ee/ai/duo_agents_platform/pages/flow_triggers/flow_triggers_new.vue';
import createAiFlowTriggerMutation from 'ee/ai/duo_agents_platform/graphql/mutations/create_ai_flow_trigger.mutation.graphql';
import FlowTriggerForm from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/flow_trigger_form.vue';
import { setPreviousRoute } from 'ee/ai/duo_agents_platform/router/utils';
import { FLOW_TRIGGERS_INDEX_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import {
  mockCreateFlowTriggerSuccessMutation,
  mockCreateFlowTriggerErrorMutation,
  mockTrigger,
} from './mocks';

Vue.use(VueApollo);

describe('FlowTriggersNew', () => {
  let wrapper;
  let createFlowTriggerMock;

  const projectId = 'graphqlid::Project//1';
  const projectPath = 'group/project';

  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    push: jest.fn(),
  };

  const createWrapper = () => {
    createFlowTriggerMock = jest.fn().mockResolvedValue(mockCreateFlowTriggerSuccessMutation);
    const apolloProvider = createMockApollo([[createAiFlowTriggerMutation, createFlowTriggerMock]]);

    wrapper = shallowMountExtended(FlowTriggersNew, {
      apolloProvider,
      provide: {
        projectId,
        projectPath,
      },
      mocks: {
        $router: mockRouter,
        $toast: mockToast,
      },
    });
  };

  const findForm = () => wrapper.findComponent(FlowTriggerForm);

  beforeEach(() => {
    createWrapper();
  });

  describe('Form Submit', () => {
    const { description, configPath, eventTypes, user } = mockTrigger;
    const formValues = {
      description,
      configPath,
      eventTypes,
      user,
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    it('sends a create request', () => {
      submitForm();

      expect(createFlowTriggerMock).toHaveBeenCalledTimes(1);
      expect(createFlowTriggerMock).toHaveBeenCalledWith({
        input: { ...formValues, projectPath },
      });
    });

    it('sets a loading state on the form while submitting', async () => {
      expect(findForm().props('isLoading')).toBe(false);

      await submitForm();

      expect(findForm().props('isLoading')).toBe(true);
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        createFlowTriggerMock.mockRejectedValue(new Error());
        submitForm();
        await waitForPromises();
      });

      it('sets error messages', () => {
        expect(findForm().props('errorMessages')).toEqual([
          'The trigger could not be created. Try again.',
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
        createFlowTriggerMock.mockResolvedValue(mockCreateFlowTriggerErrorMutation);
        submitForm();
        await waitForPromises();
      });

      it('shows an alert', () => {
        expect(findForm().props('errorMessages')).toEqual([
          mockCreateFlowTriggerErrorMutation.data.aiFlowTriggerCreate.errors[0],
        ]);
        expect(findForm().props('isLoading')).toBe(false);
      });
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        submitForm();
        await waitForPromises();
      });

      it('shows toast', () => {
        expect(mockToast.show).toHaveBeenCalledWith('Trigger created successfully.');
      });

      it('navigates to triggers page', async () => {
        await waitForPromises();
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: FLOW_TRIGGERS_INDEX_ROUTE,
        });
      });
    });
  });

  describe('Form Cancel', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('navigates to previous route when previousRoute exists', async () => {
      const previousRoute = { name: 'agents-show', params: { id: '123' } };
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
