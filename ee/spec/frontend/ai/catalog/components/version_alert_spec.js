import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { visitUrl } from '~/lib/utils/url_utility';
import VersionAlert from 'ee/ai/catalog/components/version_alert.vue';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import updateAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_item_consumer.mutation.graphql';
import { AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_AGENT } from 'ee/ai/catalog/constants';
import {
  mockUpdateAiCatalogItemConsumerSuccess,
  mockUpdateAiCatalogItemConsumerError,
  mockAiCatalogAgentResponse,
  mockAiCatalogFlowResponse,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

Vue.use(VueApollo);

describe('VersionAlert', () => {
  let wrapper;
  let mockApollo;

  const UPDATE_MESSAGES = {
    project: {
      flow: 'Only this flow in this project will be updated. Other projects using this flow will not be affected.',
      agent:
        'Only this agent in this project will be updated. Other projects using this agent will not be affected.',
    },
    group: {
      flow: "Updating a flow in this group does not update the flows enabled in this group's projects.",
      agent:
        "Updating an agent in this group does not update the agents enabled in this group's projects.",
    },
  };

  const SUCCESS_TOAST_MESSAGES = {
    flow: 'Flow is now at version 2.0.0.',
    agent: 'Agent is now at version 2.0.0.',
  };

  const mockLatestVersion = {
    humanVersionName: 'v2.0.0',
    versionName: '2.0.0',
  };

  const mockConfiguration = {
    id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
    groupId: null,
  };

  const mockAgentItemId = 'gid://gitlab/Ai::Catalog::Item/1';
  const mockFlowItemId = 'gid://gitlab/Ai::Catalog::Item/4';

  const mockToast = {
    show: jest.fn(),
  };

  const mockAgentQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogAgentResponse);
  const mockFlowQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogFlowResponse);
  const mockUpdateAiCatalogItemConsumerHandler = jest
    .fn()
    .mockResolvedValue(mockUpdateAiCatalogItemConsumerSuccess);

  const createComponent = ({ props = {}, provide = {}, mocks = {} } = {}) => {
    const defaultProps = {
      itemType: AI_CATALOG_TYPE_FLOW,
      itemId: mockFlowItemId,
      configuration: mockConfiguration,
      latestVersion: mockLatestVersion,
      ...props,
    };

    const defaultProvide = {
      isProjectNamespace: true,
      isGroupNamespace: false,
      ...provide,
    };

    const defaultMocks = {
      $toast: mockToast,
      ...mocks,
    };

    mockApollo = createMockApollo([
      [aiCatalogAgentQuery, mockAgentQueryHandler],
      [aiCatalogFlowQuery, mockFlowQueryHandler],
      [updateAiCatalogItemConsumer, mockUpdateAiCatalogItemConsumerHandler],
    ]);

    mockApollo.defaultClient.watchQuery({ query: aiCatalogAgentQuery }).subscribe();
    mockApollo.defaultClient.watchQuery({ query: aiCatalogFlowQuery }).subscribe();

    wrapper = shallowMountExtended(VersionAlert, {
      apolloProvider: mockApollo,
      propsData: defaultProps,
      provide: defaultProvide,
      mocks: defaultMocks,
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findPrimaryButtonText = () => findAlert().props('primaryButtonText');
  const findSecondaryButtonText = () => findAlert().props('secondaryButtonText');

  describe('button labels', () => {
    beforeEach(() => {
      createComponent();
    });

    it('always shows "Update" as the primary button', () => {
      expect(findPrimaryButtonText()).toBe('Update');
    });

    it('always shows "View latest version" as the secondary button', () => {
      expect(findSecondaryButtonText()).toBe('View latest version');
    });
  });

  describe('"View latest version" button navigates to Explore URL', () => {
    it('opens the Explore flow URL in a new tab for a flow item type', () => {
      createComponent({
        props: { itemType: AI_CATALOG_TYPE_FLOW, itemId: mockFlowItemId },
      });

      findAlert().vm.$emit('secondaryAction');

      expect(visitUrl).toHaveBeenCalledWith('/explore/ai-catalog/flows/4', true);
    });

    it('opens the Explore agent URL in a new tab for an agent item type', () => {
      createComponent({
        props: { itemType: AI_CATALOG_TYPE_AGENT, itemId: mockAgentItemId },
      });

      findAlert().vm.$emit('secondaryAction');

      expect(visitUrl).toHaveBeenCalledWith('/explore/ai-catalog/agents/1', true);
    });
  });

  describe.each([
    {
      namespace: 'project',
      isProjectNamespace: true,
      isGroupNamespace: false,
    },
    {
      namespace: 'group',
      isProjectNamespace: false,
      isGroupNamespace: true,
    },
  ])('when in the $namespace namespace', ({ namespace, isProjectNamespace, isGroupNamespace }) => {
    describe.each([
      { itemType: AI_CATALOG_TYPE_FLOW, itemName: 'flow', itemId: mockFlowItemId },
      { itemType: AI_CATALOG_TYPE_AGENT, itemName: 'agent', itemId: mockAgentItemId },
    ])('with $itemName item type', ({ itemType, itemName, itemId }) => {
      describe('update message', () => {
        beforeEach(() => {
          createComponent({
            props: { itemType, itemId },
            provide: { isProjectNamespace, isGroupNamespace },
          });
        });

        it(`displays the ${namespace} update message for ${itemName}`, () => {
          expect(wrapper.text()).toContain(UPDATE_MESSAGES[namespace][itemName]);
        });
      });

      describe('"Update" button', () => {
        beforeEach(() => {
          createComponent({
            props: { itemType, itemId },
            provide: { isProjectNamespace, isGroupNamespace },
          });
        });

        it('calls the update mutation with correct version prefix', async () => {
          await findAlert().vm.$emit('primaryAction');

          expect(mockUpdateAiCatalogItemConsumerHandler).toHaveBeenCalledWith({
            input: {
              id: mockConfiguration.id,
              pinnedVersionPrefix: mockLatestVersion.versionName,
            },
          });
        });

        describe('when the request succeeds', () => {
          beforeEach(async () => {
            await findAlert().vm.$emit('primaryAction');
            await waitForPromises();
          });

          it(`shows success toast for ${itemName}`, () => {
            expect(mockToast.show).toHaveBeenCalledWith(SUCCESS_TOAST_MESSAGES[itemName]);
          });
        });

        describe('when the request succeeds but with errors', () => {
          it('emits an error message', async () => {
            mockUpdateAiCatalogItemConsumerHandler.mockResolvedValueOnce(
              mockUpdateAiCatalogItemConsumerError,
            );
            await findAlert().vm.$emit('primaryAction');
            await waitForPromises();

            expect(wrapper.emitted('error')).toHaveLength(1);
            expect(wrapper.emitted('error')[0]).toEqual([
              expect.objectContaining({
                title: `Could not update ${itemName}.`,
                errors: ['Some error'],
              }),
            ]);
          });
        });

        describe('when the request fails', () => {
          it('emits an error message', async () => {
            mockUpdateAiCatalogItemConsumerHandler.mockRejectedValueOnce();
            await findAlert().vm.$emit('primaryAction');
            await waitForPromises();

            expect(wrapper.emitted('error')).toHaveLength(1);
            expect(wrapper.emitted('error')[0][0]).toEqual(
              expect.objectContaining({
                errors: expect.arrayContaining([
                  expect.stringContaining(`Could not update ${itemName}`),
                ]),
              }),
            );
          });
        });

        describe('when the response has no data', () => {
          beforeEach(async () => {
            mockUpdateAiCatalogItemConsumerHandler.mockResolvedValueOnce({ data: null });
            await findAlert().vm.$emit('primaryAction');
            await waitForPromises();
          });

          it('emits an error message', () => {
            expect(wrapper.emitted('error')).toHaveLength(1);
            expect(wrapper.emitted('error')[0][0]).toEqual(
              expect.objectContaining({
                errors: expect.arrayContaining([
                  expect.stringContaining(`Could not update ${itemName}`),
                ]),
              }),
            );
          });

          it('captures the exception in Sentry', () => {
            expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
          });
        });
      });
    });
  });
});
