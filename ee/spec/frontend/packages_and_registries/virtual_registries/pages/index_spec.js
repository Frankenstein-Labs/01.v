import Vue from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlAlert,
  GlCollapsibleListbox,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlEmptyState,
  GlExperimentBadge,
  GlSkeletonLoader,
} from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import VirtualRegistriesApp from 'ee/packages_and_registries/virtual_registries/pages/index.vue';
import getVirtualRegistriesCountsQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_virtual_registries_counts.query.graphql';

Vue.use(VueApollo);

describe('VirtualRegistriesApp', () => {
  let wrapper;

  const defaultProvide = {
    fullPath: 'gitlab-org',
    registryTypes: {
      maven: {
        newPagePath: '/groups/gitlab-org/-/virtual_registries/maven/registries/new',
        landingPagePath: '/groups/gitlab-org/-/virtual_registries/maven/registries_and_upstreams',
        maxRegistriesCount: 20,
      },
      container: {
        newPagePath: '/groups/gitlab-org/-/virtual_registries/container/registries/new',
        landingPagePath: '/groups/gitlab-org/-/virtual_registries/container/registries',
        maxRegistriesCount: 5,
      },
    },
    glAbilities: {
      createVirtualRegistry: true,
    },
  };

  const mavenOnlyProvide = {
    fullPath: 'gitlab-org',
    registryTypes: {
      maven: defaultProvide.registryTypes.maven,
    },
  };

  const containerOnlyProvide = {
    fullPath: 'gitlab-org',
    registryTypes: {
      container: defaultProvide.registryTypes.container,
    },
  };

  const mockCountsResponse = (mavenCount = 5, containerCount = 2) => ({
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        mavenRegistries: { count: mavenCount },
        containerRegistries: { count: containerCount },
      },
    },
  });

  const createComponent = ({
    provide = {},
    countsHandler = jest.fn().mockResolvedValue(mockCountsResponse()),
  } = {}) => {
    wrapper = shallowMountExtended(VirtualRegistriesApp, {
      apolloProvider: createMockApollo([[getVirtualRegistriesCountsQuery, countsHandler]]),
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        PageHeading,
        CrudComponent,
        GlDisclosureDropdown,
        GlDisclosureDropdownItem,
      },
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findRegistryItems = () => wrapper.findAll('.content-list > li');
  const findEmptyStateCreateButton = () => wrapper.findComponentByTestId('create-registry-button');
  const findLinks = () => wrapper.findAllByTestId('view-registries-link');
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDisclosureDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);

  describe('page heading', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the page heading with correct title', () => {
      expect(findPageHeading().text()).toBe('Virtual registry');
    });

    it('renders the beta experiment badge', () => {
      expect(findExperimentBadge().props('type')).toBe('beta');
    });
  });

  describe('loading state', () => {
    it('renders skeleton loader while loading', () => {
      createComponent();

      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findEmptyState().exists()).toBe(false);
      expect(findRegistryItems()).toHaveLength(0);
    });

    it('hides skeleton loader after loading', async () => {
      createComponent();
      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(false);
    });
  });

  describe('when there are registries with count', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the crud component with correct title', () => {
      expect(findCrudComponent().props('title')).toBe('Registry types');
    });

    it('renders registry items for each type', () => {
      expect(findRegistryItems()).toHaveLength(2);
    });

    it('renders registry type names', () => {
      const items = findRegistryItems();
      expect(items.at(0).text()).toContain('Maven');
      expect(items.at(1).text()).toContain('Container');
    });

    it('renders view registries links', () => {
      const links = findLinks();
      expect(links.at(0).attributes('href')).toBe(
        defaultProvide.registryTypes.maven.landingPagePath,
      );
      expect(links.at(0).text()).toBe('View registries');
    });

    it('renders create registry dropdown when user has permission', () => {
      expect(findDisclosureDropdown().props()).toMatchObject({
        toggleText: 'Create registry',
        variant: 'confirm',
      });
    });

    it('renders dropdown items for each registry type', () => {
      const items = findDisclosureDropdownItems();
      expect(items).toHaveLength(2);
      expect(items.at(0).props('item')).toEqual({
        text: 'Maven',
        href: defaultProvide.registryTypes.maven.newPagePath,
      });

      expect(items.at(0).text()).toBe('Maven');

      expect(items.at(1).props('item')).toEqual({
        text: 'Container',
        href: defaultProvide.registryTypes.container.newPagePath,
      });
      expect(items.at(1).text()).toBe('Container');
    });

    it('does not render empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });
  });

  describe('when user does not have permission to create registry', () => {
    beforeEach(async () => {
      createComponent({
        provide: {
          glAbilities: {
            createVirtualRegistry: false,
          },
        },
      });
      await waitForPromises();
    });

    it('does not render create registry dropdown', () => {
      expect(findDisclosureDropdown().exists()).toBe(false);
    });

    it('does not show max reached message', () => {
      expect(wrapper.text()).not.toContain('Maximum number of registries reached.');
    });
  });

  describe('when max registries count is reached for all types', () => {
    beforeEach(async () => {
      createComponent({
        countsHandler: jest.fn().mockResolvedValue(mockCountsResponse(20, 5)),
      });
      await waitForPromises();
    });

    it('shows max reached message in header instead of dropdown', () => {
      expect(wrapper.text()).toContain('Maximum number of registries reached.');
    });

    it('does not render create registry dropdown', () => {
      expect(findDisclosureDropdown().exists()).toBe(false);
    });
  });

  describe('when some registries have max count reached and others do not', () => {
    beforeEach(async () => {
      createComponent({
        countsHandler: jest.fn().mockResolvedValue(mockCountsResponse(20, 2)),
      });
      await waitForPromises();
    });

    it('shows max reached message for maven in the row', () => {
      const items = findRegistryItems();
      expect(items.at(0).text()).toContain('Maximum number of registries reached.');
    });

    it('renders dropdown with only non-maxed registry types', () => {
      expect(findDisclosureDropdown().exists()).toBe(true);
      const items = findDisclosureDropdownItems();
      expect(items).toHaveLength(1);
      expect(items.at(0).props('item')).toEqual({
        text: 'Container',
        href: defaultProvide.registryTypes.container.newPagePath,
      });
      expect(items.at(0).text()).toBe('Container');
    });
  });

  describe('empty state with both registry types enabled', () => {
    beforeEach(async () => {
      createComponent({
        countsHandler: jest.fn().mockResolvedValue(mockCountsResponse(0, 0)),
      });
      await waitForPromises();
    });

    it('renders empty state with correct title', () => {
      expect(findEmptyState().props('title')).toBe('Get started with virtual registries');
    });

    it('renders collapsible listbox with maven selected by default', () => {
      expect(findCollapsibleListbox().props('toggleText')).toBe('Maven');
    });

    it('renders create registry button next to listbox', () => {
      const button = findEmptyStateCreateButton();
      expect(button.text()).toBe('Create registry');
      expect(button.props('variant')).toBe('confirm');
      expect(button.attributes('href')).toBe(defaultProvide.registryTypes.maven.newPagePath);
    });

    it('passes correct items to collapsible listbox', () => {
      expect(findCollapsibleListbox().props('items')).toEqual([
        {
          value: 'maven',
          text: 'Maven',
        },
        {
          value: 'container',
          text: 'Container',
        },
      ]);
    });

    it('updates toggle text and button href when registry type is changed', async () => {
      await findCollapsibleListbox().vm.$emit('select', 'container');

      expect(findCollapsibleListbox().props('toggleText')).toBe('Container');

      const button = findEmptyStateCreateButton();
      expect(button.attributes('href')).toBe(defaultProvide.registryTypes.container.newPagePath);
    });
  });

  describe('empty state with only maven registry type enabled', () => {
    beforeEach(async () => {
      createComponent({
        provide: mavenOnlyProvide,
        countsHandler: jest.fn().mockResolvedValue(mockCountsResponse(0, 0)),
      });
      await waitForPromises();
    });

    it('passes correct items to collapsible listbox', () => {
      expect(findCollapsibleListbox().props('items')).toEqual([
        {
          value: 'maven',
          text: 'Maven',
        },
      ]);
    });

    it('renders create registry button with right href', () => {
      expect(findEmptyStateCreateButton().attributes('href')).toBe(
        defaultProvide.registryTypes.maven.newPagePath,
      );
    });
  });

  describe('empty state with only container registry type enabled', () => {
    beforeEach(async () => {
      createComponent({
        provide: containerOnlyProvide,
        countsHandler: jest.fn().mockResolvedValue(mockCountsResponse(0, 0)),
      });
      await waitForPromises();
    });

    it('passes correct items to collapsible listbox', () => {
      expect(findCollapsibleListbox().props('items')).toEqual([
        {
          value: 'container',
          text: 'Container',
        },
      ]);
    });

    it('renders create registry button with right href', () => {
      expect(findEmptyStateCreateButton().attributes('href')).toBe(
        defaultProvide.registryTypes.container.newPagePath,
      );
    });
  });

  describe('when there are no registries with count and user has no permission', () => {
    beforeEach(async () => {
      createComponent({
        provide: {
          glAbilities: {
            createVirtualRegistry: false,
          },
        },
        countsHandler: jest.fn().mockResolvedValue(mockCountsResponse(0, 0)),
      });
      await waitForPromises();
    });

    it('renders the empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
    });

    it('does not render create registry button or listbox', () => {
      expect(findEmptyStateCreateButton().exists()).toBe(false);
      expect(findCollapsibleListbox().exists()).toBe(false);
    });
  });

  describe('when GraphQL query fails', () => {
    beforeEach(async () => {
      createComponent({
        countsHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
      });
      await waitForPromises();
    });

    it('renders error alert', () => {
      expect(findAlert().props('variant')).toBe('danger');
      expect(findAlert().props('dismissible')).toBe(false);
      expect(findAlert().text()).toBe(
        'An error occurred while fetching virtual registries. Please try again.',
      );
    });

    it('does not render empty state or crud component', () => {
      expect(findEmptyState().exists()).toBe(false);
      expect(findCrudComponent().exists()).toBe(false);
    });
  });

  describe('GraphQL query variables', () => {
    it('includes both registry types when both are enabled', async () => {
      const handler = jest.fn().mockResolvedValue(mockCountsResponse());
      createComponent({ countsHandler: handler });
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith({
        groupPath: 'gitlab-org',
        includeMaven: true,
        includeContainer: true,
      });
    });

    it('includes only maven when only maven is enabled', async () => {
      const handler = jest.fn().mockResolvedValue(mockCountsResponse());
      createComponent({ provide: mavenOnlyProvide, countsHandler: handler });
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith({
        groupPath: 'gitlab-org',
        includeMaven: true,
        includeContainer: false,
      });
    });

    it('includes only container when only container is enabled', async () => {
      const handler = jest.fn().mockResolvedValue(mockCountsResponse());
      createComponent({ provide: containerOnlyProvide, countsHandler: handler });
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith({
        groupPath: 'gitlab-org',
        includeMaven: false,
        includeContainer: true,
      });
    });
  });
});
