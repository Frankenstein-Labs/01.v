import DashboardSettingsForm from './dashboard_settings_form.vue';

export default {
  component: DashboardSettingsForm,
  title: 'ee/explore/analytics_dashboards/dashboard_settings_form',
};

const Template = (args, { argTypes }) => ({
  components: { DashboardSettingsForm },
  props: Object.keys(argTypes),
  data() {
    return {
      formData: args.value,
    };
  },
  watch: {
    value(newVal) {
      this.formData = newVal;
    },
  },
  methods: {
    handleInput(newValue) {
      this.formData = newValue;
      this.$emit('input', newValue);
    },
  },
  template: `
    <dashboard-settings-form
      :value="formData"
      :is-loading="isLoading"
      @input="handleInput"
    />
  `,
});

export const BlankState = Template.bind({});
BlankState.args = {
  value: {
    title: '',
    description: '',
  },
  isLoading: false,
};

export const FilledState = Template.bind({});
FilledState.args = {
  value: {
    title: 'My Analytics Dashboard',
    description: 'A comprehensive dashboard for tracking team metrics and performance indicators',
  },
  isLoading: false,
};

export const LoadingState = Template.bind({});
LoadingState.args = {
  value: {
    title: 'My Analytics Dashboard',
    description: 'A comprehensive dashboard for tracking team metrics and performance indicators',
  },
  isLoading: true,
};
