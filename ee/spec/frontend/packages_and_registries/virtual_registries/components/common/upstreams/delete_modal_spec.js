import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlSkeletonLoader, GlTruncateText } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { deleteMavenUpstream } from 'ee/api/virtual_registries_api';
import DeleteUpstreamWithModal from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/delete_modal.vue';
import getUpstreamRegistriesQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_registries.query.graphql';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import { mavenUpstreamRegistry } from '../../../mock_data';

Vue.use(VueApollo);

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');
jest.mock('ee/api/virtual_registries_api', () => ({
  deleteMavenUpstream: jest.fn(),
}));

describe('DeleteUpstreamWithModal', () => {
  let wrapper;

  const defaultProps = {
    upstreamId: 123,
    upstreamName: 'Test upstream',
  };

  const mockRegistries = [
    { id: 1, name: 'Registry 1' },
    { id: 2, name: 'Registry 2' },
    { id: 3, name: 'Registry 3' },
  ];

  const findModal = () => wrapper.findComponent(GlModal);
  const findTruncateText = () => wrapper.findComponent(GlTruncateText);
  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);

  const mockUpstreamRegistries = {
    data: {
      upstream: {
        ...mavenUpstreamRegistry,
        registryUpstreams: mockRegistries.map((registry) => ({
          __typename: 'MavenRegistryUpstream',
          id: registry.id.toString(),
          position: 0,
          registry: {
            __typename: 'MavenVirtualRegistry',
            id: registry.id.toString(),
            name: registry.name,
          },
        })),
      },
    },
  };
  const mavenUpstreamRegistriesHandler = jest.fn().mockResolvedValue(mockUpstreamRegistries);
  const mockError = new Error('API error');
  const errorHandler = jest.fn().mockRejectedValue(mockError);

  const createComponent = ({
    props,
    handlers = [[getUpstreamRegistriesQuery, mavenUpstreamRegistriesHandler]],
  } = {}) => {
    wrapper = shallowMountExtended(DeleteUpstreamWithModal, {
      apolloProvider: createMockApollo(handlers),
      provide: {
        getUpstreamRegistriesQuery,
        ids: {
          baseUpstream: 'VirtualRegistries::Packages::Maven::Upstream',
        },
      },
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  beforeEach(() => {
    deleteMavenUpstream.mockReset();
  });

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the modal with correct props', () => {
      const modal = findModal();

      expect(modal.props()).toMatchObject({
        modalId: 'delete-upstream-modal',
        size: 'md',
        actionPrimary: {
          text: 'Delete',
          attributes: {
            variant: 'danger',
            category: 'primary',
          },
        },
        actionCancel: {
          text: 'Cancel',
        },
      });
      expect(modal.attributes('title')).toBe('Delete upstream');
    });

    it('initially has modal closed', () => {
      expect(findModal().props('visible')).toBe(false);
    });

    it('does not call the GraphQL query to fetch registry names', () => {
      expect(mavenUpstreamRegistriesHandler).not.toHaveBeenCalled();
    });

    describe.each(['upstreamId', 'upstreamName'])('when %s is not set', (prop) => {
      beforeEach(() => {
        createComponent({ props: { [prop]: null } });
      });

      it('does not render modal', () => {
        expect(findModal().exists()).toBe(false);
      });

      it('does not call the GraphQL query to fetch registry names', () => {
        expect(mavenUpstreamRegistriesHandler).not.toHaveBeenCalled();
      });
    });

    describe('when visible', () => {
      beforeEach(() => {
        createComponent({ props: { visible: true } });
      });

      it('shows modal', () => {
        expect(findModal().props('visible')).toBe(true);
      });

      it('renders loading component when the query is being made', () => {
        expect(findLoader().exists()).toBe(true);
      });

      it('calls the GraphQL query with right parameters', () => {
        expect(mavenUpstreamRegistriesHandler).toHaveBeenCalledWith({
          id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/123',
        });
      });

      it('emits canceled event when modal is canceled', () => {
        findModal().vm.$emit('canceled');

        expect(wrapper.emitted('canceled')).toHaveLength(1);
      });

      describe('when GraphQL query to get registries fails', () => {
        it('calls captureException with the error', async () => {
          createComponent({
            props: { visible: true },
            handlers: [[getUpstreamRegistriesQuery, errorHandler]],
          });

          await waitForPromises();
          expect(captureException).toHaveBeenCalledWith({
            error: mockError,
            component: 'DeleteUpstreamWithModal',
          });
        });
      });

      describe('modal content', () => {
        describe('when upstream has no associated registries', () => {
          const handler = jest.fn().mockResolvedValue({
            data: {
              upstream: {
                ...mavenUpstreamRegistry,
                registryUpstreams: [],
              },
            },
          });
          beforeEach(async () => {
            createComponent({
              props: { visible: true },
              handlers: [[getUpstreamRegistriesQuery, handler]],
            });
            await waitForPromises();
          });

          it('shows simple confirmation message', () => {
            expect(wrapper.text()).toContain('Are you sure you want to delete Test upstream?');
          });

          it('does not show registries list', () => {
            expect(findTruncateText().exists()).toBe(false);
          });

          it('does not show warning message', () => {
            expect(wrapper.text()).not.toContain('This action cannot be undone');
          });
        });

        describe('when upstream has associated registries', () => {
          beforeEach(async () => {
            createComponent({ props: { visible: true } });
            await waitForPromises();
          });

          it('shows warning message with registry count', () => {
            expect(wrapper.text()).toContain(
              'You are about to delete this upstream used by 3 registries:',
            );
          });

          it('shows truncated list of registries', () => {
            const truncateText = findTruncateText();
            expect(truncateText.exists()).toBe(true);

            const registryItems = wrapper.findAll('li');
            expect(registryItems).toHaveLength(3);
            expect(registryItems.at(0).text()).toBe('Registry 1');
            expect(registryItems.at(1).text()).toBe('Registry 2');
            expect(registryItems.at(2).text()).toBe('Registry 3');
          });

          it('shows impact warning message', () => {
            expect(wrapper.text()).toContain(
              'This action cannot be undone. Deleting this upstream might impact registries associated with it.',
            );
          });

          it('does not show simple confirmation message', () => {
            expect(wrapper.text()).not.toContain('Are you sure you want to delete Test upstream?');
          });
        });
      });
    });
  });

  describe('delete functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls deleteMavenUpstream with correct parameters', async () => {
      deleteMavenUpstream.mockResolvedValue();

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(deleteMavenUpstream).toHaveBeenCalledWith({
        id: 123,
      });
    });

    it('emits success event when deletion succeeds', async () => {
      deleteMavenUpstream.mockResolvedValue();

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(wrapper.emitted('success')).toHaveLength(1);
      expect(wrapper.emitted('error')).toBeUndefined();
    });

    it('emits error event when deletion fails', async () => {
      const error = new Error('API Error');
      deleteMavenUpstream.mockRejectedValue(error);

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
      expect(wrapper.emitted('error')[0]).toEqual([error]);
      expect(wrapper.emitted('success')).toBeUndefined();
    });
  });
});
