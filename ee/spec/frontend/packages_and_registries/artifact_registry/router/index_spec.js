import { mountExtended } from 'helpers/vue_test_utils_helper';
import ArtifactRegistryBreadcrumbs from 'ee/packages_and_registries/artifact_registry/repositories/artifact_registry_breadcrumbs.vue';
import {
  ARTIFACT_VERSIONS_ROUTE_NAME,
  NOT_FOUND_ROUTE_NAME,
  PAGE_NOT_FOUND_TITLE,
  REPOSITORIES_LIST_ROUTE_NAME,
  REPOSITORY_DETAIL_ROUTE_NAME,
  REPOSITORY_EDIT_ROUTE_NAME,
  REPOSITORY_NEW_HOSTED_ROUTE_NAME,
  REPOSITORY_NEW_TITLE,
} from 'ee/packages_and_registries/artifact_registry/constants';
import { createRouter } from 'ee/packages_and_registries/artifact_registry/router';
import { routeName } from 'ee/packages_and_registries/artifact_registry/utils';
import {
  ARTIFACT_ID_FOR,
  BASE_PATH,
  createBreadCrumbState,
  resetBreadCrumbState,
} from '../mock_data';

const ARTIFACT_ID = ARTIFACT_ID_FOR.MAVEN;

describe('Artifact registry repositories router', () => {
  let router;
  let state;

  const getBase = () => router.options.history?.base || router.options.base;

  // The organization crumbs are static, injected from the Rails page, so mounting with
  // none leaves a trail of whatever the routes themselves contribute.
  const findCrumbs = () =>
    mountExtended(ArtifactRegistryBreadcrumbs, {
      router,
      propsData: { staticBreadcrumbs: [] },
    }).findAll('a');

  const crumbTexts = () => findCrumbs().wrappers.map((crumb) => crumb.text());
  const crumbHrefs = () => findCrumbs().wrappers.map((crumb) => crumb.attributes('href'));

  beforeEach(() => {
    state = createBreadCrumbState();
    router = createRouter(BASE_PATH, state);
  });

  afterEach(() => {
    resetBreadCrumbState();
  });

  it('builds a history-mode router based at the slug-scoped repositories path', () => {
    expect(getBase()).toBe(BASE_PATH);
  });

  describe('the repositories list route', () => {
    it('owns the router base, ahead of the not-found fallback', async () => {
      await router.push('/');

      expect(router.currentRoute.name).toBe(REPOSITORIES_LIST_ROUTE_NAME);
    });

    it('contributes the Repositories crumb once, in place of the Rails one', async () => {
      await router.push('/');

      expect(crumbTexts()).toEqual(['Repositories']);
    });
  });

  describe('the hosted create route', () => {
    it('resolves ahead of the not-found fallback', async () => {
      await router.push('/new/hosted');

      expect(router.currentRoute.name).toBe(REPOSITORY_NEW_HOSTED_ROUTE_NAME);
    });

    it('carries the breadcrumb and document title text', async () => {
      await router.push('/new/hosted');

      expect(router.currentRoute.meta.text).toBe(REPOSITORY_NEW_TITLE);
    });

    it('takes over a kind-less /new rather than letting it fall through to not-found', async () => {
      await router.push('/new');

      expect(router.currentRoute.name).toBe(REPOSITORY_NEW_HOSTED_ROUTE_NAME);
      expect(router.currentRoute.path).toBe('/new/hosted');
    });
  });

  describe('the repository detail route', () => {
    it('claims a single path segment as the name of the repository it shows', async () => {
      await router.push('/payment-core');

      expect(router.currentRoute.name).toBe(REPOSITORY_DETAIL_ROUTE_NAME);
      expect(router.currentRoute.params.id).toBe('payment-core');
    });

    it('renders the repository name as the trailing breadcrumb, behind Repositories', async () => {
      await router.push('/payment-core');

      expect(crumbTexts()).toEqual(['Repositories', 'payment-core']);
    });

    // A crumb whose target never resolves still renders its text, so the href is the
    // assertion that holds: naming this route without the current params renders the
    // uninterpolated `/:id`.
    it('links the trail to paths that resolve, not to the route pattern', async () => {
      await router.push('/payment-core');

      expect(crumbHrefs()).toEqual([`${BASE_PATH}/`, `${BASE_PATH}/payment-core`]);
    });

    it('leaves the reserved new-repository segment to the create route', async () => {
      await router.push('/new');

      expect(router.currentRoute.name).toBe(REPOSITORY_NEW_HOSTED_ROUTE_NAME);
    });
  });

  describe('the repository edit route', () => {
    it.each(['my-repository', 'my.repo_1', '0abc'])(
      'addresses the repository named %p',
      async (name) => {
        await router.push(`/${name}/edit`);

        expect(router.currentRoute.name).toBe(REPOSITORY_EDIT_ROUTE_NAME);
        expect(router.currentRoute.params.id).toBe(name);
      },
    );

    // The breadcrumb trail is built from the matched ancestry, so nesting is what puts
    // the repository between Repositories and Edit.
    it('sits under the repository it edits', async () => {
      await router.push('/my-repository/edit');

      const ancestry = router.currentRoute.matched.map(({ path }) => path);

      // The root record spells its own path differently across the two router versions,
      // so the assertion is on the nesting below it.
      expect(ancestry).toHaveLength(3);
      expect(ancestry.slice(1)).toEqual(['/:id', '/:id/edit']);
    });

    // The repository segment is a single wildcard, so it would swallow the create routes
    // if it were registered ahead of them.
    it.each(['/new/hosted', '/new'])('does not take over %p', async (path) => {
      await router.push(path);

      expect(router.currentRoute.name).toBe(REPOSITORY_NEW_HOSTED_ROUTE_NAME);
    });
  });

  describe('the artifact version list route', () => {
    it('addresses the artifact the id names', async () => {
      await router.push(`/payment-core/${ARTIFACT_ID}`);

      expect(router.currentRoute.name).toBe(ARTIFACT_VERSIONS_ROUTE_NAME);
      expect(router.currentRoute.params).toMatchObject({
        id: 'payment-core',
        artifactId: ARTIFACT_ID,
      });
    });

    it('sits under the repository the artifact belongs to', async () => {
      await router.push(`/payment-core/${ARTIFACT_ID}`);

      const ancestry = router.currentRoute.matched.map(({ path }) => path);

      expect(ancestry).toHaveLength(3);
      expect(ancestry.slice(1)).toEqual(['/:id', '/:id/:artifactId']);
    });

    it('leaves the edit segment to the edit route', async () => {
      await router.push('/payment-core/edit');

      expect(router.currentRoute.name).toBe(REPOSITORY_EDIT_ROUTE_NAME);
    });

    it('names itself by the published artifact name, and by the id until there is one', async () => {
      await router.push(`/payment-core/${ARTIFACT_ID}`);

      const { meta } = router.currentRoute.matched.at(-1);

      expect(routeName({ meta, params: router.currentRoute.params })).toBe(ARTIFACT_ID);

      state.updateName('com.company.payment:core');

      expect(routeName({ meta, params: router.currentRoute.params })).toBe(
        'com.company.payment:core',
      );
    });
  });

  describe('unregistered routes', () => {
    it('resolves a multi-segment path to the not-found fallback route', async () => {
      await router.push('/some/unregistered/tab');

      expect(router.currentRoute.name).toBe(NOT_FOUND_ROUTE_NAME);
      expect(router.currentRoute.meta.text).toBe(PAGE_NOT_FOUND_TITLE);
    });
  });
});
