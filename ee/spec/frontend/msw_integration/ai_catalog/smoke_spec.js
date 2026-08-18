import { waitFor, within } from '@testing-library/vue';
import { getText } from 'ee_jest/msw_integration/test_helpers';
import AiCatalogItem from 'ee/ai/catalog/pages/ai_catalog_item.vue';
import { AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_FLOW } from 'ee/ai/catalog/constants';
import { agentResponse, flowResponse } from 'ee_jest/msw_integration/handlers/ai_catalog';
import { mountAiCatalogComponent, createApolloProvider, EXPLORE_PROVIDE } from './test_setup';

const UPDATE_ALERT_TEXT = 'A new version is available';

const fixtureAgentName = agentResponse.data.aiCatalogItem.name;
const fixtureAgentLatestVersionName =
  agentResponse.data.aiCatalogItem.latestVersion.humanVersionName;
const fixtureFlowName = flowResponse.data.aiCatalogItem.name;
const fixtureFlowLatestVersionName = flowResponse.data.aiCatalogItem.latestVersion.humanVersionName;

describe('AI Catalog MSW smoke test', () => {
  let apolloProvider;

  beforeEach(async () => {
    await apolloProvider?.defaultClient?.cache?.reset();
  });

  describe('Agent show page', () => {
    beforeEach(() => {
      apolloProvider = createApolloProvider();
      mountAiCatalogComponent({
        component: AiCatalogItem,
        routePath: '/agents/1',
        apolloProvider,
        provide: EXPLORE_PROVIDE,
        propsData: { itemType: AI_CATALOG_TYPE_AGENT },
      });
    });

    it('renders the agent show page with fixture data from MSW', async () => {
      await waitFor(() => {
        expect(getText(document.body)).toContain(fixtureAgentName);
      });
    });

    it('passes aiCatalogItem and version props correctly to the item show component', async () => {
      await waitFor(() => {
        // aiCatalogItem: item name renders in the page heading
        expect(getText(document.body)).toContain(fixtureAgentName);

        // version.activeVersionKey = VERSION_LATEST: latest version name shown in metadata
        expect(getText(within(document.body).queryByTestId('metadata-version'))).toContain(
          fixtureAgentLatestVersionName,
        );

        // version.isUpdateAvailable = false: no update alert shown in explore context
        expect(getText(document.body)).not.toContain(UPDATE_ALERT_TEXT);
      });
    });
  });

  describe('Flow show page', () => {
    beforeEach(() => {
      apolloProvider = createApolloProvider();
      mountAiCatalogComponent({
        component: AiCatalogItem,
        routePath: '/flows/1',
        apolloProvider,
        provide: EXPLORE_PROVIDE,
        propsData: { itemType: AI_CATALOG_TYPE_FLOW },
      });
    });

    it('renders the flow show page with fixture data from MSW', async () => {
      await waitFor(() => {
        expect(getText(document.body)).toContain(fixtureFlowName);
      });
    });

    it('passes aiCatalogItem and version props correctly to the item show component', async () => {
      await waitFor(() => {
        // aiCatalogItem: item name renders in the page heading
        expect(getText(document.body)).toContain(fixtureFlowName);

        // version.activeVersionKey = VERSION_LATEST: latest version name shown in metadata
        expect(getText(within(document.body).queryByTestId('metadata-version'))).toContain(
          fixtureFlowLatestVersionName,
        );

        // version.isUpdateAvailable = false: no update alert shown in explore context
        expect(getText(document.body)).not.toContain(UPDATE_ALERT_TEXT);
      });
    });
  });
});
