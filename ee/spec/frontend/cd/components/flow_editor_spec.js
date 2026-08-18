import { GlBadge, GlLoadingIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import SourceEditor from '~/vue_shared/components/source_editor.vue';
import FlowEditor from 'ee/cd/components/flow_editor.vue';
import cdApplicationFlowQuery from 'ee/cd/graphql/cd_application_flow.query.graphql';
import cdApplicationFlowDefinitionCreateMutation from 'ee/cd/graphql/cd_application_flow_definition_create.mutation.graphql';

Vue.use(VueApollo);

describe('FlowEditor', () => {
  let wrapper;
  let pushSpy;

  const id = '7';
  const applicationGid = 'gid://gitlab/Cd::Application/7';
  const showRoute = { name: 'applications_show_route', params: { id: '7' } };

  const flowV2 = {
    id: 'gid://gitlab/Cd::ApplicationFlowDefinition/2',
    version: 2,
    definition: 'trigger:\n  type: pipeline\n',
  };

  const buildResponse = (nodes = [flowV2]) => ({
    data: {
      organization: {
        id: 'gid://gitlab/Organizations::Organization/1',
        cdApplication: {
          id: applicationGid,
          name: 'payments-platform',
          applicationFlowDefinitions: { nodes },
        },
      },
    },
  });

  const createSuccess = {
    data: {
      cdApplicationFlowDefinitionCreate: {
        applicationFlowDefinition: {
          id: 'gid://gitlab/Cd::ApplicationFlowDefinition/3',
          version: 3,
          definition: 'steps: []\n',
        },
        errors: [],
      },
    },
  };

  const defaultQueryHandler = jest.fn().mockResolvedValue(buildResponse());
  let createHandler;

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findLoadError = () => wrapper.findByTestId('flow-editor-load-error-alert');
  const findNotFound = () => wrapper.findByTestId('flow-editor-not-found');
  const findSaveError = () => wrapper.findByTestId('flow-editor-error-alert');
  const findEditor = () => wrapper.findComponentByTestId('flow-source-editor');
  const findBackButton = () => wrapper.findComponentByTestId('back-button');
  const findDiscardButton = () => wrapper.findComponentByTestId('discard-flow-button');
  const findSaveButton = () => wrapper.findComponentByTestId('save-flow-button');

  const editDraft = async (value) => {
    findEditor().vm.$emit('input', value);
    await nextTick();
  };

  const createComponent = ({
    queryHandler = defaultQueryHandler,
    mutationHandler = createHandler,
  } = {}) => {
    pushSpy = jest.fn();
    wrapper = shallowMountExtended(FlowEditor, {
      apolloProvider: createMockApollo([
        [cdApplicationFlowQuery, queryHandler],
        [cdApplicationFlowDefinitionCreateMutation, mutationHandler],
      ]),
      propsData: { id },
      mocks: { $router: { push: pushSpy } },
      stubs: { SourceEditor: stubComponent(SourceEditor) },
    });
  };

  beforeEach(() => {
    createHandler = jest.fn().mockResolvedValue(createSuccess);
  });

  describe('while loading', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the loading icon and not the editor', () => {
      expect(findLoadingIcon().exists()).toBe(true);
      expect(findEditor().exists()).toBe(false);
    });
  });

  describe('when the query errors', () => {
    beforeEach(async () => {
      createComponent({ queryHandler: jest.fn().mockRejectedValue(new Error('boom')) });
      await waitForPromises();
    });

    it('renders the load error and not the editor', () => {
      expect(findLoadError().exists()).toBe(true);
      expect(findEditor().exists()).toBe(false);
    });
  });

  describe('when the application is not found', () => {
    beforeEach(async () => {
      const notFound = {
        data: {
          organization: { id: 'gid://gitlab/Organizations::Organization/1', cdApplication: null },
        },
      };
      createComponent({ queryHandler: jest.fn().mockResolvedValue(notFound) });
      await waitForPromises();
    });

    it('renders the not-found empty state and not the editor', () => {
      expect(findNotFound().exists()).toBe(true);
      expect(findEditor().exists()).toBe(false);
    });
  });

  describe('with an existing flow', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the application name', () => {
      expect(wrapper.text()).toContain('payments-platform');
    });

    it('renders the next draft version', () => {
      expect(findBadge().text()).toBe('Draft v3');
    });

    it('seeds the editor with the latest definition', () => {
      expect(findEditor().props('value')).toBe('trigger:\n  type: pipeline\n');
    });

    it('disables save until the draft changes', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      await editDraft('changed');

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('links the back button to the show route', () => {
      expect(findBackButton().props('to')).toEqual(showRoute);
    });

    it('navigates back when discarding', () => {
      findDiscardButton().vm.$emit('click');

      expect(pushSpy).toHaveBeenCalledWith(showRoute);
    });
  });

  describe('with no flow yet', () => {
    beforeEach(async () => {
      createComponent({ queryHandler: jest.fn().mockResolvedValue(buildResponse([])) });
      await waitForPromises();
    });

    it('starts a v1 draft with an empty editor', () => {
      expect(findBadge().text()).toBe('Draft v1');
      expect(findEditor().props('value')).toBe('');
    });
  });

  describe('saving', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      await editDraft('steps: []\n');
    });

    it('runs the create mutation with the edited definition', async () => {
      findSaveButton().vm.$emit('click');
      await waitForPromises();

      expect(createHandler).toHaveBeenCalledWith({
        input: { applicationId: applicationGid, definition: 'steps: []\n' },
      });
    });

    it('navigates back on success', async () => {
      findSaveButton().vm.$emit('click');
      await waitForPromises();

      expect(pushSpy).toHaveBeenCalledWith(showRoute);
    });

    describe('when the mutation returns errors', () => {
      beforeEach(async () => {
        createHandler = jest.fn().mockResolvedValue({
          data: {
            cdApplicationFlowDefinitionCreate: {
              applicationFlowDefinition: null,
              errors: ['Something went wrong'],
            },
          },
        });
        createComponent();
        await waitForPromises();
        await editDraft('steps: []\n');

        findSaveButton().vm.$emit('click');
        await waitForPromises();
      });

      it('shows the error and stays on the page', () => {
        expect(findSaveError().text()).toContain('Something went wrong');
        expect(pushSpy).not.toHaveBeenCalled();
      });
    });

    describe('when the mutation request fails', () => {
      beforeEach(async () => {
        createHandler = jest.fn().mockRejectedValue(new Error('network'));
        createComponent();
        await waitForPromises();
        await editDraft('steps: []\n');

        findSaveButton().vm.$emit('click');
        await waitForPromises();
      });

      it('shows a generic error and stays on the page', () => {
        expect(findSaveError().text()).toContain('Failed to save the flow');
        expect(pushSpy).not.toHaveBeenCalled();
      });
    });
  });
});
