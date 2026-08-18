import { GlModal } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { typePolicies as globalTypePolicies } from '~/lib/graphql';
import { createAlert } from '~/alert';
import DeleteRepositoryModal from 'ee/packages_and_registries/artifact_registry/repositories/components/delete_repository_modal.vue';
import { typePolicies } from 'ee/packages_and_registries/artifact_registry/graphql/cache_config';
import deleteRepositoryMutation from 'ee/packages_and_registries/artifact_registry/graphql/mutations/delete_repository.mutation.graphql';
import getRepositoriesQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repositories.query.graphql';
import { createRouter } from 'ee/packages_and_registries/artifact_registry/router';
import {
  BASE_PATH,
  ORGANIZATION_GID,
  mockDeleteRepositoryResponse,
  mockRepository,
  mockRepositoryPage,
} from '../../mock_data';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('ArtifactRegistryDeleteRepositoryModal', () => {
  let wrapper;
  let router;
  let cache;
  let deleteHandler;
  let toastShow;

  const findModal = () => wrapper.findComponent(GlModal);
  const findPhraseLabel = () => wrapper.findByTestId('confirm-danger-phrase');
  const findConsequenceCopy = () => wrapper.findByTestId('confirm-danger-warning');
  const findConfirmationInput = () => wrapper.findComponentByTestId('confirm-danger-field');
  const findPrimaryAction = () => findModal().props('actionPrimary');
  const findPrimaryActionAttributes = (attr) => findPrimaryAction().attributes[attr];

  const organizationCacheId = () =>
    cache.identify({ __typename: 'Organization', id: ORGANIZATION_GID });

  const repositoryCacheId = (name = mockRepository.name) =>
    cache.identify({ __typename: 'ArtifactRegistryRepository', name });

  // The connection caches under a filter-keyed field, so this matches the field rather than a
  // bare key, which would report it absent whether or not the eviction ran.
  const hasCachedRepositoriesConnection = () =>
    Object.keys(cache.extract()[organizationCacheId()]).some((key) =>
      /^artifactRegistryRepositories[:(]/.test(key),
    );

  const seedRepositoriesList = () => {
    cache.writeQuery({
      query: getRepositoriesQuery,
      variables: { organizationId: ORGANIZATION_GID },
      data: {
        organization: {
          __typename: 'Organization',
          id: ORGANIZATION_GID,
          artifactRegistryRepositories: mockRepositoryPage,
        },
      },
    });
  };

  const createComponent = async ({ deleteResponse } = {}) => {
    deleteHandler = deleteResponse ?? jest.fn().mockResolvedValue(mockDeleteRepositoryResponse());
    toastShow = jest.fn();

    const mockApollo = createMockApollo(
      [[deleteRepositoryMutation, deleteHandler]],
      {},
      { typePolicies: { ...globalTypePolicies, ...typePolicies } },
    );
    cache = mockApollo.clients.defaultClient.cache;
    seedRepositoriesList();

    router = createRouter(BASE_PATH);
    await router.push(`/${mockRepository.name}`);

    wrapper = mountExtended(DeleteRepositoryModal, {
      router,
      apolloProvider: mockApollo,
      propsData: { repository: mockRepository, visible: true },
      provide: { organizationGid: ORGANIZATION_GID },
      mocks: { $toast: { show: toastShow } },
      // The real GlModal renders its content only once shown, so its body is unreachable here.
      // Stubbing it renders the slots and keeps `actionPrimary` readable, which is where the
      // confirm button's state lives.
      stubs: { GlModal: stubComponent(GlModal) },
      attachTo: document.body,
    });

    await waitForPromises();
  };

  const confirm = async () => {
    findModal().vm.$emit('primary');
    await waitForPromises();
  };

  describe('the confirmation gate', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('names the repository as the phrase that has to be typed', () => {
      expect(findPhraseLabel().text()).toBe(
        `Type the repository name below to confirm: ${mockRepository.name}`,
      );
    });

    it('states what deleting the repository destroys', () => {
      expect(findConsequenceCopy().text()).toBe(
        'This action permanently deletes the repository and all of its artifacts. If this repository is connected to a virtual repository, the virtual repository loses access to this repository and its artifacts.',
      );
    });

    it('names the confirm action after what it does', () => {
      expect(findPrimaryAction().text).toBe('Delete repository');
      expect(findPrimaryActionAttributes('variant')).toBe('danger');
    });

    it('keeps the confirm action disabled until the typed name matches', async () => {
      expect(findPrimaryActionAttributes('disabled')).toBe(true);

      await findConfirmationInput().vm.$emit('input', 'not-the-repository');

      expect(findPrimaryActionAttributes('disabled')).toBe(true);

      await findConfirmationInput().vm.$emit('input', mockRepository.name);

      expect(findPrimaryActionAttributes('disabled')).toBe(false);
    });
  });

  describe('when the delete succeeds', () => {
    beforeEach(async () => {
      await createComponent();
      await confirm();
    });

    it('addresses the repository by name', () => {
      expect(deleteHandler).toHaveBeenCalledWith({ input: { name: mockRepository.name } });
    });

    it('evicts the cached repositories connection so the list refetches', () => {
      expect(hasCachedRepositoriesConnection()).toBe(false);
    });

    it('evicts the repository itself, so its detail route cannot read a stale one', () => {
      expect(cache.extract()).not.toHaveProperty(repositoryCacheId());
    });

    it('shows a success toast', () => {
      expect(toastShow).toHaveBeenCalledWith('Repository was successfully deleted.');
    });

    it('returns to the repositories list', () => {
      expect(router.currentRoute.name).toBe('repositories_list');
    });

    it('raises no alert', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });
  });

  describe('when the payload carries errors', () => {
    beforeEach(async () => {
      await createComponent({
        deleteResponse: jest
          .fn()
          .mockResolvedValue(mockDeleteRepositoryResponse({ errors: ['Repository is in use.'] })),
      });
      await confirm();
    });

    it('surfaces the error', () => {
      expect(createAlert).toHaveBeenCalledWith({ message: 'Repository is in use.' });
    });

    it('leaves the repositories connection cached, because nothing was deleted', () => {
      expect(hasCachedRepositoriesConnection()).toBe(true);
    });

    it('shows no success toast and stays put', () => {
      expect(toastShow).not.toHaveBeenCalled();
      expect(router.currentRoute.name).toBe('repository_detail');
    });
  });

  describe('when the mutation fails outright', () => {
    beforeEach(async () => {
      await createComponent({
        deleteResponse: jest.fn().mockRejectedValue(new Error('Artifact Registry is down')),
      });
      await confirm();
    });

    it('reports the failure as a page-level alert', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong. Please try again.',
        error: expect.any(Error),
        captureError: true,
      });
    });

    it('shows no success toast and stays put', () => {
      expect(toastShow).not.toHaveBeenCalled();
      expect(router.currentRoute.name).toBe('repository_detail');
    });
  });
});
