import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import { createMockSubscription } from 'mock-apollo-client';
import { GlLoadingIcon } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ApplicationsShow from 'ee/cd/components/applications_show.vue';
import OverviewCard from 'ee/cd/components/overview_card.vue';
import ServicesTable from 'ee/cd/components/services_table.vue';
import ReleasesTable from 'ee/cd/components/releases_table.vue';
import DeploymentsTable from 'ee/cd/components/deployments_table.vue';
import ApplicationFlow from 'ee/cd/components/application_flow.vue';
import ApplicationLinks from 'ee/cd/components/application_links.vue';
import FilterBar from 'ee/cd/components/shared/filter_bar.vue';
import cdApplicationQuery from 'ee/cd/graphql/cd_application.query.graphql';
import cdApplicationServicesQuery from 'ee/cd/graphql/cd_application_services.query.graphql';
import cdServiceUpdatedSubscription from 'ee/cd/graphql/cd_service_updated.subscription.graphql';
import cdDeploymentUpdatedSubscription from 'ee/cd/graphql/cd_deployment_updated.subscription.graphql';
import cdApplicationReleasesQuery from 'ee/cd/graphql/cd_application_releases.query.graphql';
import cdApplicationDeploymentsQuery from 'ee/cd/graphql/cd_application_deployments.query.graphql';
import cdApplicationLinksQuery from 'ee/cd/graphql/cd_application_links.query.graphql';
import { routes } from 'ee/cd/router';
import ApplicationHeader from 'ee/cd/components/application_header.vue';
import {
  makeApplication,
  buildApplicationQueryResponse,
  buildApplicationServicesResponse,
  buildApplicationReleasesResponse,
  buildApplicationDeploymentsResponse,
  buildServiceSubscriptionResponse,
  buildPushedService,
  buildDeploymentSubscriptionResponse,
  buildPushedDeployment,
  buildApplicationLinksResponse,
  makeCdApplicationLink,
} from './mock_data';

Vue.use(VueApollo);
Vue.use(VueRouter);

const SECTION_KEYS = ['services', 'deployments', 'releases', 'links'];

// Explicit stub for <router-view>: the close/back wiring test emits those
// events on it, and Vue 2's auto-stubbed router-view is a functional component
// with no `vm` to emit from. The routed side panel is tested in
// service_side_panel_spec.js.
const RouterViewStub = { name: 'RouterViewStub', template: '<div data-testid="router-view" />' };

const OverviewCardStub = {
  name: 'OverviewCardStub',
  template: '<div><slot name="filters"></slot><slot></slot></div>',
};

