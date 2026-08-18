import { withVuexStore } from 'storybook_addons/vuex_store';
import createMockApollo from 'helpers/mock_apollo_helper';
import { TASKS_BY_TYPE_MAX_LABELS } from '../../constants';
import { subjectFilter } from './stories_constants';
import TasksByTypeFilters from './filters.vue';

export default {
  component: TasksByTypeFilters,
  title: 'ee/analytics/cycle_analytics/components/tasks_by_type/filters',
  decorators: [withVuexStore],
};

const mockApolloProvider = () => createMockApollo();

const Template = (args, { argTypes, createVuexStore }) => ({
  components: { TasksByTypeFilters },
  apolloProvider: mockApolloProvider(),
  props: Object.keys(argTypes),
  template: '<tasks-by-type-filters v-bind="$props" />',
  store: createVuexStore({
    getters: {
      namespaceRestApiRequestPath: () => 'fake/namespace/path',
    },
  }),
});

export const Default = Template.bind({});
Default.args = {
  maxLabels: TASKS_BY_TYPE_MAX_LABELS,
  selectedLabelNames: [],
  subjectFilter,
};
