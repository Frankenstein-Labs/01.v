import { createRouter } from '../../router';
import CreateButton from './create_button.vue';

const BASE_PATH = '/o/gitlab-org/-/artifact_registry/acme/repositories';

export default {
  component: CreateButton,
  title: 'ee/artifact_registry/repositories/components/create_button',
};

export const Default = () => ({
  components: { CreateButton },
  // Each entry is a route link, so the button needs a router to resolve its href.
  router: createRouter(BASE_PATH),
  template: '<create-button />',
});
