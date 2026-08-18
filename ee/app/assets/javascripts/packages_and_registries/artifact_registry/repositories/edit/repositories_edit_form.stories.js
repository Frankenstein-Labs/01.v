import createMockApollo from 'helpers/mock_apollo_helper';
import {
  ORGANIZATION_GID,
  mockRepository,
  mockRepositoryResponse,
  mockUpdateRepositoryResponse,
  mockWrittenRepository,
} from 'ee_jest/packages_and_registries/artifact_registry/mock_data';
import { REPOSITORY_EDIT_ROUTE_NAME } from '../../constants';
import updateRepositoryMutation from '../../graphql/mutations/update_repository.mutation.graphql';
import getRepositoryQuery from '../../graphql/queries/get_repository.query.graphql';
import { createRouter } from '../../router';
import RepositoriesEditForm from './repositories_edit_form.vue';

const BASE_PATH = '/o/gitlab-org/-/artifact_registry/acme/repositories';

const prefillHandler = (repository) => () => Promise.resolve(mockRepositoryResponse(repository));

const updateHandler = ({ input }) =>
  Promise.resolve(mockUpdateRepositoryResponse({ repository: mockWrittenRepository(input) }));

export default {
  component: RepositoriesEditForm,
  title: 'ee/artifact_registry/repositories/edit/repositories_edit_form',
};

const Template = (repositoryHandler) => () => {
  // The view reads the repository named in the route, so the story stands on the edit route
  // before it renders.
  const router = createRouter(BASE_PATH);
  router
    .push({ name: REPOSITORY_EDIT_ROUTE_NAME, params: { id: mockRepository.name } })
    .catch(() => {});

  return {
    components: { RepositoriesEditForm },
    router,
    apolloProvider: createMockApollo([
      [getRepositoryQuery, repositoryHandler],
      [updateRepositoryMutation, updateHandler],
    ]),
    provide: { organizationGid: ORGANIZATION_GID },
    template: '<repositories-edit-form />',
  };
};

export const Default = Template(prefillHandler(mockWrittenRepository()));

export const Loading = Template(() => new Promise(() => {}));

export const ServiceUnavailable = Template(() => Promise.reject(new Error('Unavailable')));

export const NotFound = Template(prefillHandler(null));
