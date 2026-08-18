import { createRouter } from '../../router';
import RepositoryForm from './repository_form.vue';

const BASE_PATH = '/o/gitlab-org/-/artifact_registry/acme/repositories';

const NEW_REPOSITORY = {
  format: 'DOCKER',
  name: '',
  description: '',
  visibility: 'PRIVATE',
};

export default {
  component: RepositoryForm,
  title: 'ee/artifact_registry/repositories/components/repository_form',
};

// The form takes no Apollo provider, which is the point of the extraction: what a
// submit does belongs to the route view that wraps it.
const Template = (_, { argTypes }) => ({
  components: { RepositoryForm },
  props: Object.keys(argTypes),
  router: createRouter(BASE_PATH),
  template: '<repository-form v-bind="$props" />',
});

export const Default = Template.bind({});
Default.args = {
  repository: NEW_REPOSITORY,
  submitText: 'Create repository',
};

// The edit flow's shape: the name is shown but cannot be changed, and the format is
// not offered at all.
export const Edit = Template.bind({});
Edit.args = {
  repository: {
    format: 'MAVEN',
    name: 'my-repository',
    description: 'A hosted Maven repository',
    visibility: 'PRIVATE',
  },
  submitText: 'Save changes',
  nameReadonly: true,
  showFormat: false,
};

export const Submitting = Template.bind({});
Submitting.args = {
  ...Default.args,
  submitting: true,
};

export const WithErrors = Template.bind({});
WithErrors.args = {
  ...Default.args,
  errorMessages: ['Name has already been taken.', 'Format is not supported.'],
};
