import { GlBreadcrumb } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AiCatalogBreadcrumbs from 'ee/ai/catalog/router/ai_catalog_breadcrumbs.vue';
import {
  AI_CATALOG_INDEX_ROUTE,
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE,
} from 'ee/ai/catalog/router/constants';

describe('AiCatalogBreadcrumbs', () => {
  let wrapper;

  const mockExploreBreadcrumb = {
    text: 'Explore',
    to: '/explore',
  };
  const defaultProps = {
    staticBreadcrumbs: [mockExploreBreadcrumb],
  };

  const createComponent = (routeOptions = { matched: [], params: {} }, { props, provide } = {}) => {
    wrapper = shallowMount(AiCatalogBreadcrumbs, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide,
      mocks: {
        $route: {
          name: AI_CATALOG_INDEX_ROUTE,
          path: '/ai-catalog',
          ...routeOptions,
        },
      },
      stubs: {
        GlBreadcrumb,
      },
    });
  };

  const findBreadcrumb = () => wrapper.findComponent(GlBreadcrumb);
  const getBreadcrumbItems = () => findBreadcrumb().props('items');

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders breadcrumbs', () => {
      expect(findBreadcrumb().exists()).toBe(true);
      expect(findBreadcrumb().props('autoResize')).toBe(false);
    });
  });

  describe.each`
    routeName                                    | expectedText                | matched                                                                                                                                                                                                                         | params
    ${AI_CATALOG_INDEX_ROUTE}                    | ${'AI Catalog'}             | ${[]}                                                                                                                                                                                                                           | ${{}}
    ${AI_CATALOG_AGENTS_ROUTE}                   | ${'Agents'}                 | ${[{ path: '/agents', meta: { text: 'Agents' } }]}                                                                                                                                                                              | ${{}}
    ${AI_CATALOG_AGENTS_NEW_ROUTE}               | ${'New agent'}              | ${[{ path: '/agents', meta: { text: 'Agents' } }, { path: '/agents/new', meta: { text: 'New agent' } }]}                                                                                                                        | ${{}}
    ${AI_CATALOG_AGENTS_EDIT_ROUTE}              | ${'Edit agent'}             | ${[{ path: '/agents', meta: { text: 'Agents' } }, { path: '/agents/:id/edit', meta: { text: 'Edit agent' } }]}                                                                                                                  | ${{ id: 4 }}
    ${AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE} | ${'security_analyst_agent'} | ${[{ path: '/foundational_agents', meta: { text: 'Agents', indexRoute: AI_CATALOG_AGENTS_ROUTE } }, { path: '/foundational_agents/:reference', meta: { useId: true, indexRoute: AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE } }]} | ${{ reference: 'security_analyst_agent' }}
    ${AI_CATALOG_FLOWS_ROUTE}                    | ${'Flows'}                  | ${[{ path: '/flows', meta: { text: 'Flows' } }]}                                                                                                                                                                                | ${{}}
  `('breadcrumbs on $routeName', ({ expectedText, matched, routeName, params }) => {
    beforeEach(() => {
      createComponent({
        name: routeName,
        matched,
        params,
      });
    });

    it('renders correct items', () => {
      const items = getBreadcrumbItems();
      // 1 static route + AI Catalog + dynamic routes
      const totalLength = 2 + matched.length;

      expect(items).toHaveLength(totalLength);
      expect(items[totalLength - 1].text).toBe(expectedText);
    });
  });

  describe('namespace breadcrumbs', () => {
    const groupCrumb = { text: 'Group', to: '/group' };
    const projectCrumb = { text: 'Project', to: '/group/project' };
    const props = {
      staticBreadcrumbs: [groupCrumb],
      allStaticBreadcrumbs: [groupCrumb, projectCrumb],
    };

    const getItemTexts = () => getBreadcrumbItems().map((item) => item.text);

    it('uses the sliced static breadcrumbs by default', () => {
      createComponent({ matched: [], params: {} }, { props });

      expect(getItemTexts()).toEqual(['Group', 'AI Catalog']);
    });

    it('uses the full static breadcrumbs when includeNamespaceBreadcrumbs is injected', () => {
      createComponent(
        { matched: [], params: {} },
        { props, provide: { includeNamespaceBreadcrumbs: true } },
      );

      expect(getItemTexts()).toEqual(['Group', 'Project', 'AI Catalog']);
    });
  });

  describe('AI Catalog root crumb', () => {
    const getRootCrumb = () => getBreadcrumbItems().find((item) => item.text === 'AI Catalog');

    it('links to the AI Catalog index route by default', () => {
      createComponent();

      expect(getRootCrumb().to).toEqual({ name: AI_CATALOG_INDEX_ROUTE });
    });

    it('links to the injected rootRouteName when provided', () => {
      createComponent({ matched: [], params: {} }, { provide: { rootRouteName: 'sessions' } });

      expect(getRootCrumb().to).toEqual({ name: 'sessions' });
    });
  });
});