describe('ApplicationsShow', () => {
  let wrapper;
  let router;
  let defaultQueryHandler;
  let defaultServicesHandler;
  let defaultReleasesHandler;
  let defaultDeploymentsHandler;
  let defaultLinksHandler;
  let subscriptionHandler;
  let deploymentSubscriptionHandler;

  beforeEach(() => {
    subscriptionHandler = jest.fn(() => createMockSubscription());
    deploymentSubscriptionHandler = jest.fn(() => createMockSubscription());
    defaultQueryHandler = jest
      .fn()
      .mockResolvedValue(buildApplicationQueryResponse(makeApplication()));
    defaultServicesHandler = jest
      .fn()
      .mockResolvedValue(buildApplicationServicesResponse(makeApplication()));
    defaultReleasesHandler = jest
      .fn()
      .mockResolvedValue(buildApplicationReleasesResponse(makeApplication()));
    defaultDeploymentsHandler = jest
      .fn()
      .mockResolvedValue(buildApplicationDeploymentsResponse(makeApplication()));
    defaultLinksHandler = jest.fn().mockResolvedValue(buildApplicationLinksResponse([]));
  });

  // -- Finders --
  const findApplicationHeader = () => wrapper.findComponent(ApplicationHeader);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findRouterView = () => wrapper.findComponent(RouterViewStub);
  const findNewReleaseButton = () => wrapper.findComponentByTestId('new-release-button');
  const findOverviewCardsContainer = () => wrapper.findByTestId('overview-cards');
  const findOverviewCards = () => wrapper.findAllComponents(OverviewCard);
  const findServicesTables = () => wrapper.findAllComponents(ServicesTable);
  const findCard = (key) => wrapper.findComponentByTestId(`${key}-card`);
  const findCardExpanded = (key) => wrapper.findByTestId(`${key}-card-expanded`);
  const findEmptyState = () => wrapper.findByTestId('applications-show-empty-state');
  const findErrorAlert = () => wrapper.findByTestId('applications-show-error-alert');
  const findDeploymentsTable = () => findCard('deployments').findComponent(DeploymentsTable);
  const findApplicationFlow = () => wrapper.findComponent(ApplicationFlow);
  const findFilterBar = () => wrapper.findComponent(FilterBar);

  const createRouter = (initialRoute = '/applications/5') => {
    // Use the real nested route config so tests exercise the actual wiring;
    // only the catch-all is swapped to the vue-router 4 form. <router-view> is
    // stubbed at mount, so the real routed page components are never rendered.
    const testRoutes = routes.map((route) =>
      route.path === '*' ? { ...route, path: '/:pathMatch(.*)*' } : route,
    );

    router = new VueRouter({ mode: 'abstract', routes: testRoutes });
    router.push(initialRoute);
    return router;
  };

  const createComponent = ({
    queryHandler = defaultQueryHandler,
    servicesHandler = defaultServicesHandler,
    releasesHandler = defaultReleasesHandler,
    deploymentsHandler = defaultDeploymentsHandler,
    linksHandler = defaultLinksHandler,
    route,
    stubs = {},
  } = {}) => {
    wrapper = shallowMountExtended(ApplicationsShow, {
      propsData: { id: '5' },
      apolloProvider: createMockApollo([
        [cdApplicationQuery, queryHandler],
        [cdApplicationServicesQuery, servicesHandler],
        [cdApplicationReleasesQuery, releasesHandler],
        [cdApplicationDeploymentsQuery, deploymentsHandler],
        [cdApplicationLinksQuery, linksHandler],
        [cdServiceUpdatedSubscription, subscriptionHandler],
        [cdDeploymentUpdatedSubscription, deploymentSubscriptionHandler],
      ]),
      router: createRouter(route),
      stubs: { 'router-view': RouterViewStub, ...stubs },
    });
  };

  describe('while loading', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not render the page heading', () => {
      expect(findApplicationHeader().exists()).toBe(false);
    });
  });

  describe('while releases load independently', () => {
    beforeEach(async () => {
      createComponent({ releasesHandler: jest.fn().mockReturnValue(new Promise(() => {})) });
      await waitForPromises();
    });

    it('renders the page without waiting for releases', () => {
      expect(findApplicationHeader().exists()).toBe(true);
    });

    it('passes a loading state to the releases card', () => {
      expect(findCard('releases').props('loading')).toBe(true);
    });
  });

  describe('when releases fail to load', () => {
    beforeEach(async () => {
      jest.spyOn(Sentry, 'captureException').mockImplementation();
      createComponent({ releasesHandler: jest.fn().mockRejectedValue(new Error('boom')) });
      await waitForPromises();
    });

    it('renders the page without a page-level error', () => {
      expect(findApplicationHeader().exists()).toBe(true);
      expect(findErrorAlert().exists()).toBe(false);
    });

    it('passes an error state to the releases card', () => {
      expect(findCard('releases').props('error')).toBe(true);
      expect(findCard('releases').props('errorMessage')).toBe(
        'Failed to load releases. Reload to try again.',
      );
    });

    it('reports the failure to Sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });

  describe('when deployments fail to load', () => {
    beforeEach(async () => {
      jest.spyOn(Sentry, 'captureException').mockImplementation();
      createComponent({ deploymentsHandler: jest.fn().mockRejectedValue(new Error('boom')) });
      await waitForPromises();
    });

    it('renders the page without a page-level error', () => {
      expect(findApplicationHeader().exists()).toBe(true);
      expect(findErrorAlert().exists()).toBe(false);
    });

    it('passes an error state and message to the deployments card', () => {
      expect(findCard('deployments').props('error')).toBe(true);
      expect(findCard('deployments').props('errorMessage')).toBe(
        'Failed to load deployments. Reload to try again.',
      );
    });

    it('reports the failure to Sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });

  describe('when the application is not found', () => {
    beforeEach(async () => {
      const handler = jest.fn().mockResolvedValue(buildApplicationQueryResponse(null));
      createComponent({ queryHandler: handler });
      await waitForPromises();
    });

    it('renders the empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
    });

    it('does not render the page heading', () => {
      expect(findApplicationHeader().exists()).toBe(false);
    });

    it('does not render overview cards', () => {
      expect(findOverviewCardsContainer().exists()).toBe(false);
    });
  });

  describe('when the query errors', () => {
    beforeEach(async () => {
      const handler = jest.fn().mockRejectedValue(new Error('boom'));
      createComponent({ queryHandler: handler });
      await waitForPromises();
    });

    it('renders the error alert', () => {
      expect(findErrorAlert().exists()).toBe(true);
    });

    it('does not render the empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('does not render overview cards', () => {
      expect(findOverviewCardsContainer().exists()).toBe(false);
    });
  });

  describe('after loading', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('fetches the application by id', () => {
      expect(defaultQueryHandler).toHaveBeenCalledTimes(1);
    });

    it('fetches the releases by the same application id', () => {
      expect(defaultReleasesHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/Cd::Application/5',
        first: 5,
        after: null,
        last: null,
        before: null,
        search: null,
        statuses: null,
      });
    });

    it('hides the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('passes the application to the header', () => {
      expect(findApplicationHeader().props('application')).toMatchObject({
        name: 'My Application',
      });
    });

    it('renders the overview cards container', () => {
      expect(findOverviewCardsContainer().exists()).toBe(true);
    });

    it('renders all four overview cards', () => {
      expect(findOverviewCards()).toHaveLength(4);
    });

    it('passes services to the collapsed services table', () => {
      const servicesTables = findServicesTables();

      expect(servicesTables).toHaveLength(1);
      expect(servicesTables.at(0).props('services')).toHaveLength(2);
      expect(servicesTables.at(0).props('full')).toBe(false);
    });

    it('passes the version sets to the collapsed releases table', () => {
      const releasesTable = findCard('releases').findComponent(ReleasesTable);

      expect(releasesTable.props('releases')).toHaveLength(2);
      expect(releasesTable.props('releases')[0].name).toBe('v1_1_0');
      expect(releasesTable.props('full')).toBe(false);
    });

    it('navigates to the release detail route when a release is selected', async () => {
      findCard('releases')
        .findComponent(ReleasesTable)
        .vm.$emit('select', { id: 'gid://gitlab/Cd::VersionSet/1', name: 'v1_1_0' });
      await waitForPromises();

      expect(router.currentRoute.name).toBe('release_detail_route');
      expect(router.currentRoute.params.releaseId).toBe('1');
    });

    it('marks the open release in the releases table while its panel is shown', async () => {
      findCard('releases')
        .findComponent(ReleasesTable)
        .vm.$emit('select', { id: 'gid://gitlab/Cd::VersionSet/1', name: 'v1_1_0' });
      await waitForPromises();

      expect(findCard('releases').findComponent(ReleasesTable).props('selectedId')).toBe(
        'gid://gitlab/Cd::VersionSet/1',
      );
    });
  });

  describe('deployment selection and flow', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    describe('when a deployment is clicked', () => {
      beforeEach(async () => {
        findDeploymentsTable().vm.$emit('select', { id: 'gid://gitlab/Cd::Rollout/1' });
        await nextTick();
      });

      it('passes the clicked deployment id to the application flow', () => {
        expect(findApplicationFlow().props('selectedDeploymentId')).toBe(
          'gid://gitlab/Cd::Rollout/1',
        );
      });
    });

    describe('when the flow reports the shown rollout', () => {
      beforeEach(async () => {
        findApplicationFlow().vm.$emit('rollout-selected', {
          id: 'gid://gitlab/Cd::Rollout/1',
          versionSetId: 'gid://gitlab/Cd::VersionSet/1',
        });
        await nextTick();
      });

      it('highlights the deployment row', () => {
        expect(findDeploymentsTable().props('selectedId')).toBe('gid://gitlab/Cd::Rollout/1');
      });

      it('highlights the related release row', () => {
        expect(findCard('releases').findComponent(ReleasesTable).props('selectedId')).toBe(
          'gid://gitlab/Cd::VersionSet/1',
        );
      });
    });
  });

  describe.each(SECTION_KEYS)('expand/collapse %s card', (sectionKey) => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('does not show expanded card initially', () => {
      expect(findCardExpanded(sectionKey).exists()).toBe(false);
    });

    describe('when expanded', () => {
      beforeEach(async () => {
        findCard(sectionKey).findComponent(OverviewCard).vm.$emit('toggle');
        await nextTick();
      });

      it('shows the expanded card', () => {
        expect(findCardExpanded(sectionKey).exists()).toBe(true);
      });

      it('keeps other cards visible', () => {
        const otherKeys = SECTION_KEYS.filter((k) => k !== sectionKey);

        otherKeys.forEach((key) => {
          expect(findCard(key).exists()).toBe(true);
        });
      });

      it('hides the collapsed card', () => {
        expect(findCard(sectionKey).exists()).toBe(false);
      });

      describe('when collapsed again', () => {
        beforeEach(async () => {
          findCardExpanded(sectionKey).findComponent(OverviewCard).vm.$emit('toggle');
          await nextTick();
        });

        it('hides expanded card', () => {
          expect(findCardExpanded(sectionKey).exists()).toBe(false);
        });

        it('shows collapsed card again', () => {
          expect(findCard(sectionKey).exists()).toBe(true);
        });
      });
    });
  });

  describe('links card', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('expands the links card when the links content requests it', async () => {
      expect(findCardExpanded('links').exists()).toBe(false);

      findCard('links').findComponent(ApplicationLinks).vm.$emit('expand');
      await nextTick();

      expect(findCardExpanded('links').exists()).toBe(true);
    });

    it('passes the current links to the card content', () => {
      expect(findCard('links').findComponent(ApplicationLinks).props('links')).toEqual([]);
    });

    it('forwards the links pageInfo to the card so it can paginate', async () => {
      createComponent({
        linksHandler: jest
          .fn()
          .mockResolvedValue(
            buildApplicationLinksResponse([makeCdApplicationLink()], { hasNextPage: true }),
          ),
      });
      await waitForPromises();

      expect(findCard('links').props('pageInfo')).toMatchObject({ hasNextPage: true });
    });

    describe('when the links content reports a mutation', () => {
      const mountWithLinks = (links, pageInfo = {}) => {
        const linksHandler = jest
          .fn()
          .mockResolvedValue(buildApplicationLinksResponse(links, pageInfo));
        createComponent({ linksHandler });
        return linksHandler;
      };
      const emitFromLinks = (event) =>
        findCard('links').findComponent(ApplicationLinks).vm.$emit(event);
      const lastLinksVariables = (handler) => handler.mock.calls.at(-1)[0];

      it('refetches after an update', async () => {
        const linksHandler = mountWithLinks([makeCdApplicationLink()]);
        await waitForPromises();

        emitFromLinks('updated');
        await waitForPromises();

        expect(linksHandler).toHaveBeenCalledTimes(2);
      });

      it('refetches after a create', async () => {
        const linksHandler = mountWithLinks([makeCdApplicationLink()]);
        await waitForPromises();

        emitFromLinks('created');
        await waitForPromises();

        expect(linksHandler).toHaveBeenCalledTimes(2);
      });

      it('refetches the current page after a delete when other rows remain', async () => {
        const linksHandler = mountWithLinks([
          makeCdApplicationLink({ id: 'gid://gitlab/Cd::ApplicationLink/1' }),
          makeCdApplicationLink({ id: 'gid://gitlab/Cd::ApplicationLink/2' }),
        ]);
        await waitForPromises();

        emitFromLinks('deleted');
        await waitForPromises();

        expect(lastLinksVariables(linksHandler)).toMatchObject({ before: null });
      });

      it('steps back a page after deleting the only row on a later page', async () => {
        const linksHandler = mountWithLinks([makeCdApplicationLink()], {
          hasPreviousPage: true,
          startCursor: 'PREV_CURSOR',
        });
        await waitForPromises();

        emitFromLinks('deleted');
        await waitForPromises();

        expect(lastLinksVariables(linksHandler)).toMatchObject({ before: 'PREV_CURSOR', last: 10 });
      });
    });
  });

  describe('services table props', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('passes full=true to the expanded services table', async () => {
      findCard('services').findComponent(OverviewCard).vm.$emit('toggle');
      await nextTick();

      const expandedTable = findCardExpanded('services').findComponent(ServicesTable);

      expect(expandedTable.exists()).toBe(true);
      expect(expandedTable.props('full')).toBe(true);
    });
  });

  describe('real-time updates', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('subscribes to cdServiceUpdated for the application', () => {
      expect(subscriptionHandler).toHaveBeenCalledWith({
        applicationId: 'gid://gitlab/Cd::Application/5',
      });
    });

    it('subscribes to cdDeploymentUpdated for the application', () => {
      expect(deploymentSubscriptionHandler).toHaveBeenCalledWith({
        applicationId: 'gid://gitlab/Cd::Application/5',
      });
    });
  });

  describe('when a service status is pushed over the subscription', () => {
    const firstEnvHealth = () =>
      findServicesTables().at(0).props('services')[0].serviceEnvironmentHealths.nodes[0];
    const servicesHealth = () => firstEnvHealth().health;
    const servicesVersion = () => firstEnvHealth().deployedVersions.nodes[0].name;

    let mockSubscription;

    const pushUpdate = async (node) => {
      mockSubscription.next({ data: { cdServiceUpdated: buildPushedService(node) } });
      await waitForPromises();
      await nextTick();
    };

    beforeEach(async () => {
      subscriptionHandler = jest.fn(() => {
        mockSubscription = createMockSubscription();
        return mockSubscription;
      });
      createComponent({
        servicesHandler: jest.fn().mockResolvedValue(buildServiceSubscriptionResponse('HEALTHY')),
        releasesHandler: jest.fn().mockReturnValue(new Promise(() => {})),
        deploymentsHandler: jest.fn().mockReturnValue(new Promise(() => {})),
      });
      await waitForPromises();
    });

    it('updates the service health in the list without refetching', async () => {
      expect(servicesHealth()).toBe('HEALTHY');

      await pushUpdate({ health: 'FAILED' });

      expect(servicesHealth()).toBe('FAILED');
    });

    it('updates the deployed version in the list without refetching', async () => {
      expect(servicesVersion()).toBe('v1-0-0');

      await pushUpdate({ health: 'HEALTHY', versionId: '2', versionName: 'v1-2-0' });

      expect(servicesVersion()).toBe('v1-2-0');
    });
  });

  describe('when a deployment status is pushed over the subscription', () => {
    const rollout = () => findDeploymentsTable().props('deployments')[0];
    const rolloutRowState = () => rollout().state;
    const envState = (index) => rollout().rolloutEnvironments.nodes[index].state;

    let mockSubscription;

    beforeEach(async () => {
      deploymentSubscriptionHandler = jest.fn(() => {
        mockSubscription = createMockSubscription();
        return mockSubscription;
      });
      createComponent({
        deploymentsHandler: jest
          .fn()
          .mockResolvedValue(buildDeploymentSubscriptionResponse('FAILED')),
        servicesHandler: jest.fn().mockReturnValue(new Promise(() => {})),
        releasesHandler: jest.fn().mockReturnValue(new Promise(() => {})),
      });
      await waitForPromises();
    });

    it('updates only the pushed environment and the rollout, leaving siblings untouched', async () => {
      expect(rolloutRowState()).toBe('FAILED');
      expect(envState(0)).toBe('FAILED');
      expect(envState(1)).toBe('PENDING');

      mockSubscription.next({ data: { cdDeploymentUpdated: buildPushedDeployment('COMPLETED') } });
      await waitForPromises();
      await nextTick();

      expect(rolloutRowState()).toBe('COMPLETED');
      expect(envState(0)).toBe('COMPLETED');
      expect(envState(1)).toBe('PENDING');
    });
  });

  describe('multi-expand', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('allows multiple cards to be expanded simultaneously', async () => {
      findCard('services').findComponent(OverviewCard).vm.$emit('toggle');
      await nextTick();

      findCard('deployments').findComponent(OverviewCard).vm.$emit('toggle');
      await nextTick();

      expect(findCardExpanded('services').exists()).toBe(true);
      expect(findCardExpanded('deployments').exists()).toBe(true);
      expect(findCard('releases').exists()).toBe(true);
      expect(findCard('links').exists()).toBe(true);
    });
  });

  describe('release panel', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the "Build new release" button', () => {
      expect(findNewReleaseButton().exists()).toBe(true);
    });

    it('navigates to the new release route when the button is clicked', async () => {
      findNewReleaseButton().vm.$emit('click');
      await waitForPromises();

      expect(router.currentRoute.name).toBe('release_new_route');
    });
  });

  describe('when a release is created', () => {
    beforeEach(async () => {
      createComponent({ route: '/applications/5/releases/new' });
      await waitForPromises();

      findRouterView().vm.$emit('created', 'gid://gitlab/Cd::VersionSet/1');
      await waitForPromises();
    });

    it('returns to the overview route', () => {
      expect(router.currentRoute.name).toBe('applications_show_route');
    });

    it('expands the releases card', () => {
      expect(findCardExpanded('releases').exists()).toBe(true);
    });

    it('refetches the releases', () => {
      expect(defaultReleasesHandler).toHaveBeenCalledTimes(2);
    });

    it('highlights the new release in the releases table', () => {
      const table = findCardExpanded('releases').findComponent(ReleasesTable);

      expect(table.props('recentId')).toBe('gid://gitlab/Cd::VersionSet/1');
    });
  });

  describe('when a release is created while paged to a later page', () => {
    let releasesHandler;

    beforeEach(async () => {
      releasesHandler = jest.fn().mockResolvedValue(
        buildApplicationReleasesResponse(makeApplication(), {
          hasNextPage: true,
          hasPreviousPage: false,
          startCursor: 'start',
          endCursor: 'end',
        }),
      );
      createComponent({ route: '/applications/5/releases/new', releasesHandler });
      await waitForPromises();

      findCard('releases').findComponent(OverviewCard).vm.$emit('next', 'end');
      await waitForPromises();

      findRouterView().vm.$emit('created', 'gid://gitlab/Cd::VersionSet/1');
      await waitForPromises();
    });

    it('resets the releases list to the first page', () => {
      expect(releasesHandler).toHaveBeenLastCalledWith({
        id: 'gid://gitlab/Cd::Application/5',
        first: 5,
        after: null,
        last: null,
        before: null,
        search: null,
        statuses: null,
      });
    });
  });

  describe('when a deployment is triggered', () => {
    const rolloutId = 'gid://gitlab/Cd::Rollout/1';

    beforeEach(async () => {
      createComponent({ route: '/applications/5/releases/1' });
      await waitForPromises();

      findRouterView().vm.$emit('deploy-triggered', rolloutId);
      await waitForPromises();
    });

    it('returns to the overview route', () => {
      expect(router.currentRoute.name).toBe('applications_show_route');
    });

    it('expands the deployments card', () => {
      expect(findCardExpanded('deployments').exists()).toBe(true);
    });

    it('highlights the triggered deployment as recent', () => {
      expect(
        findCardExpanded('deployments').findComponent(DeploymentsTable).props('recentId'),
      ).toBe(rolloutId);
    });

    it('refetches the deployments and the releases', () => {
      expect(defaultDeploymentsHandler).toHaveBeenCalledTimes(2);
      expect(defaultReleasesHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe.each([
    {
      key: 'deployments',
      handlerKey: 'deploymentsHandler',
      buildResponse: buildApplicationDeploymentsResponse,
      getDefaultHandler: () => defaultDeploymentsHandler,
      filters: { search: null, statuses: null },
    },
    {
      key: 'releases',
      handlerKey: 'releasesHandler',
      buildResponse: buildApplicationReleasesResponse,
      getDefaultHandler: () => defaultReleasesHandler,
      filters: { search: null, statuses: null },
    },
  ])('$key pagination', ({ key, handlerKey, buildResponse, getDefaultHandler, filters }) => {
    const pageInfo = {
      hasNextPage: true,
      hasPreviousPage: false,
      startCursor: 'start',
      endCursor: 'end',
    };

    const findSectionCard = () => findCard(key).findComponent(OverviewCard);
    const buildHandler = () =>
      jest.fn().mockResolvedValue(buildResponse(makeApplication(), pageInfo));

    it('requests the first page with the default page size', async () => {
      createComponent();
      await waitForPromises();

      expect(getDefaultHandler()).toHaveBeenCalledWith({
        id: 'gid://gitlab/Cd::Application/5',
        first: 5,
        after: null,
        last: null,
        before: null,
        ...filters,
      });
    });

    it('passes the pageInfo to the card', async () => {
      createComponent({ [handlerKey]: buildHandler() });
      await waitForPromises();

      expect(findCard(key).props('pageInfo')).toMatchObject(pageInfo);
    });

    it('passes the default page size to the card', async () => {
      createComponent();
      await waitForPromises();

      expect(findCard(key).props('pageSize')).toBe(5);
    });

    describe('when the card requests the next page', () => {
      let handler;

      beforeEach(async () => {
        handler = buildHandler();
        createComponent({ [handlerKey]: handler });
        await waitForPromises();

        findSectionCard().vm.$emit('next', 'end');
        await waitForPromises();
      });

      it('refetches after the end cursor', () => {
        expect(handler).toHaveBeenLastCalledWith({
          id: 'gid://gitlab/Cd::Application/5',
          first: 5,
          after: 'end',
          last: null,
          before: null,
          ...filters,
        });
      });
    });

    describe('when the card requests the previous page', () => {
      let handler;

      beforeEach(async () => {
        handler = buildHandler();
        createComponent({ [handlerKey]: handler });
        await waitForPromises();

        findSectionCard().vm.$emit('prev', 'start');
        await waitForPromises();
      });

      it('refetches before the start cursor', () => {
        expect(handler).toHaveBeenLastCalledWith({
          id: 'gid://gitlab/Cd::Application/5',
          first: null,
          after: null,
          last: 5,
          before: 'start',
          ...filters,
        });
      });
    });

    describe('when the card changes the page size', () => {
      let handler;

      beforeEach(async () => {
        handler = buildHandler();
        createComponent({ [handlerKey]: handler });
        await waitForPromises();

        findSectionCard().vm.$emit('page-size-change', 20);
        await waitForPromises();
      });

      it('refetches the first page at the new size', () => {
        expect(handler).toHaveBeenLastCalledWith({
          id: 'gid://gitlab/Cd::Application/5',
          first: 20,
          after: null,
          last: null,
          before: null,
          ...filters,
        });
      });

      describe('and then requests the next page', () => {
        beforeEach(async () => {
          findSectionCard().vm.$emit('next', 'end');
          await waitForPromises();
        });

        it('keeps the selected page size', () => {
          expect(handler).toHaveBeenLastCalledWith({
            id: 'gid://gitlab/Cd::Application/5',
            first: 20,
            after: 'end',
            last: null,
            before: null,
            ...filters,
          });
        });
      });
    });
  });

  describe('service side panel router-view', () => {
    it('renders a router-view to host the routed side panel', async () => {
      createComponent();
      await waitForPromises();

      expect(findRouterView().exists()).toBe(true);
    });

    it('navigates to the service detail route when a service row is selected', async () => {
      createComponent();
      await waitForPromises();

      findServicesTables().at(0).vm.$emit('select', { id: 'gid://gitlab/Cd::Service/10' });
      await waitForPromises();

      expect(router.currentRoute.name).toBe('service_detail_route');
      expect(router.currentRoute.params.serviceId).toBe('10');
    });

    it('marks the open service in the services table while its panel is shown', async () => {
      createComponent();
      await waitForPromises();
      expect(findServicesTables().at(0).props('selectedId')).toBeNull();

      findServicesTables().at(0).vm.$emit('select', { id: 'gid://gitlab/Cd::Service/10' });
      await waitForPromises();

      expect(findServicesTables().at(0).props('selectedId')).toBe('gid://gitlab/Cd::Service/10');
    });

    it('navigates back to the parent route when the router-view emits close', async () => {
      createComponent({ route: '/applications/5/services/10' });
      await waitForPromises();
      expect(router.currentRoute.name).toBe('service_detail_route');

      findRouterView().vm.$emit('close');
      await waitForPromises();

      expect(router.currentRoute.name).toBe('applications_show_route');
      expect(router.currentRoute.params.serviceId).toBeUndefined();
    });
  });

  describe.each([
    { key: 'deployments', statusId: 'ACTIVE', getHandler: () => defaultDeploymentsHandler },
    { key: 'releases', statusId: 'DEPLOYING', getHandler: () => defaultReleasesHandler },
  ])('$key filtering', ({ key, statusId, getHandler }) => {
    const expandSection = async () => {
      findCard(key).vm.$emit('toggle');
      await nextTick();
    };

    beforeEach(async () => {
      createComponent({ stubs: { OverviewCard: OverviewCardStub } });
      await waitForPromises();
      await expandSection();
    });

    it('shows a search-by-type filter bar with the status filters', () => {
      expect(findFilterBar().props('searchFirst')).toBe(true);
      expect(findFilterBar().props('filters')).toHaveLength(4);
      expect(findFilterBar().props('filters')[0].id).toBe('ALL');
      expect(
        findFilterBar()
          .props('filters')
          .map((filter) => filter.id),
      ).toContain(statusId);
    });

    describe('when a search term is entered', () => {
      beforeEach(async () => {
        findFilterBar().vm.$emit('search', 'v2');
        await waitForPromises();
      });

      it('refetches filtered by the search term from the first page', () => {
        expect(getHandler()).toHaveBeenLastCalledWith(
          expect.objectContaining({ search: 'v2', statuses: null, after: null, before: null }),
        );
      });
    });

    describe('when a status filter is selected', () => {
      beforeEach(async () => {
        findFilterBar().vm.$emit('filter-selected', statusId);
        await waitForPromises();
      });

      it('refetches filtered by that status', () => {
        expect(getHandler()).toHaveBeenLastCalledWith(
          expect.objectContaining({ statuses: [statusId], after: null, before: null }),
        );
      });
    });

    describe('when the status filter is reset to All', () => {
      beforeEach(async () => {
        findFilterBar().vm.$emit('filter-selected', statusId);
        await waitForPromises();
        findFilterBar().vm.$emit('filter-selected', 'ALL');
        await waitForPromises();
      });

      it('clears the status filter', () => {
        expect(getHandler()).toHaveBeenLastCalledWith(expect.objectContaining({ statuses: null }));
      });
    });

    describe('when the section is collapsed after filtering', () => {
      beforeEach(async () => {
        findFilterBar().vm.$emit('search', 'v2');
        await waitForPromises();
        wrapper.findComponentByTestId(`${key}-card-expanded`).vm.$emit('toggle');
        await waitForPromises();
      });

      it('resets the filter and refetches unfiltered', () => {
        expect(getHandler()).toHaveBeenLastCalledWith(
          expect.objectContaining({ search: null, statuses: null, after: null, before: null }),
        );
      });
    });
  });

  describe('when a deployment is triggered while a filter is active', () => {
    beforeEach(async () => {
      createComponent({
        stubs: { OverviewCard: OverviewCardStub },
        route: '/applications/5/releases/1',
      });
      await waitForPromises();
      findCard('deployments').vm.$emit('toggle');
      await nextTick();
      findFilterBar().vm.$emit('search', 'v2');
      await waitForPromises();
      findRouterView().vm.$emit('deploy-triggered', 'gid://gitlab/Cd::Rollout/9');
      await waitForPromises();
    });

    it('resets the deployments filter and refetches unfiltered', () => {
      expect(defaultDeploymentsHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ search: null, statuses: null }),
      );
    });
  });

  describe('when a release is created while a filter is active', () => {
    beforeEach(async () => {
      createComponent({
        stubs: { OverviewCard: OverviewCardStub },
        route: '/applications/5/releases/new',
      });
      await waitForPromises();
      findCard('releases').vm.$emit('toggle');
      await nextTick();
      findFilterBar().vm.$emit('search', 'v2');
      await waitForPromises();
      findRouterView().vm.$emit('created', 'gid://gitlab/Cd::VersionSet/9');
      await waitForPromises();
    });

    it('resets the releases filter and refetches unfiltered', () => {
      expect(defaultReleasesHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ search: null, statuses: null }),
      );
    });
  });
});
