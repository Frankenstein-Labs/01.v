import DataExplorer from './data_explorer.vue';

export default {
  component: DataExplorer,
  title: 'ee/explore/analytics_dashboards/data_explorer',
};

const Template = () => ({
  components: { DataExplorer },
  data() {
    return { query: '' };
  },
  template: `<data-explorer v-model="query" />`,
});

export const Default = Template.bind({});
