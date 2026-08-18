import { GlAlert } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { SkipReason, itSkipVue3 } from 'helpers/vue3_conditional';
import { visitUrl } from '~/lib/utils/url_utility';
import AiCatalogItemShow from 'ee/ai/catalog/pages/ai_catalog_item_show.vue';
import AiCatalogItemEdit from 'ee/ai/catalog/pages/ai_catalog_item_edit.vue';
import AiCatalogItemDuplicate from 'ee/ai/catalog/pages/ai_catalog_item_duplicate.vue';
import { VERSION_PINNED, VERSION_PINNED_GROUP, VERSION_LATEST } from 'ee/ai/catalog/constants';
import updateAiCatalogConfiguredItem from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_item_consumer.mutation.graphql';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import {
  mockAgentVersion,
  mockAgentPinnedVersion,
  mockAgentGroupPinnedVersion,
  mockUpdateAiCatalogItemConsumerSuccess,
  mockAiCatalogAgentResponse,
} from '../mock_data';
import {
  createIntegrationWrapper,
  PROJECT_PROVIDE,
  GROUP_PROVIDE,
  EXPLORE_PROVIDE,
  ROUTE_PRESETS,
} from './helpers';
import { createAgentWithPermissions } from './mock_data_factories';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

const createVersionProp = ({
  isUpdateAvailable = false,
  activeVersionKey = VERSION_LATEST,
  baseVersionKey = VERSION_LATEST,
  setActiveVersionKey = jest.fn(),
} = {}) => ({
  isUpdateAvailable,
  activeVersionKey,
  baseVersionKey,
  setActiveVersionKey,
});

