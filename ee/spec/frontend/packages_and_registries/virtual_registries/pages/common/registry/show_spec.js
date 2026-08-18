import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlSkeletonLoader } from '@gitlab/ui';
import mavenRegistryUpstreamsFixture from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_maven_virtual_registry_upstreams.query.graphql.json';
import getRegistryQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_registry.query.graphql';
import getRegistryUpstreamsQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_virtual_registry_upstreams.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import RegistryShow from 'ee/packages_and_registries/virtual_registries/pages/common/registry/show.vue';
import RegistryDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/header.vue';
import UpstreamsList from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/upstreams_list.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');

Vue.use(VueApollo);

const defaultProvide = {
  groupPath: 'flightjs',
  initialRegistry: {
    id: 1,
    name: 'Registry 1',
    description: 'Maven Registry',
  },
  ids: {
    baseRegistry: 'VirtualRegistries::Packages::Maven::Registry',
  },
  getRegistryQuery,
  getRegistryUpstreamsQuery,
  registryEditPath: '/groups/flightjs/-/virtual_registries/maven/1/edit',
  editUpstreamPathTemplate: '/groups/flightjs/-/virtual_registries/maven/upstreams/:id/edit',
  showUpstreamPathTemplate: '/groups/flightjs/-/virtual_registries/maven/upstreams/:id',
};

describe('RegistryShow', () => {
  let wrapper;

  const mockError = new Error('GraphQL error');

  const findUpstreamsList = () => wrapper.findComponent(UpstreamsList);
  const findMavenRegistryDetailsHeader = () => wrapper.findComponent(RegistryDetailsHeader);

  const mockRegistryHandler = jest.fn().mockResolvedValue({
    data: {
      registry: {
        ...defaultProvide.initialRegistry,
        id: mavenRegistryUpstreamsFixture.data.registry.id,
      },
    },
  });
  const mavenRegistryUpstreamsHandler = jest.fn().mockResolvedValue(mavenRegistryUpstreamsFixture);
  const errorHandler = jest.fn().mockRejectedValue(mockError);

  const createComponent = ({
    registryHandler = mockRegistryHandler,
    registryUpstreamsHandler = mavenRegistryUpstreamsHandler,
    provide = {},
    propsData = {},
  } = {}) => {
    wrapper = shallowMountExtended(RegistryShow, {
      apolloProvider: createMockApollo([
        [getRegistryQuery, registryHandler],
        [getRegistryUpstreamsQuery, registryUpstreamsHandler],
      ]),
      propsData,
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  describe('loading state', () => {
    it('sets loading prop on initial load', () => {
      createComponent();

      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });

    it('fetches GraphQL queries on initial load', () => {
      createComponent();

      expect(mockRegistryHandler).toHaveBeenCalledTimes(1);
      expect(mockRegistryHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/1',
      });
      expect(mavenRegistryUpstreamsHandler).toHaveBeenCalledTimes(1);
      expect(mavenRegistryUpstreamsHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/1',
      });
    });

    it('does not set loading prop on subsequent loads', async () => {
      createComponent();

      await waitForPromises();

      await findUpstreamsList().vm.$emit('update');

      expect(findUpstreamsList().props('loading')).toBe(false);
    });
  });

  it('shows empty state when registry is not found', async () => {
    createComponent({
      registryHandler: jest.fn().mockResolvedValue({ data: { registry: null } }),
      provide: {
        initialRegistry: {},
      },
      propsData: {
        id: '1',
      },
    });

    await waitForPromises();

    expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
  });

  describe('header', () => {
    it('renders MavenRegistryDetailsHeader component', async () => {
      createComponent();
      await waitForPromises();

      expect(findMavenRegistryDetailsHeader().exists()).toBe(true);
    });
  });

  describe('upstreams list', () => {
    it('displays the upstream registries currently available', async () => {
      createComponent();

      await waitForPromises();

      expect(findUpstreamsList().props()).toEqual({
        id: mavenRegistryUpstreamsFixture.data.registry.id,
        loading: false,
        registryUpstreams: mavenRegistryUpstreamsFixture.data.registry.registryUpstreams,
      });
    });
  });

  describe('with errors', () => {
    it('sends an error to Sentry', async () => {
      createComponent({
        registryUpstreamsHandler: errorHandler,
      });

      await waitForPromises();

      expect(captureException).toHaveBeenCalledWith({
        component: 'RegistryShow',
        error: mockError,
      });
    });
  });

  describe('when upstreams list emits `update` event', () => {
    it('refetches upstreams query', async () => {
      createComponent();

      await waitForPromises();
      await findUpstreamsList().vm.$emit('update');

      expect(mavenRegistryUpstreamsHandler).toHaveBeenCalledTimes(2);
    });
  });
});
