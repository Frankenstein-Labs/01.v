import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlIcon, GlCollapsibleListbox, GlLink } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import DependencyLocationCount from 'ee/dependencies/components/dependency_location_count.vue';
import getDependencyLocations from 'ee/dependencies/graphql/dependency_locations.query.graphql';
import { SEARCH_MIN_THRESHOLD } from 'ee/dependencies/components/constants';

Vue.use(VueApollo);

describe('Dependency Location Count component', () => {
  let wrapper;

  const blobPath = '/blob_path/Gemfile.lock';
  const path = 'Gemfile.lock';
  const projectName = 'test-project';
  const projectFullPath = 'group/test-project';
  const fullPath = 'test-group';
  const unknownPath = 'Unknown path';
  const topLevelText = '(top level)';

  const createGraphQLResponse = (nodes) => ({
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        dependencyLocations: {
          nodes,
        },
      },
    },
  });

  const createLocationNode = ({ location = {}, project = {}, ...overrides } = {}) => ({
    occurrenceId: 'gid://gitlab/Sbom::Occurrence/1',
    hasDependencyPaths: false,
    ...overrides,
    location: { blobPath, path, topLevel: false, ...location },
    project: {
      id: 'gid://gitlab/Project/1',
      name: projectName,
      fullPath: projectFullPath,
      ...project,
    },
  });

  const locationsData = [createLocationNode()];

  const graphqlResponse = createGraphQLResponse(locationsData);

  let apolloResolver;

  const createComponent = ({
    propsData,
    mountFn = shallowMountExtended,
    dependencyPaths = true,
    handler = apolloResolver,
    ...options
  } = {}) => {
    wrapper = mountFn(DependencyLocationCount, {
      propsData: {
        locationCount: 2,
        componentId: 1,
        ...propsData,
      },
      apolloProvider: createMockApollo([[getDependencyLocations, handler]]),
      provide: {
        fullPath,
        glFeatures: {
          dependencyPaths,
        },
      },
      ...options,
    });
  };

  const findToggleText = () => wrapper.findByTestId('toggle-text');
  const findLocationList = () => wrapper.findComponent(GlCollapsibleListbox);
  const findLocationInfo = () => wrapper.findComponent(GlLink);
  const findUnknownLocationInfo = () => wrapper.findByTestId('unknown-path');
  const findUnknownLocationIcon = () => findUnknownLocationInfo().findComponent(GlIcon);
  const findDependencyPathButton = () => wrapper.findComponentByTestId('dependency-path-button');

  const clickLocationList = async () => {
    await findLocationList().vm.$emit('shown');
    await waitForPromises();
  };

  beforeEach(() => {
    apolloResolver = jest.fn().mockResolvedValue(graphqlResponse);
  });

  it('renders toggle text', () => {
    createComponent();

    expect(findToggleText().html()).toMatchSnapshot();
  });

  it.each`
    locationCount | headerText
    ${1}          | ${'1 location'}
    ${2}          | ${'2 locations'}
  `(
    'renders correct location text when `locationCount` is $locationCount',
    ({ locationCount, headerText }) => {
      createComponent({
        propsData: {
          locationCount,
        },
      });

      expect(findLocationList().props('headerText')).toBe(headerText);
    },
  );

  it('renders the listbox', () => {
    createComponent();

    expect(findLocationList().props()).toMatchObject({
      headerText: '2 locations',
      searchable: true,
      items: [],
      loading: false,
      searching: true,
    });
  });

  describe('with fetched data', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mountExtended,
      });
    });

    it('sets searching based on the data being fetched', async () => {
      await findLocationList().vm.$emit('shown');

      expect(findLocationList().props('searching')).toBe(true);

      await waitForPromises();

      expect(apolloResolver).toHaveBeenCalled();

      expect(findLocationList().props('searching')).toBe(false);
    });

    it('sets searching when search term is updated', async () => {
      await findLocationList().vm.$emit('search', 'a');

      expect(findLocationList().props('searching')).toBe(true);

      await waitForPromises();

      expect(findLocationList().props('searching')).toBe(false);
    });

    it('renders location information', async () => {
      await clickLocationList();

      expect(findLocationInfo().attributes('href')).toBe(blobPath);
      expect(findLocationInfo().text()).toContain(path);
      expect(wrapper.text()).toContain(projectName);
      expect(wrapper.text()).not.toContain(topLevelText);
    });

    it('renders no locations without throwing when dependencyLocations is null', async () => {
      apolloResolver = jest.fn().mockResolvedValue({
        data: { group: { id: 'gid://gitlab/Group/1', dependencyLocations: null } },
      });
      createComponent({ mountFn: mountExtended });

      await clickLocationList();

      expect(findLocationList().props('items')).toEqual([]);
    });

    describe('when top level is set to true', () => {
      beforeEach(() => {
        apolloResolver = jest
          .fn()
          .mockResolvedValue(
            createGraphQLResponse([createLocationNode({ location: { topLevel: true } })]),
          );
        createComponent({
          mountFn: mountExtended,
        });
      });

      it('renders location information', async () => {
        await clickLocationList();

        expect(findLocationInfo().attributes('href')).toBe(blobPath);
        expect(findLocationInfo().text()).toContain(path);
        expect(wrapper.text()).toContain(projectName);
        expect(wrapper.text()).toContain(topLevelText);
      });
    });

    describe('with unknown path', () => {
      beforeEach(() => {
        apolloResolver = jest
          .fn()
          .mockResolvedValue(
            createGraphQLResponse([
              createLocationNode({ location: { blobPath: null, path: null } }),
            ]),
          );
        createComponent({
          mountFn: mountExtended,
        });
      });

      it('renders location information', async () => {
        await clickLocationList();

        expect(findUnknownLocationIcon().props('name')).toBe('error');
        expect(findUnknownLocationInfo().text()).toContain(unknownPath);
        expect(wrapper.text()).toContain(projectName);
      });
    });

    describe.each`
      locationCount               | searchable
      ${SEARCH_MIN_THRESHOLD - 1} | ${false}
      ${SEARCH_MIN_THRESHOLD + 1} | ${true}
    `('with location count equal to $locationCount', ({ locationCount, searchable }) => {
      beforeEach(() => {
        createComponent({
          propsData: { locationCount },
        });
      });

      it(`renders listbox with searchable set to ${searchable}`, async () => {
        await clickLocationList();

        expect(findLocationList().props()).toMatchObject({
          headerText: `${locationCount} locations`,
          searchable,
        });
      });
    });

    describe('with dependency path', () => {
      const dependencyPathNode = createLocationNode({
        location: { blobPath: null, path: null },
        hasDependencyPaths: true,
      });

      beforeEach(() => {
        apolloResolver = jest.fn().mockResolvedValue(createGraphQLResponse([dependencyPathNode]));
        createComponent({
          mountFn: mountExtended,
        });
      });

      it('shows the dependency path button', async () => {
        await clickLocationList();
        expect(findDependencyPathButton().exists()).toBe(true);
      });

      it('emits event and passes the project and selected location data', async () => {
        await clickLocationList();

        findDependencyPathButton().vm.$emit('click');
        await waitForPromises();

        const emittedData = wrapper.emitted('click-dependency-path')[0][0];

        expect(emittedData).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              location: dependencyPathNode.location,
              project: dependencyPathNode.project,
              value: 0,
            }),
          ]),
        );
      });

      it('does not show the dependency path button', async () => {
        apolloResolver = jest
          .fn()
          .mockResolvedValue(
            createGraphQLResponse([{ ...dependencyPathNode, hasDependencyPaths: false }]),
          );
        createComponent({
          mountFn: mountExtended,
        });

        await clickLocationList();

        expect(findDependencyPathButton().exists()).toBe(false);
      });

      describe('when feature flag "dependencyPaths" is disabled', () => {
        it('does not show the dependency path', async () => {
          createComponent({
            mountFn: mountExtended,
            dependencyPaths: false,
          });

          await clickLocationList();

          expect(findDependencyPathButton().exists()).toBe(false);
        });
      });
    });
  });
});
