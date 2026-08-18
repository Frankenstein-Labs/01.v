import { GlBreadcrumb } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ArtifactRegistryBreadcrumbs from 'ee/packages_and_registries/artifact_registry/repositories/artifact_registry_breadcrumbs.vue';
import { createRouter } from 'ee/packages_and_registries/artifact_registry/router';
import {
  ARTIFACT_ID_FOR,
  BASE_PATH,
  createBreadCrumbState,
  resetBreadCrumbState,
} from '../mock_data';

const MAVEN_PATH = `/payment-core/${ARTIFACT_ID_FOR.MAVEN}`;

describe('ArtifactRegistryBreadcrumbs', () => {
  let wrapper;

  // The Rails page ends its trail with its own Repositories crumb, targeting the Rails
  // URL. `injectVueAppBreadcrumbs` offers that full trail and the same trail with the
  // last crumb sliced off; the component takes the sliced one so the router owns the
  // Repositories crumb, and both are passed here to hold it to that choice.
  const railsBreadcrumbs = [
    { text: 'Acme', href: '/o/acme' },
    { text: 'Repositories', href: BASE_PATH },
  ];

  const propsData = {
    allStaticBreadcrumbs: railsBreadcrumbs,
    staticBreadcrumbs: railsBreadcrumbs.slice(0, -1),
  };

  const mountAt = async (path, resolvedName = '') => {
    const state = createBreadCrumbState();
    state.updateName(resolvedName);

    const router = createRouter(BASE_PATH, state);
    await router.push(path);

    wrapper = mountExtended(ArtifactRegistryBreadcrumbs, { router, propsData });
  };

  const crumbItems = () => wrapper.findComponent(GlBreadcrumb).props('items');

  afterEach(() => {
    resetBreadCrumbState();
  });

  const findCrumbs = () => wrapper.findAll('a');
  const crumbTexts = () => findCrumbs().wrappers.map((crumb) => crumb.text());
  const crumbHrefs = () => findCrumbs().wrappers.map((crumb) => crumb.attributes('href'));

  describe.each`
    path                    | routeCrumbTexts                                 | routeCrumbHrefs
    ${'/'}                  | ${['Repositories']}                             | ${[`${BASE_PATH}/`]}
    ${'/new/hosted'}        | ${['Repositories', 'Create hosted repository']} | ${[`${BASE_PATH}/`, `${BASE_PATH}/new/hosted`]}
    ${'/payment-core'}      | ${['Repositories', 'payment-core']}             | ${[`${BASE_PATH}/`, `${BASE_PATH}/payment-core`]}
    ${'/payment-core/edit'} | ${['Repositories', 'payment-core', 'Edit']}     | ${[`${BASE_PATH}/`, `${BASE_PATH}/payment-core`, `${BASE_PATH}/payment-core/edit`]}
  `('on $path', ({ path, routeCrumbTexts, routeCrumbHrefs }) => {
    beforeEach(async () => {
      await mountAt(path);
    });

    it('trails the sliced static crumbs with one crumb per titled route', () => {
      expect(crumbTexts()).toEqual(['Acme', ...routeCrumbTexts]);
    });

    // A crumb whose target never resolves still renders, so the href is the assertion
    // that holds: a dynamic route named without the current params renders the
    // uninterpolated `/:id`, and a Repositories crumb taken from the Rails trail renders
    // the Rails URL instead of the list route.
    it('resolves every crumb link to a real path', () => {
      expect(crumbHrefs()).toEqual(['/o/acme', ...routeCrumbHrefs]);
    });
  });

  describe('on the version list route', () => {
    it('names the artifact by the name the route resolved, not by its id', async () => {
      await mountAt(MAVEN_PATH, 'com.company.payment:core');

      expect(crumbTexts()).toEqual([
        'Acme',
        'Repositories',
        'payment-core',
        'com.company.payment:core',
      ]);
    });

    it('falls back to the id when no name resolved', async () => {
      await mountAt(MAVEN_PATH);

      expect(crumbTexts()).toEqual(['Acme', 'Repositories', 'payment-core', ARTIFACT_ID_FOR.MAVEN]);
    });

    it('links to the artifact by its id, not by the name it renders', async () => {
      await mountAt(MAVEN_PATH, 'com.company.payment:core');

      expect(crumbHrefs().at(-1)).toBe(`${BASE_PATH}/payment-core/${ARTIFACT_ID_FOR.MAVEN}`);
    });

    it('targets an ancestor crumb with its own params alone', async () => {
      await mountAt(MAVEN_PATH);

      const [, repositoryCrumb] = crumbItems().slice(1);

      expect(repositoryCrumb.to).toEqual({
        name: 'repository_detail',
        params: { id: 'payment-core' },
      });
    });
  });
});