describe('Agent — version pinning integration', () => {
  const LATEST_PROMPT = 'latest-version-prompt';
  const PINNED_PROMPT = 'pinned-version-prompt';
  const GROUP_PINNED_PROMPT = 'group-pinned-version-prompt';

  const projectAgent = createAgentWithPermissions({
    pinnedVersion: { ...mockAgentPinnedVersion, systemPrompt: PINNED_PROMPT },
  });
  const groupAgent = createAgentWithPermissions({
    withProjectConfig: false,
    groupPinnedVersion: { ...mockAgentGroupPinnedVersion, systemPrompt: GROUP_PINNED_PROMPT },
  });
  const exploreAgent = {
    ...createAgentWithPermissions({ withProjectConfig: false, withGroupConfig: false }),
    latestVersion: { ...mockAgentVersion, systemPrompt: LATEST_PROMPT },
  };

  const mountShow = ({ provide, agent, versionProp, apolloHandlers = [], mocks = {} } = {}) => {
    const defaultAgent = agent || createAgentWithPermissions();

    return createIntegrationWrapper(AiCatalogItemShow, {
      provide,
      props: {
        aiCatalogItem: defaultAgent,
        version: versionProp,
      },
      apolloHandlers,
      route: ROUTE_PRESETS.agentShow,
      mocks,
    });
  };

  describe('Show page', () => {
    it('project namespace: shows pinned version content and version alert', async () => {
      const versionProp = createVersionProp({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED,
        baseVersionKey: VERSION_PINNED,
      });
      const { wrapper } = mountShow({ provide: PROJECT_PROVIDE, agent: projectAgent, versionProp });
      await waitForPromises();

      expect(wrapper.text()).toContain(PINNED_PROMPT);
      expect(wrapper.findComponent(GlAlert).text()).toContain('A new version is available');
    });

    it('group namespace: shows group pinned version content and version alert', async () => {
      const versionProp = createVersionProp({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED_GROUP,
        baseVersionKey: VERSION_PINNED_GROUP,
      });
      const { wrapper } = mountShow({ provide: GROUP_PROVIDE, agent: groupAgent, versionProp });
      await waitForPromises();

      expect(wrapper.text()).toContain(GROUP_PINNED_PROMPT);
      expect(wrapper.findComponent(GlAlert).text()).toContain('A new version is available');
    });

    it('explore namespace: shows latest version content and no version alert', async () => {
      const versionProp = createVersionProp({
        isUpdateAvailable: false,
        activeVersionKey: VERSION_LATEST,
        baseVersionKey: VERSION_LATEST,
      });
      const { wrapper } = mountShow({ provide: EXPLORE_PROVIDE, agent: exploreAgent, versionProp });
      await waitForPromises();

      expect(wrapper.text()).toContain(LATEST_PROMPT);
      expect(wrapper.findComponent(GlAlert).exists()).toBe(false);
    });
  });

  describe('Edit page', () => {
    const mountEdit = ({ versionProp, agent } = {}) => {
      const defaultAgent = agent || createAgentWithPermissions();

      return createIntegrationWrapper(AiCatalogItemEdit, {
        provide: PROJECT_PROVIDE,
        props: {
          aiCatalogItem: defaultAgent,
          version: versionProp,
        },
        apolloHandlers: [],
        route: ROUTE_PRESETS.agentEdit,
      });
    };

    const findAlerts = (wrapper) => wrapper.findAllComponents(GlAlert);

    it('warns that only the latest version is editable when pinned version differs', async () => {
      const versionProp = createVersionProp({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED,
        baseVersionKey: VERSION_PINNED,
      });
      const { wrapper } = mountEdit({ versionProp });
      await waitForPromises();

      const alerts = findAlerts(wrapper);
      expect(alerts.wrappers.some((a) => a.text().includes('edit only the latest version'))).toBe(
        true,
      );
    });

    it('does not warn when already viewing the latest version', async () => {
      const versionProp = createVersionProp({
        isUpdateAvailable: false,
        activeVersionKey: VERSION_LATEST,
        baseVersionKey: VERSION_LATEST,
      });
      const { wrapper } = mountEdit({ versionProp });
      await waitForPromises();

      const alerts = findAlerts(wrapper);
      expect(alerts.wrappers.some((a) => a.text().includes('edit only the latest version'))).toBe(
        false,
      );
    });
  });

  describe('Duplicate page', () => {
    const mountDuplicate = ({ provide, agent } = {}) => {
      const defaultAgent = agent || createAgentWithPermissions();

      return createIntegrationWrapper(AiCatalogItemDuplicate, {
        provide,
        props: { aiCatalogItem: defaultAgent },
        apolloHandlers: [],
        route: ROUTE_PRESETS.agentDuplicate,
      });
    };

    const findSystemPromptTextArea = (wrapper) =>
      wrapper.findByTestId('agent-form-textarea-system-prompt');

    // Vue Router 4 navigation is async — $route.params.id is undefined
    // in created() until the initial navigation completes. See linked issue.
    const vue3Skip = (name) =>
      new SkipReason({
        name,
        reason:
          'Vue Router 4 resolves navigation async — $route.params.id is undefined in created()',
        issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/593908',
      });

    itSkipVue3(
      vue3Skip('pre-fills system prompt from project pinned version on project namespace'),
      async () => {
        const { wrapper } = mountDuplicate({
          provide: { ...PROJECT_PROVIDE, isGlobalNamespace: false },
          agent: projectAgent,
        });
        await waitForPromises();

        const textarea = findSystemPromptTextArea(wrapper);
        // eslint-disable-next-line jest/no-standalone-expect
        expect(textarea.element.value).toBe(PINNED_PROMPT);
      },
    );

    itSkipVue3(
      vue3Skip('pre-fills system prompt from group pinned version on group namespace'),
      async () => {
        const { wrapper } = mountDuplicate({
          provide: { ...GROUP_PROVIDE, isGlobalNamespace: false },
          agent: groupAgent,
        });
        await waitForPromises();

        const textarea = findSystemPromptTextArea(wrapper);
        // eslint-disable-next-line jest/no-standalone-expect
        expect(textarea.element.value).toBe(GROUP_PINNED_PROMPT);
      },
    );

    itSkipVue3(
      vue3Skip('pre-fills system prompt from latest version on explore namespace'),
      async () => {
        const { wrapper } = mountDuplicate({
          provide: { ...EXPLORE_PROVIDE, isGlobalNamespace: true },
          agent: exploreAgent,
        });
        await waitForPromises();

        const textarea = findSystemPromptTextArea(wrapper);
        // eslint-disable-next-line jest/no-standalone-expect
        expect(textarea.element.value).toBe(LATEST_PROMPT);
      },
    );
  });

  describe('Version alert + mutation', () => {
    const findAlert = (wrapper) => wrapper.findComponent(GlAlert);
    const findAlertButton = (wrapper) => findAlert(wrapper).find('button');

    it('clicking "View latest version" opens the Explore agent URL in a new tab', async () => {
      const versionProp = createVersionProp({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED,
        baseVersionKey: VERSION_PINNED,
      });

      const { wrapper } = mountShow({ provide: PROJECT_PROVIDE, versionProp });
      await waitForPromises();

      findAlert(wrapper).vm.$emit('secondaryAction');

      expect(visitUrl).toHaveBeenCalledWith('/explore/ai-catalog/agents/1', true);
    });

    it('clicking "Update" fires mutation with correct consumer ID and version prefix', async () => {
      const mutationHandler = jest.fn().mockResolvedValue(mockUpdateAiCatalogItemConsumerSuccess);
      const versionProp = createVersionProp({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_LATEST,
        baseVersionKey: VERSION_PINNED,
      });

      const { wrapper } = mountShow({
        provide: PROJECT_PROVIDE,
        versionProp,
        apolloHandlers: [
          [updateAiCatalogConfiguredItem, mutationHandler],
          [aiCatalogAgentQuery, jest.fn().mockResolvedValue(mockAiCatalogAgentResponse)],
        ],
      });
      await waitForPromises();

      (await findAlertButton(wrapper)).trigger('click');

      expect(mutationHandler).toHaveBeenCalledTimes(1);
      expect(mutationHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: expect.objectContaining({
            id: 'gid://gitlab/Ai::Catalog::ItemConsumer/3',
            pinnedVersionPrefix: mockAgentVersion.versionName,
          }),
        }),
      );
    });

    it('successful update shows toast', async () => {
      const mutationHandler = jest.fn().mockResolvedValue(mockUpdateAiCatalogItemConsumerSuccess);
      const versionProp = createVersionProp({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_LATEST,
        baseVersionKey: VERSION_PINNED,
      });

      const { wrapper, apolloProvider } = mountShow({
        provide: PROJECT_PROVIDE,
        versionProp,
        apolloHandlers: [
          [updateAiCatalogConfiguredItem, mutationHandler],
          [aiCatalogAgentQuery, jest.fn().mockResolvedValue(mockAiCatalogAgentResponse)],
        ],
      });

      // Pre-subscribe the refetch query so Apollo can resolve it after the mutation
      apolloProvider.defaultClient.watchQuery({ query: aiCatalogAgentQuery }).subscribe();

      await waitForPromises();

      (await findAlertButton(wrapper)).trigger('click');
      await waitForPromises();

      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith('Agent is now at version 2.0.0.');
    });
  });
});
