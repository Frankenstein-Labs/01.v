import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import App from 'ee/packages_and_registries/artifact_registry/repositories/app.vue';
import NotFound from 'ee/packages_and_registries/artifact_registry/components/not_found.vue';
import RepositoriesCreateForm from 'ee/packages_and_registries/artifact_registry/repositories/create/repositories_create_form.vue';
import RepositoriesEditForm from 'ee/packages_and_registries/artifact_registry/repositories/edit/repositories_edit_form.vue';
import getRepositoriesQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repositories.query.graphql';
import getRepositoryQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository.query.graphql';
import { createRouter } from 'ee/packages_and_registries/artifact_registry/router';
import {
  ARTIFACT_ID_FOR,
  BASE_PATH,
  CLIENT_BASE_URL,
  ORGANIZATION_GID,
  SLUG,
  createBreadCrumbState,
  mockRepositoriesResponse,
  mockRepositoryResponse,
  resetBreadCrumbState,
  mockRepository,
  mockRepositoryPage,
} from '../mock_data';

Vue.use(VueApollo);

const BASE_TITLE = 'Repositories · GitLab';

describe('ArtifactRegistryRepositoriesApp', () => {
  let wrapper;
  let router;
  let state;

  afterEach(() => {
    resetBreadCrumbState();
  });

  const findShell = () => wrapper.findByTestId('repositories-shell');
  const findNotFound = () => wrapper.findComponent(NotFound);
  const findCreateForm = () => wrapper.findComponent(RepositoriesCreateForm);
  const findEditForm = () => wrapper.findComponent(RepositoriesEditForm);

  const createComponent = async (initialPath = '/') => {
    document.title = BASE_TITLE;

    state = createBreadCrumbState();
    router = createRouter(BASE_PATH, state);
    await router.push(initialPath);

    wrapper = mountExtended(App, {
      router,
      apolloProvider: createMockApollo([
        [
          getRepositoriesQuery,
          jest.fn().mockResolvedValue(mockRepositoriesResponse(mockRepositoryPage)),
        ],
        [getRepositoryQuery, jest.fn().mockResolvedValue(mockRepositoryResponse(mockRepository))],
      ]),
      provide: {
        breadCrumbState: state,
        organizationGid: ORGANIZATION_GID,
        slug: SLUG,
        clientBaseUrl: CLIENT_BASE_URL,
      },
      attachTo: document.body,
    });
    await nextTick();
  };

  it('hosts the router outlet inside a focusable container', async () => {
    await createComponent();

    expect(findShell().attributes('tabindex')).toBe('-1');
  });

  describe('when navigating to a path no slice has registered', () => {
    beforeEach(async () => {
      await createComponent('/some/unregistered/tab');
    });

    it('renders the in-SPA not-found fallback rather than crashing', () => {
      expect(findNotFound().exists()).toBe(true);
    });
  });

  describe('when navigating to the hosted create route', () => {
    beforeEach(async () => {
      await createComponent('/new/hosted');
    });

    it('renders the create form', () => {
      expect(findCreateForm().exists()).toBe(true);
    });
  });

  describe('when navigating to the edit route', () => {
    beforeEach(async () => {
      await createComponent('/my-repository/edit');
    });

    it('renders the edit form', () => {
      expect(findEditForm().exists()).toBe(true);
    });
  });

  describe('client-side route changes', () => {
    it('moves focus to the newly rendered view', async () => {
      await createComponent('/');

      // Focus starts outside the shell, so the assertion below shows the route change moved it.
      document.body.focus();

      await router.push('/some/unregistered/tab');
      await nextTick();

      expect(document.activeElement).toBe(findShell().element);
    });

    it('moves focus when entering the create route', async () => {
      await createComponent('/');

      document.body.focus();

      await router.push('/new/hosted');
      await nextTick();

      expect(document.activeElement).toBe(findShell().element);
    });

    it('moves focus when entering the edit route', async () => {
      await createComponent('/');

      document.body.focus();

      await router.push('/my-repository/edit');
      await nextTick();

      expect(document.activeElement).toBe(findShell().element);
    });

    it('leaves focus alone on a query-only change, so an announcement is not interrupted', async () => {
      await createComponent('/');

      document.body.focus();

      await router.push({ path: '/', query: { format: 'MAVEN' } });
      await nextTick();

      expect(document.activeElement).toBe(document.body);
    });
  });

  describe('the document title', () => {
    it('leaves the Rails title alone on the list route, which already names itself', async () => {
      await createComponent('/');

      expect(document.title).toBe(BASE_TITLE);
    });

    it('names a static route in full, behind the repository it belongs to', async () => {
      await createComponent('/my-repository/edit');

      expect(document.title).toBe(`Edit hosted repository · my-repository · ${BASE_TITLE}`);
    });

    it('retitles on a client-side route change', async () => {
      await createComponent('/');

      await router.push('/my-repository');
      await nextTick();

      expect(document.title).toBe(`my-repository · ${BASE_TITLE}`);
    });

    it('retitles when a route resolves its name after navigating', async () => {
      await createComponent(`/my-repository/${ARTIFACT_ID_FOR.MAVEN}`);

      expect(document.title).toBe(`${ARTIFACT_ID_FOR.MAVEN} · my-repository · ${BASE_TITLE}`);

      state.updateName('com.company.payment:core');
      await nextTick();

      expect(document.title).toBe(`com.company.payment:core · my-repository · ${BASE_TITLE}`);
    });
  });
});
