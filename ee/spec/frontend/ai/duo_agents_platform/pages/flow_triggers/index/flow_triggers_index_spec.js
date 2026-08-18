import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import ResourceListsLoadingStateList from '~/vue_shared/components/resource_lists/loading_state_list.vue';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import FlowTriggersIndex from 'ee/ai/duo_agents_platform/pages/flow_triggers/index/flow_triggers_index.vue';
import FlowTriggersTable from 'ee/ai/duo_agents_platform/pages/flow_triggers/index/components/flow_triggers_table.vue';
import FlowTriggersCta from 'ee/ai/duo_agents_platform/pages/flow_triggers/index/components/flow_triggers_cta.vue';
import getProjectAiFlowTriggers from 'ee/ai/duo_agents_platform/graphql/queries/get_ai_flow_triggers.query.graphql';
import deleteAiFlowTriggerMutation from 'ee/ai/duo_agents_platform/graphql/mutations/delete_ai_flow_trigger.mutation.graphql';
import {
  mockAiFlowTriggersResponse,
  mockEmptyAiFlowTriggersResponse,
  mockNullProjectAiFlowTriggersResponse,
  mockDeleteTriggerResponse,
} from '../mocks';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('FlowTriggersIndex', () => {
  let wrapper;
  let mockApollo;

  const mockFlowTriggerQueryHandler = jest.fn().mockResolvedValue(mockAiFlowTriggersResponse);
  const mockFlowDeleteMutationHandler = jest.fn().mockResolvedValue(mockDeleteTriggerResponse);

  const findLoadingStateList = () => wrapper.findComponent(ResourceListsLoadingStateList);
  const findEmptyState = () => wrapper.findComponent(ResourceListsEmptyState);
  const findTable = () => wrapper.findComponent(FlowTriggersTable);
  const findConfirmModal = () => wrapper.findComponent(ConfirmActionModal);
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findNewTriggerButton = () => wrapper.findComponent(FlowTriggersCta);

  const createWrapper = ({
    queryHandler = mockFlowTriggerQueryHandler,
    mutationHandler = mockFlowDeleteMutationHandler,
  } = {}) => {
    mockApollo = createMockApollo([
      [getProjectAiFlowTriggers, queryHandler],
      [deleteAiFlowTriggerMutation, mutationHandler],
    ]);

    wrapper = shallowMountExtended(FlowTriggersIndex, {
      apolloProvider: mockApollo,
      provide: {
        projectPath: 'myProject',
        glAbilities: {
          readAiCatalogFlow: true,
          readAiCatalogThirdPartyFlow: true,
          createAiCatalogThirdPartyFlow: true,
        },
      },
    });
  };

  beforeEach(() => {
    createAlert.mockClear();
    createWrapper();
  });

  describe('Rendering', () => {
    it('loads the page heading and "New trigger" button', () => {
      expect(findPageHeading().props('heading')).toBe('Triggers');

      expect(findNewTriggerButton().exists()).toBe(true);
    });

    describe('"New trigger" button', () => {
      describe('when only readAiCatalogFlow is true', () => {
        beforeEach(() => {
          createWrapper({
            provide: {
              glAbilities: {
                readAiCatalogFlow: true,
                readAiCatalogThirdPartyFlow: false,
                createAiCatalogThirdPartyFlow: false,
              },
            },
          });
        });

        it('shows the button', () => {
          expect(findNewTriggerButton().exists()).toBe(true);
        });
      });

      describe('when only readAiCatalogThirdPartyFlow is true', () => {
        beforeEach(() => {
          createWrapper({
            provide: {
              glAbilities: {
                readAiCatalogFlow: false,
                readAiCatalogThirdPartyFlow: true,
                createAiCatalogThirdPartyFlow: false,
              },
            },
          });
        });

        it('shows the button', () => {
          expect(findNewTriggerButton().exists()).toBe(true);
        });
      });

      describe('when only createAiCatalogThirdPartyFlow is true', () => {
        beforeEach(() => {
          createWrapper({
            provide: {
              glAbilities: {
                readAiCatalogFlow: false,
                readAiCatalogThirdPartyFlow: false,
                createAiCatalogThirdPartyFlow: true,
              },
            },
          });
        });

        it('shows the button', () => {
          expect(findNewTriggerButton().exists()).toBe(true);
        });
      });

      describe('when all three are false', () => {
        beforeEach(() => {
          createWrapper({
            provide: {
              glAbilities: {
                readAiCatalogFlow: false,
                readAiCatalogThirdPartyFlow: false,
                createAiCatalogThirdPartyFlow: false,
              },
            },
          });
        });

        it('hides the button', () => {
          expect(findNewTriggerButton().exists()).toBe(true);
        });
      });
    });

    describe('while fetching data', () => {
      it('shows a loading state', () => {
        expect(findLoadingStateList().exists()).toBe(true);
      });

      it('does not show an empty state', () => {
        expect(findEmptyState().exists()).toBe(false);
      });

      it('does not show a table of triggers', () => {
        expect(findTable().exists()).toBe(false);
      });
    });

    describe('when the data is loaded', () => {
      describe('and there is data', () => {
        beforeEach(async () => {
          await waitForPromises();
        });

        it('fetches list data', () => {
          expect(mockFlowTriggerQueryHandler).toHaveBeenCalled();
        });

        it('shows a table of triggers', () => {
          expect(findTable().exists()).toBe(true);
        });

        it('does not show an empty state', () => {
          expect(findEmptyState().exists()).toBe(false);
        });

        it('does not show a loading state', () => {
          expect(findLoadingStateList().exists()).toBe(false);
        });
      });

      describe('and there is no data', () => {
        beforeEach(async () => {
          createWrapper({ queryHandler: mockEmptyAiFlowTriggersResponse });
          await waitForPromises();
        });

        it('shows an empty state', () => {
          expect(findEmptyState().exists()).toBe(true);
        });

        it('does not show a loading state', () => {
          expect(findLoadingStateList().exists()).toBe(false);
        });

        it('does not show a table of triggers', () => {
          expect(findTable().exists()).toBe(false);
        });
      });

      describe('but the request failed', () => {
        const error = new Error();

        beforeEach(async () => {
          createWrapper({ queryHandler: jest.fn().mockRejectedValue(error) });
          await waitForPromises();
        });

        it('creates an error alert', () => {
          expect(createAlert).toHaveBeenCalledWith({
            captureError: true,
            message: 'Failed to fetch triggers',
          });
        });

        it('shows an empty state', () => {
          expect(findEmptyState().exists()).toBe(true);
          expect(findEmptyState().props().svgPath).toBeDefined();
        });

        it('does not show a loading state', () => {
          expect(findLoadingStateList().exists()).toBe(false);
        });
      });

      describe('and the project is null (e.g. user lacks access)', () => {
        beforeEach(async () => {
          createWrapper({
            queryHandler: jest.fn().mockResolvedValue(mockNullProjectAiFlowTriggersResponse),
          });
          await waitForPromises();
        });

        it('shows an empty state', () => {
          expect(findEmptyState().exists()).toBe(true);
        });

        it('does not show a loading state', () => {
          expect(findLoadingStateList().exists()).toBe(false);
        });

        it('does not show a table of triggers', () => {
          expect(findTable().exists()).toBe(false);
        });
      });
    });
  });

  describe('Interactions', () => {
    describe('when the user clicked on a delete button', () => {
      beforeEach(async () => {
        await waitForPromises();
        const tableComponent = findTable();
        tableComponent.vm.$emit('delete-trigger', '1');
      });

      it('opens confirm modal on delete', () => {
        expect(findConfirmModal().exists()).toBe(true);
      });

      describe('and the user confirms deletion', () => {
        beforeEach(async () => {
          findConfirmModal().props('actionFn')();
          await waitForPromises();
        });

        it('hides the modal', () => {
          expect(findConfirmModal().exists()).toBe(false);
        });

        it('performs delete action', () => {
          expect(mockFlowDeleteMutationHandler).toHaveBeenCalledWith({
            id: '1',
          });
        });
      });
    });
  });
});
