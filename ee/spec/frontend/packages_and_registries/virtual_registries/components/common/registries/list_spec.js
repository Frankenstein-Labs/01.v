import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlEmptyState, GlSkeletonLoader } from '@gitlab/ui';
import containerRegistriesPayload from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_container_virtual_registries.query.graphql.json';
import mavenRegistriesPayload from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_maven_virtual_registries.query.graphql.json';
import RegistriesList from 'ee/packages_and_registries/virtual_registries/components/common/registries/list.vue';
import getMavenVirtualRegistriesQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_virtual_registries.query.graphql';
import getContainerVirtualRegistriesQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_virtual_registries.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import RegistriesTable from 'ee/packages_and_registries/virtual_registries/components/common/registries/table.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import ContainerI18n from 'ee/packages_and_registries/virtual_registries/pages/container/i18n';
import MavenI18n from 'ee/packages_and_registries/virtual_registries/pages/maven/i18n';

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');

Vue.use(VueApollo);

const PAGE_SIZE = 20;

describe('RegistriesList', () => {
  let wrapper;

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findRegistriesTable = () => wrapper.findComponent(RegistriesTable);

  describe.each`
    type           | getRegistriesQuery                    | i18n             | registriesPayload
    ${'maven'}     | ${getMavenVirtualRegistriesQuery}     | ${MavenI18n}     | ${mavenRegistriesPayload}
    ${'container'} | ${getContainerVirtualRegistriesQuery} | ${ContainerI18n} | ${containerRegistriesPayload}
  `('$type virtual registry', ({ getRegistriesQuery, registriesPayload, i18n }) => {
    const defaultProvide = {
      fullPath: 'gitlab-org',
      getRegistriesQuery,
      i18n,
    };

    const createComponent = ({ handlers = [] } = {}) => {
      wrapper = shallowMountExtended(RegistriesList, {
        apolloProvider: createMockApollo(handlers),
        provide: defaultProvide,
      });
    };
    const mockEmptyRegistries = {
      data: {
        group: {
          ...registriesPayload.data.group,
          registries: { nodes: [], pageInfo: {} },
        },
      },
    };

    const { nodes: registries } = registriesPayload.data.group.registries;

    const registriesHandler = jest.fn().mockResolvedValue(registriesPayload);
    const emptyRegistriesHandler = jest.fn().mockResolvedValue(mockEmptyRegistries);
    const mockError = new Error('GraphQL error');
    const errorHandler = jest.fn().mockRejectedValue(mockError);

    describe('component initialization', () => {
      beforeEach(() => {
        createComponent({
          handlers: [[getRegistriesQuery, registriesHandler]],
        });
      });

      it('calls the GraphQL query with right parameters', () => {
        expect(registriesHandler).toHaveBeenCalledWith({
          groupPath: defaultProvide.fullPath,
          first: PAGE_SIZE,
        });
      });

      it('displays the skeleton loader during loading', () => {
        expect(findSkeletonLoader().exists()).toBe(true);
        expect(findAlert().exists()).toBe(false);
        expect(findEmptyState().exists()).toBe(false);
        expect(findRegistriesTable().exists()).toBe(false);
      });

      describe('when the API returns data', () => {
        it('displays the registry items with the correct props', async () => {
          await waitForPromises();

          expect(findSkeletonLoader().exists()).toBe(false);
          expect(findAlert().exists()).toBe(false);
          expect(findEmptyState().exists()).toBe(false);

          expect(findRegistriesTable().props('registries')).toEqual(registries);
        });

        it('emits `update-count` event', async () => {
          await waitForPromises();

          expect(wrapper.emitted('update-count')[0][0]).toBe(1);
        });
      });
    });

    describe('when the API returns an empty array', () => {
      it('displays the empty state', async () => {
        createComponent({
          handlers: [[getRegistriesQuery, emptyRegistriesHandler]],
        });

        await waitForPromises();

        expect(findSkeletonLoader().exists()).toBe(false);
        expect(findAlert().exists()).toBe(false);

        expect(findEmptyState().props('title')).toBe(i18n.registries.emptyStateTitle);
        expect(findRegistriesTable().exists()).toBe(false);
      });
    });

    describe('when the API fails', () => {
      it('displays an error message', async () => {
        createComponent({ handlers: [[getRegistriesQuery, errorHandler]] });

        await waitForPromises();

        expect(findSkeletonLoader().exists()).toBe(false);
        expect(findEmptyState().exists()).toBe(false);
        expect(findRegistriesTable().exists()).toBe(false);

        expect(findAlert().text()).toBe('GraphQL error');
        expect(captureException).toHaveBeenCalledWith({
          component: 'RegistriesList',
          error: mockError,
        });
      });
    });
  });
});
