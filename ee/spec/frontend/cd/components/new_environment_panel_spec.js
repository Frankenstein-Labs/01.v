import { GlAlert } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DynamicPanel from '~/vue_shared/components/dynamic_panel.vue';
import NewEnvironmentPanel from 'ee/cd/components/new_environment_panel.vue';
import PanelFormField from 'ee/cd/components/shared/panel_form_field.vue';
import PanelFormGroup from 'ee/cd/components/shared/panel_form_group.vue';
import cdEnvironmentCreateMutation from 'ee/cd/graphql/cd_environment_create.mutation.graphql';
import cdEnvironmentTiersQuery from 'ee/cd/graphql/cd_environment_tiers.query.graphql';
import cdAvailableAgentsQuery from 'ee/cd/graphql/cd_available_agents.query.graphql';
import cdEnvironmentsQuery from 'ee/cd/graphql/cd_environments.query.graphql';
import { ENVIRONMENT_DRIVER_REF } from 'ee/cd/constants';
import {
  buildQueryResponse,
  buildDefaultAvailableAgentsQueryResponse,
  buildEnvironmentsQueryResponse,
  makeCdEnvironmentDriverBinding,
} from './mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('NewEnvironmentPanel', () => {
  let apolloProvider;
  let wrapper;

  const organizationId = 'gid://gitlab/Organizations::Organization/1';
  const tiers = ['DEVELOPMENT', 'STAGING', 'PRODUCTION'];
  const queryVariables = { search: '', tier: null };

  const buildResponse = (errors = []) => ({
    data: {
      cdEnvironmentCreate: {
        __typename: 'CdEnvironmentCreatePayload',
        environment: errors.length
          ? null
          : {
              __typename: 'CdEnvironment',
              id: 'gid://gitlab/Cd::Environment/1',
              name: 'eu-west-1-prod',
              tier: 'PRODUCTION',
              environmentDriverBindings: {
                __typename: 'CdEnvironmentDriverBindingConnection',
                nodes: [makeCdEnvironmentDriverBinding()],
              },
            },
        errors,
      },
    },
  });

  const defaultMutationHandler = jest.fn().mockResolvedValue(buildResponse());
  const defaultTiersHandler = jest.fn().mockResolvedValue(buildQueryResponse(tiers));
  const defaultAgentsHandler = jest
    .fn()
    .mockResolvedValue(buildDefaultAvailableAgentsQueryResponse());

  const findMountingPortal = () => wrapper.findComponent(MountingPortal);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findPanelFormGroups = () => wrapper.findAllComponents(PanelFormGroup);
  const findPanelFormGroup = () => findPanelFormGroups().at(0);
  const findTargetFormGroup = () => findPanelFormGroups().at(1);
  const findPanelFormFields = () => wrapper.findAllComponents(PanelFormField);
  const findNameField = () => findPanelFormFields().at(0);
  const findAgentField = () => findPanelFormFields().at(3);
  const findNameInput = () => wrapper.findComponent('#environment-name');
  const findTierListbox = () => wrapper.findComponentByTestId('tier-listbox');
  const findTypeListbox = () => wrapper.findComponentByTestId('type-listbox');
  const findAgentListbox = () => wrapper.findComponentByTestId('agent-listbox');
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-button');
  const findSubmitButton = () => wrapper.findComponentByTestId('submit-environment-button');

  const createComponent = ({
    open = true,
    mutationHandler = defaultMutationHandler,
    tiersHandler = defaultTiersHandler,
    agentsHandler = defaultAgentsHandler,
  } = {}) => {
    apolloProvider = createMockApollo([
      [cdEnvironmentCreateMutation, mutationHandler],
      [cdEnvironmentTiersQuery, tiersHandler],
      [cdAvailableAgentsQuery, agentsHandler],
    ]);
    apolloProvider.defaultClient.cache.writeQuery({
      query: cdEnvironmentsQuery,
      variables: queryVariables,
      data: buildEnvironmentsQueryResponse().data,
    });

    wrapper = shallowMountExtended(NewEnvironmentPanel, {
      apolloProvider,
      propsData: { open, queryVariables },
      stubs: {
        DynamicPanel,
        MountingPortal: stubComponent(MountingPortal, { name: 'MountingPortal' }),
      },
    });
  };

  const submit = async (name = 'eu-west-1-prod') => {
    findNameInput().vm.$emit('input', name);
    findSubmitButton().vm.$emit('click');
    await waitForPromises();
  };

  const selectAgent = (agentId = 'gid://gitlab/Clusters::Agent/2') =>
    findAgentListbox().vm.$emit('select', agentId);

  describe('when open is false', () => {
    beforeEach(() => {
      createComponent({ open: false });
    });

    it('does not render the panel', () => {
      expect(findMountingPortal().exists()).toBe(false);
    });
  });

  describe('when open is true', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the header text', () => {
      expect(wrapper.text()).toContain('Register environment');
    });

    it('renders the form group with its step, title, and description', () => {
      expect(findPanelFormGroup().props()).toEqual({
        step: '1',
        title: 'Environment identity',
        description: 'A short name and the tier it represents.',
      });
    });

    it('renders the name field with its placeholder', () => {
      expect(findNameField().props('label')).toBe('Environment name');
      expect(findNameInput().attributes('placeholder')).toBe('e.g. eu-west-1-prod');
    });

    it('renders the tier options and selects the first tier by default', () => {
      expect(findTierListbox().props('items')).toEqual([
        { value: 'DEVELOPMENT', text: 'Development' },
        { value: 'STAGING', text: 'Staging' },
        { value: 'PRODUCTION', text: 'Production' },
      ]);
      expect(findTierListbox().props('selected')).toBe('DEVELOPMENT');
    });

    it('renders the Target form group with its step, title, and description', () => {
      expect(findTargetFormGroup().props()).toEqual({
        step: '2',
        title: 'Target',
        description:
          'The cluster that backs this environment. Deploy connects through a GitLab Agent — no cluster endpoint required.',
      });
    });

    it('renders a disabled type listbox hard-coded to Argo Rollouts', () => {
      expect(findTypeListbox().props('disabled')).toBe(true);
      expect(findTypeListbox().props('selected')).toBe(ENVIRONMENT_DRIVER_REF);
      expect(findTypeListbox().props('items')).toEqual([
        { value: ENVIRONMENT_DRIVER_REF, text: 'Kubernetes (Argo Rollouts)' },
      ]);
    });

    it('renders the available agents with the select-agent entry selected by default', () => {
      expect(findAgentListbox().props('items')).toEqual([
        { value: 'select-agent', text: 'Select an agent' },
        { value: 'gid://gitlab/Clusters::Agent/1', text: 'production-agent' },
        { value: 'gid://gitlab/Clusters::Agent/2', text: 'staging-agent' },
      ]);
      expect(findAgentListbox().props('selected')).toBe('select-agent');
      expect(findAgentListbox().props('toggleText')).toBe('Select an agent');
      expect(findAgentListbox().props('loading')).toBe(false);
    });

    it('enables the submit button', () => {
      expect(findSubmitButton().props('disabled')).toBe(false);
    });
  });

  describe('while the agents query is in flight', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows the agent listbox as loading', () => {
      expect(findAgentListbox().props('loading')).toBe(true);
    });
  });

  describe('name validation', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('does not flag the field as invalid by default', () => {
      expect(findNameField().props('state')).toBe(null);
    });

    it('flags a blank name and does not call the mutation on submit', async () => {
      await submit('');

      expect(findNameField().props('state')).toBe(false);
      expect(findNameField().props('invalidFeedback')).toBe('Name is required.');
      expect(defaultMutationHandler).not.toHaveBeenCalled();
    });

    it('flags a name that exceeds the max length', async () => {
      findNameInput().vm.$emit('input', 'a'.repeat(256));
      await waitForPromises();

      expect(findNameField().props('state')).toBe(false);
      expect(findNameField().props('invalidFeedback')).toBe('Name cannot exceed 255 characters.');
    });
  });

  describe('on successful submission', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      selectAgent();
      await submit();
    });

    it('sends only the selected agent id in the driver config', () => {
      expect(defaultMutationHandler).toHaveBeenCalledWith({
        input: {
          name: 'eu-west-1-prod',
          tier: 'DEVELOPMENT',
          organizationId,
          environmentDriverBinding: {
            driverRef: ENVIRONMENT_DRIVER_REF,
            driverConfig: { cluster_agent_id: '2' },
          },
        },
      });
    });

    it('adds the created environment to the environments query cache', () => {
      const cache = apolloProvider.defaultClient.cache.readQuery({
        query: cdEnvironmentsQuery,
        variables: queryVariables,
      });

      expect(cache.organization.cdEnvironments.nodes).toHaveLength(1);
      expect(cache.organization.cdEnvironments.nodes.at(-1)).toMatchObject({
        id: 'gid://gitlab/Cd::Environment/1',
        name: 'eu-west-1-prod',
        tier: 'PRODUCTION',
        environmentDriverBindings: {
          nodes: [makeCdEnvironmentDriverBinding()],
        },
      });
    });

    it('emits close', () => {
      expect(wrapper.emitted('close')).toEqual([[]]);
    });
  });

  describe('when an agent is selected', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      selectAgent();
    });

    it('shows the selected agent name', () => {
      expect(findAgentListbox().props('toggleText')).toBe('staging-agent');
    });

    it('keeps the select-agent entry in the listbox', () => {
      expect(findAgentListbox().props('items')).toContainEqual({
        value: 'select-agent',
        text: 'Select an agent',
      });
    });

    it('does not flag the agent field as invalid', async () => {
      await submit();

      expect(findAgentField().props('state')).toBe(null);
      expect(findAgentListbox().props('state')).toBe(null);
    });
  });

  describe('when no agent is selected', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('does not flag the agent field as invalid before submitting', () => {
      expect(findAgentField().props('state')).toBe(null);
      expect(findAgentListbox().props('state')).toBe(null);
    });

    it('flags the agent field and does not call the mutation on submit', async () => {
      await submit();

      expect(findAgentField().props('state')).toBe(false);
      expect(findAgentField().props('invalidFeedback')).toBe('Select a GitLab Agent.');
      expect(defaultMutationHandler).not.toHaveBeenCalled();
    });

    // The form group renders the feedback text, but only the listbox's own state prop
    // gives the control an invalid border, the way nameState does for the name input.
    it('marks the listbox itself invalid on submit', async () => {
      await submit();

      expect(findAgentListbox().props('state')).toBe(false);
    });
  });

  describe('when the select-agent entry is re-selected', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      selectAgent();
      selectAgent('select-agent');
      await submit();
    });

    it('flags the agent field and does not call the mutation', () => {
      expect(findAgentField().props('state')).toBe(false);
      expect(findAgentListbox().props('state')).toBe(false);
      expect(defaultMutationHandler).not.toHaveBeenCalled();
    });
  });

  describe('when the agents query fails', () => {
    beforeEach(async () => {
      createComponent({ agentsHandler: jest.fn().mockRejectedValue(new Error('agents error')) });
      await waitForPromises();
    });

    it('renders an error and reports the exception to Sentry', () => {
      expect(findAlert().text()).toBe(
        'Failed to load GitLab agents. Refresh the page to try again.',
      );
      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('agents error'));
    });
  });

  describe('when the mutation returns errors', () => {
    beforeEach(async () => {
      createComponent({ mutationHandler: jest.fn().mockResolvedValue(buildResponse(['Taken'])) });
      await waitForPromises();
      selectAgent();
      await submit();
    });

    it('renders the errors and does not emit close', () => {
      expect(findAlert().text()).toBe('Taken');
      expect(wrapper.emitted('close')).toBeUndefined();
    });

    it('does not add anything to the environments query cache', () => {
      const cache = apolloProvider.defaultClient.cache.readQuery({
        query: cdEnvironmentsQuery,
        variables: queryVariables,
      });

      expect(cache.organization.cdEnvironments.nodes).toHaveLength(0);
    });
  });

  describe('when the mutation throws', () => {
    beforeEach(async () => {
      createComponent({ mutationHandler: jest.fn().mockRejectedValue(new Error('network error')) });
      await waitForPromises();
      selectAgent();
      await submit();
    });

    it('renders a generic error and reports to Sentry', () => {
      expect(findAlert().text()).toBe('An error occurred. Please try again.');
      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('network error'));
    });
  });

  describe('when the tiers query has not resolved yet', () => {
    beforeEach(() => {
      createComponent();
    });

    it('disables the submit button', () => {
      expect(findSubmitButton().props('disabled')).toBe(true);
    });

    it('does not call the mutation on submit', async () => {
      selectAgent();
      await submit();

      expect(defaultMutationHandler).not.toHaveBeenCalled();
    });
  });

  describe('when the tiers query fails', () => {
    beforeEach(async () => {
      createComponent({ tiersHandler: jest.fn().mockRejectedValue(new Error('tiers error')) });
      await waitForPromises();
    });

    it('reports the exception to Sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('tiers error'));
    });

    it('keeps the submit button disabled', () => {
      expect(findSubmitButton().props('disabled')).toBe(true);
    });

    it('does not call the mutation on submit', async () => {
      selectAgent();
      await submit();

      expect(defaultMutationHandler).not.toHaveBeenCalled();
    });
  });

  describe('when the Cancel button is clicked', () => {
    beforeEach(() => {
      createComponent();
      findCancelButton().vm.$emit('click');
    });

    it('emits close', () => {
      expect(wrapper.emitted('close')).toEqual([[]]);
    });
  });
});
