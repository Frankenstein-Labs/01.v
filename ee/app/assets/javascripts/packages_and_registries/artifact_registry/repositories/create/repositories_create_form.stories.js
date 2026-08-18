import createMockApollo from 'helpers/mock_apollo_helper';
import {
  ORGANIZATION_GID,
  mockCreateRepositoryResponse,
} from 'ee_jest/packages_and_registries/artifact_registry/mock_data';
import createRepositoryMutation from '../../graphql/mutations/create_repository.mutation.graphql';
import { createRouter } from '../../router';
import RepositoriesCreateForm from './repositories_create_form.vue';

const BASE_PATH = '/o/gitlab-org/-/artifact_registry/acme/repositories';

const createHandler = () => Promise.resolve(mockCreateRepositoryResponse());

export default {
  component: RepositoriesCreateForm,
  title: 'ee/artifact_registry/repositories/create/repositories_create_form',
};

const Template = () => ({
  components: { RepositoriesCreateForm },
  // The page is a route component, so it needs a router to render standalone.
  router: createRouter(BASE_PATH),
  apolloProvider: createMockApollo([[createRepositoryMutation, createHandler]]),
  provide: { organizationGid: ORGANIZATION_GID },
  template: '<repositories-create-form />',
});

export const Default = Template.bind({});
