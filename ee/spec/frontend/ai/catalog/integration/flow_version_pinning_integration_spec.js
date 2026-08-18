import { GlAlert } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { SkipReason, itSkipVue3 } from 'helpers/vue3_conditional';
import { visitUrl } from '~/lib/utils/url_utility';
import AiCatalogItemShow from 'ee/ai/catalog/pages/ai_catalog_item_show.vue';
import AiCatalogItemEdit from 'ee/ai/catalog/pages/ai_catalog_item_edit.vue';
import AiCatalogItemDuplicate from 'ee/ai/catalog/pages/ai_catalog_item_duplicate.vue';
import { VERSION_PINNED, VERSION_PINNED_GROUP, VERSION_LATEST } from 'ee/ai/catalog/constants';
import updateAiCatalogConfiguredItem from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_item_consumer.mutation.graphql';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import {
  mockFlowVersion,
  mockFlowPinnedVersion,
  mockFlowGroupPinnedVersion,
  mockUpdateAiCatalogItemConsumerSuccess,
  mockAiCatalogFlowResponse,
} from '../mock_data';
import {
  createIntegrationWrapper,
  PROJECT_PROVIDE,
  GROUP_PROVIDE,
  EXPLORE_PROVIDE,
  ROUTE_PRESETS,
} from './helpers';
import { createFlowWithPermissions } from './mock_data_factories';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

// FormFlowDefinition wraps Monaco SourceEditor which cannot run in jsdom.
const FormFlowDefinitionStub = { props: ['value'], template: '<div />' };

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

