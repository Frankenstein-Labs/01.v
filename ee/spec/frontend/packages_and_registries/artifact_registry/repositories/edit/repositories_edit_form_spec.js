import { GlAlert, GlSkeletonLoader } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { typePolicies as globalTypePolicies } from '~/lib/graphql';
import { createAlert } from '~/alert';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import NotFound from 'ee/packages_and_registries/artifact_registry/components/not_found.vue';
import FormatLogo from 'ee/packages_and_registries/artifact_registry/repositories/components/format_logo.vue';
import RepositoryForm from 'ee/packages_and_registries/artifact_registry/repositories/components/repository_form.vue';
import RepositoriesEditForm from 'ee/packages_and_registries/artifact_registry/repositories/edit/repositories_edit_form.vue';
import { typePolicies } from 'ee/packages_and_registries/artifact_registry/graphql/cache_config';
import updateRepositoryMutation from 'ee/packages_and_registries/artifact_registry/graphql/mutations/update_repository.mutation.graphql';
import getRepositoriesQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repositories.query.graphql';
import getRepositoryQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository.query.graphql';
import { createRouter } from 'ee/packages_and_registries/artifact_registry/router';
import {
  BASE_PATH,
  ORGANIZATION_GID,
  REPOSITORY_CACHE_ID,
  mockRepositoryPage,
  mockRepositoryResponse,
  mockUpdateRepositoryResponse,
  mockWrittenRepository,
} from '../../mock_data';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('ArtifactRegistryRepositoriesEditForm', () => {
  let wrapper;
  let router;
  let cache;
  let storedRepository;
  let prefillHandler;
  let updateHandler;
  let toastShow;

  const mockErrorResponse = (errors) => mockUpdateRepositoryResponse({ repository: null, errors });

  const findHeading = () => wrapper.findComponent(PageHeading);
  const findHeadingLogo = () => wrapper.findComponent(FormatLogo);
  const findSkeleton = () => wrapper.findComponent(GlSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findNotFound = () => wrapper.findComponent(NotFound);
  const findForm = () => wrapper.findComponent(RepositoryForm);
  const findErrorsAlert = () => wrapper.findComponent(ErrorsAlert);
  const findDescription = () => wrapper.findByTestId('repository-description');

  const organizationCacheId = () =>
    cache.identify({ __typename: 'Organization', id: ORGANIZATION_GID });

  // The connection caches under a filter-keyed field, so this matches the field rather than a
  // bare key, which would report it absent whether or not it was evicted.
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

  const createComponent = async ({ name = 'my-repository' } = {}) => {
    toastShow = jest.fn();

    const mockApollo = createMockApollo(
      [
        [getRepositoryQuery, prefillHandler],
        [updateRepositoryMutation, updateHandler],
      ],
      {},
      { typePolicies: { ...globalTypePolicies, ...typePolicies } },
    );
    cache = mockApollo.clients.defaultClient.cache;

    router = createRouter(BASE_PATH);
    await router.push({ name: 'repository_edit', params: { id: name } });

    wrapper = mountExtended(RepositoriesEditForm, {
      router,
      apolloProvider: mockApollo,
      provide: { organizationGid: ORGANIZATION_GID },
      mocks: { $toast: { show: toastShow } },
      attachTo: document.body,
    });
  };

  const createResolvedComponent = async (options) => {
    await createComponent(options);
    await waitForPromises();
  };

  const submitForm = async () => {
    await wrapper.find('form').trigger('submit');
    await waitForPromises();
  };

  beforeEach(() => {
    // The prefill and the write answer from one stored repository, because a save moves the
    // route while the form is still mounted and the prefill re-reads: a read that answered the
    // pre-save repository would overwrite the write in the cache.
    storedRepository = mockWrittenRepository();

    prefillHandler = jest.fn(() => mockRepositoryResponse({ ...storedRepository }));
    updateHandler = jest.fn(({ input }) => {
      storedRepository = {
        ...storedRepository,
        description: input.description,
        visibility: input.visibility,
      };

      return mockUpdateRepositoryResponse({ repository: { ...storedRepository } });
    });
  });

  describe('while the prefill is in flight', () => {
    beforeEach(async () => {
      // Never answers, so the in-flight state is what renders rather than whatever the microtask
      // order leaves on screen.
      prefillHandler.mockReturnValue(new Promise(() => {}));
      await createResolvedComponent();
    });

    it('shows a skeleton', () => {
      expect(findSkeleton().exists()).toBe(true);
    });

    it('does not render the form yet', () => {
      expect(findForm().exists()).toBe(false);
    });
  });

  describe('once the repository resolves', () => {
    beforeEach(async () => {
      await createResolvedComponent();
    });

    it('asks the server for the repository named in the route', () => {
      expect(prefillHandler).toHaveBeenCalledWith({
        organizationId: ORGANIZATION_GID,
        name: 'my-repository',
      });
    });

    it('names the view', () => {
      expect(findHeading().text()).toContain('Edit hosted repository');
    });

    it('carries the format logo in the heading', () => {
      expect(findHeadingLogo().props()).toMatchObject({ format: 'MAVEN', size: 48 });
    });

    it('prefills the form with what it read', () => {
      expect(findForm().props('repository')).toMatchObject({
        name: 'my-repository',
        description: 'A hosted Maven repository',
      });
    });

    it('shows the name read-only and offers no format, because both are immutable', () => {
      expect(findForm().props()).toMatchObject({ nameReadonly: true, showFormat: false });
      expect(wrapper.findByTestId('repository-format').exists()).toBe(false);
    });

    // An edit is reached from the repository it edits, so abandoning one returns there
    // rather than to the list the viewer has already left.
    it('cancels back to the repository being edited', () => {
      expect(findForm().props('cancelRoute')).toEqual({
        name: 'repository_detail',
        params: { id: 'my-repository' },
      });
    });

    it('drops the skeleton', () => {
      expect(findSkeleton().exists()).toBe(false);
    });
  });

  describe('when the repository does not resolve', () => {
    beforeEach(async () => {
      prefillHandler.mockResolvedValue(mockRepositoryResponse(null));
      await createResolvedComponent({ name: 'no-such-repository' });
    });

    it('renders the not-found state', () => {
      expect(findNotFound().exists()).toBe(true);
    });

    it('renders nothing else', () => {
      expect(findHeading().exists()).toBe(false);
      expect(findForm().exists()).toBe(false);
    });
  });

  describe('when the read fails', () => {
    beforeEach(async () => {
      prefillHandler.mockRejectedValue(new Error('Service unavailable'));
      await createResolvedComponent();
    });

    it('says the service is unavailable while leaving the view rendered', () => {
      expect(findAlert().text()).toBe('The Artifact Registry service is unavailable.');
      expect(findHeading().exists()).toBe(true);
    });

    it('renders no form to submit', () => {
      expect(findForm().exists()).toBe(false);
    });
  });

  describe('when the form is submitted', () => {
    beforeEach(async () => {
      await createResolvedComponent();
      seedRepositoriesList();
      await findDescription().setValue('Updated');
      await waitForPromises();
      await submitForm();
    });

    // `name` addresses the repository rather than renaming it, and `format` is absent outright:
    // both are immutable at Artifact Registry.
    it('sends the identity and the writable fields only', () => {
      expect(updateHandler).toHaveBeenCalledWith({
        input: {
          name: 'my-repository',
          description: 'Updated',
          visibility: 'PRIVATE',
        },
      });
    });

    it('patches the repository in the cache rather than refetching it', () => {
      expect(cache.extract()[REPOSITORY_CACHE_ID]).toMatchObject({ description: 'Updated' });
    });

    it('leaves the cached repositories connection in place', () => {
      expect(hasCachedRepositoriesConnection()).toBe(true);
    });

    it('shows a success toast', () => {
      expect(toastShow).toHaveBeenCalledWith('Repository was successfully updated.');
    });

    it('returns to the repositories list', () => {
      expect(router.currentRoute.name).toBe('repositories_list');
    });

    it('raises no alert', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });
  });

  describe('when the mutation returns a recoverable error', () => {
    beforeEach(async () => {
      updateHandler.mockResolvedValue(mockErrorResponse(['Repository not found.']));
      await createResolvedComponent();
      await submitForm();
    });

    it('renders it above the form rather than as a page-level alert', () => {
      expect(findErrorsAlert().props('errors')).toEqual(['Repository not found.']);
      expect(createAlert).not.toHaveBeenCalled();
    });

    it('stays on the edit view', () => {
      expect(router.currentRoute.name).toBe('repository_edit');
      expect(toastShow).not.toHaveBeenCalled();
    });

    // Otherwise a retry that fails differently shows both sets at once.
    it('drops them when the form is submitted again', async () => {
      updateHandler.mockRejectedValue(new Error('Service unavailable'));
      await submitForm();

      expect(findErrorsAlert().props('errors')).toEqual([]);
    });

    it('clears the errors when the alert is dismissed', async () => {
      findErrorsAlert().vm.$emit('dismiss');
      await waitForPromises();

      expect(findErrorsAlert().props('errors')).toEqual([]);
    });
  });

  describe('when the mutation throws a top-level error', () => {
    beforeEach(async () => {
      updateHandler.mockRejectedValue(new Error('Service unavailable'));
      await createResolvedComponent();
      await submitForm();
    });

    it('raises a generic alert, reports it, and leaves the form rendered', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong. Please try again.',
        error: expect.any(Error),
        captureError: true,
      });
      expect(findForm().exists()).toBe(true);
    });
  });
});
