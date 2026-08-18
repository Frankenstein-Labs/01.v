import { sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getText, findButtonByText, waitForAssertion } from 'ee_jest/msw_integration/test_helpers';
import AiCatalogItem from 'ee/ai/catalog/pages/ai_catalog_item.vue';
import {
  AI_CATALOG_ITEM_LABELS,
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
} from 'ee/ai/catalog/constants';
import {
  agentResponse,
  agentPinnedToLatestResponse,
  flowResponse,
  flowPinnedToLatestResponse,
  resetAiCatalogCache,
  updateConsumerResponse,
} from 'ee_jest/msw_integration/handlers/ai_catalog';
import { mountAiCatalogComponent, createApolloProvider, PROJECT_PROVIDE } from './test_setup';

const UPDATE_ALERT_TEXT = 'A new version is available';

const TOAST_SUCCESS_MESSAGE = {
  [AI_CATALOG_TYPE_AGENT]: 'Agent is now at version %{newVersion}.',
  [AI_CATALOG_TYPE_FLOW]: 'Flow is now at version %{newVersion}.',
};

const VERSIONING_CONFIGS = [
  {
    itemType: AI_CATALOG_TYPE_AGENT,
    component: AiCatalogItem,
    fixtureResponse: agentResponse,
    pinnedToLatestResponse: agentPinnedToLatestResponse,
    routePath: '/agents/1',
    explorePath: '/explore/ai-catalog/agents',
  },
  {
    itemType: AI_CATALOG_TYPE_FLOW,
    component: AiCatalogItem,
    fixtureResponse: flowResponse,
    pinnedToLatestResponse: flowPinnedToLatestResponse,
    routePath: '/flows/1',
    explorePath: '/explore/ai-catalog/flows',
  },
];

describe.each(VERSIONING_CONFIGS)(
  '$itemType version pinning',
  ({ itemType, component, fixtureResponse, pinnedToLatestResponse, routePath, explorePath }) => {
    let apolloProvider;

    // The alert's "View latest version" opens the Explore page in a new tab, and
    // jsdom has no window.open implementation to fall back on.
    beforeEach(() => {
      jest.spyOn(window, 'open').mockImplementation(() => null);
    });

    afterEach(() => {
      apolloProvider?.defaultClient?.stop();
    });

    const mount = () => {
      apolloProvider = createApolloProvider();
      mountAiCatalogComponent({
        component,
        routePath,
        apolloProvider,
        provide: PROJECT_PROVIDE,
        propsData: { itemType },
      });
    };

    describe('when update is available', () => {
      const itemLabel = AI_CATALOG_ITEM_LABELS[itemType];
      const item = fixtureResponse.data.aiCatalogItem;
      const itemName = item.name;
      const pinnedVersion = item.configurationForProject.pinnedItemVersion.humanVersionName;
      const latestVersion = item.latestVersion.humanVersionName;

      beforeEach(() => {
        resetAiCatalogCache();
      });

      describe('Version display', () => {
        it(`shows ${itemLabel} name and pinned version by default`, async () => {
          mount();

          await waitForAssertion(() => {
            const text = getText(document.body);
            expect(text).toContain(itemName);
            expect(text).toContain(pinnedVersion);
          });
        });

        it('shows version alert when update is available', async () => {
          mount();

          await waitForAssertion(() => {
            expect(getText(document.body)).toContain(itemName);
          });

          expect(getText(document.body)).toContain(UPDATE_ALERT_TEXT);
        });
      });

      describe('View latest version', () => {
        it('clicking "View latest version" opens the Explore page in a new tab', async () => {
          mount();

          await waitForAssertion(() => {
            expect(getText(document.body)).toContain(pinnedVersion);
          });

          findButtonByText('View latest version').click();

          expect(window.open).toHaveBeenCalledWith(`${explorePath}/${getIdFromGraphQLId(item.id)}`);
        });
      });

      describe('Update to latest version', () => {
        it('updates content and shows confirmation toast after clicking "Update"', async () => {
          mount();

          await waitForAssertion(() => {
            expect(getText(document.body)).toContain(pinnedVersion);
          });

          findButtonByText('Update').click();

          await waitForAssertion(() => {
            expect(getText(document.body)).not.toContain(UPDATE_ALERT_TEXT);
          });

          expect(getText(document.body)).toContain(latestVersion);

          const expectedMessage = sprintf(TOAST_SUCCESS_MESSAGE[itemType], {
            newVersion:
              updateConsumerResponse.data.aiCatalogItemConsumerUpdate.itemConsumer
                .pinnedVersionPrefix,
          });
          expect(getText(document.body)).toContain(expectedMessage);
        });
      });
    });

    describe('when no update is available', () => {
      const latestVersion =
        pinnedToLatestResponse.data.aiCatalogItem.latestVersion.humanVersionName;

      beforeEach(() => {
        const cacheKey = itemType === AI_CATALOG_TYPE_AGENT ? 'agent' : 'flow';
        resetAiCatalogCache({ [cacheKey]: pinnedToLatestResponse });
      });

      it('does not show version alert when pinned to latest', async () => {
        mount();

        await waitForAssertion(() => {
          expect(getText(document.body)).toContain(latestVersion);
        });

        expect(getText(document.body)).not.toContain(UPDATE_ALERT_TEXT);
      });
    });
  },
);
