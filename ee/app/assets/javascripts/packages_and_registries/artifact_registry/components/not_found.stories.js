import NotFound from './not_found.vue';

export default {
  component: NotFound,
  title: 'ee/artifact_registry/repositories/not_found',
};

export const Default = () => ({
  components: { NotFound },
  template: '<not-found />',
});