describe('Flow — version pinning integration', () => {
  const LATEST_DEFINITION = 'latest-version-definition';
  const PINNED_DEFINITION = 'pinned-version-definition';
  const GROUP_PINNED_DEFINITION = 'group-pinned-version-definition';

  const projectFlow = createFlowWithPermissions({
    pinnedVersion: { ...mockFlowPinnedVersion, definition: PINNED_DEFINITION },
  });
  const groupFlow = createFlowWithPermissions({
    withProjectConfig: false,
    groupPinnedVersion: { ...mockFlowGroupPinnedVersion, definition: GROUP_PINNED_DEFINITION },
  });
  const exploreFlow = {
    ...createFlowWithPermissions({ withProjectConfig: false, withGroupConfig: false }),
    latestVersion: { ...mockFlowVersion, definition: LATEST_DEFINITION },
  };

  const mountShow = ({ provide, flow, versionProp, apolloHandlers = [], mocks = {} } = {}) => {
    const defaultFlow = flow || createFlowWithPermissions();

    return createIntegrationWrapper(AiCatalogItemShow, {
      provide,
      props: {
        aiCatalogItem: defaultFlow,
        version: versionProp,
      },
      apolloHandlers,
      route: ROUTE_PRESETS.flowShow,
      stubs: { FormFlowDefinition: FormFlowDefinitionStub },
      mocks,
    });
  };

  describe('Show page', () => {
    const findDefinition = (wrapper) =>
      wrapper.findComponent(FormFlowDefinitionStub).props('value');

    it('project namespace: shows pinned version definition and version alert', async () => {
      const versionProp = createVersionProp({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED,
        baseVersionKey: VERSION_PINNED,
      });
      const { wrapper } = mountShow({ provide: PROJECT_PROVIDE, flow: projectFlow, versionProp });
      await waitForPromises();

      expect(findDefinition(wrapper)).toBe(PINNED_DEFINITION);
      expect(wrapper.findComponent(GlAlert).text()).toContain('A new version is available');
    });

    it('group namespace: shows group pinned version definition and version alert', async () => {
      const versionProp = createVersionProp({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED_GROUP,
        baseVersionKey: VERSION_PINNED_GROUP,
      });
      const { wrapper } = mountShow({ provide: GROUP_PROVIDE, flow: groupFlow, versionProp });
      await waitForPromises();

      expect(findDefinition(wrapper)).toBe(GROUP_PINNED_DEFINITION);
      expect(wrapper.findComponent(GlAlert).text()).toContain('A new version is available');
    });

    it('explore namespace: shows latest version definition and no version alert', async () => {
      const versionProp = createVersionProp({
        isUpdateAvailable: false,
        activeVersionKey: VERSION_LATEST,
        baseVersionKey: VERSION_LATEST,
      });
      const { wrapper } = mountShow({ provide: EXPLORE_PROVIDE, flow: exploreFlow, versionProp });
      await waitForPromises();

      expect(findDefinition(wrapper)).toBe(LATEST_DEFINITION);
      expect(wrapper.findComponent(GlAlert).exists()).toBe(false);
    });
  });

  describe('Edit page', () => {
    const mountEdit = ({ versionProp, flow } = {}) => {
      const defaultFlow = flow || createFlowWithPermissions();

      return createIntegrationWrapper(AiCatalogItemEdit, {
        provide: PROJECT_PROVIDE,
        props: {
          aiCatalogItem: defaultFlow,
          version: versionProp,
        },
        apolloHandlers: [],
        route: ROUTE_PRESETS.flowEdit,
        stubs: { FormFlowDefinition: FormFlowDefinitionStub },
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
    const mountDuplicate = ({ provide, flow } = {}) => {
      const defaultFlow = flow || createFlowWithPermissions();

      return createIntegrationWrapper(AiCatalogItemDuplicate, {
        provide,
        props: { aiCatalogItem: defaultFlow },
        apolloHandlers: [],
        route: ROUTE_PRESETS.flowDuplicate,
        stubs: { FormFlowDefinition: FormFlowDefinitionStub },
      });
    };

    // Vue Router 4 navigation is async — $route.params.id is undefined
    // in created() until the initial navigation completes. See linked issue.
    const vue3Skip = (name) =>
      new SkipReason({
        name,
        reason:
          'Vue Router 4 resolves navigation async — $route.params.id is undefined in created()',
        issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/593908',
      });

    const findFormDefinition = (wrapper) =>
      wrapper.findComponent({ name: 'AiCatalogFlowForm' }).props('initialValues').definition;

    itSkipVue3(
      vue3Skip('pre-fills definition from project pinned version on project namespace'),
      async () => {
        const { wrapper } = mountDuplicate({
          provide: { ...PROJECT_PROVIDE, isGlobalNamespace: false },
          flow: projectFlow,
        });
        await waitForPromises();

        // eslint-disable-next-line jest/no-standalone-expect
        expect(findFormDefinition(wrapper)).toBe(PINNED_DEFINITION);
      },
    );

    itSkipVue3(
      vue3Skip('pre-fills definition from group pinned version on group namespace'),
      async () => {
        const { wrapper } = mountDuplicate({
          provide: { ...GROUP_PROVIDE, isGlobalNamespace: false },
          flow: groupFlow,
        });
        await waitForPromises();

        // eslint-disable-next-line jest/no-standalone-expect
        expect(findFormDefinition(wrapper)).toBe(GROUP_PINNED_DEFINITION);
      },
    );

    itSkipVue3(
      vue3Skip('pre-fills definition from latest version on explore namespace'),
      async () => {
        const { wrapper } = mountDuplicate({
          provide: { ...EXPLORE_PROVIDE, isGlobalNamespace: true },
          flow: exploreFlow,
        });
        await waitForPromises();

        // eslint-disable-next-line jest/no-standalone-expect
        expect(findFormDefinition(wrapper)).toBe(LATEST_DEFINITION);
      },
    );
  });

  describe('Version alert + mutation', () => {
    const findAlert = (wrapper) => wrapper.findComponent(GlAlert);
    const findAlertButton = (wrapper) => findAlert(wrapper).find('button');

    it('clicking "View latest version" opens the Explore flow URL in a new tab', async () => {
      const versionProp = createVersionProp({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED,
        baseVersionKey: VERSION_PINNED,
      });

      const { wrapper } = mountShow({ provide: PROJECT_PROVIDE, versionProp });
      await waitForPromises();

      findAlert(wrapper).vm.$emit('secondaryAction');

      expect(visitUrl).toHaveBeenCalledWith('/explore/ai-catalog/flows/4', true);
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
          [aiCatalogFlowQuery, jest.fn().mockResolvedValue(mockAiCatalogFlowResponse)],
        ],
      });
      await waitForPromises();

      (await findAlertButton(wrapper)).trigger('click');

      expect(mutationHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: expect.objectContaining({
            id: 'gid://gitlab/Ai::Catalog::ItemConsumer/12',
            pinnedVersionPrefix: mockFlowVersion.versionName,
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
          [aiCatalogFlowQuery, jest.fn().mockResolvedValue(mockAiCatalogFlowResponse)],
        ],
      });

      // Pre-subscribe the refetch query so Apollo can resolve it after the mutation
      apolloProvider.defaultClient.watchQuery({ query: aiCatalogFlowQuery }).subscribe();

      await waitForPromises();

      (await findAlertButton(wrapper)).trigger('click');
      await waitForPromises();

      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith('Flow is now at version 2.0.0.');
    });
  });
});
