import AgenticAdoptionFunnelStage from './agentic_adoption_funnel_stage.vue';

export default {
  component: AgenticAdoptionFunnelStage,
  title: 'ee/security_dashboard/charts/agentic_adoption_funnel_stage',
};

const Template = (args, { argTypes }) => ({
  components: { AgenticAdoptionFunnelStage },
  props: Object.keys(argTypes),
  template: `
    <agentic-adoption-funnel-stage
      :count="count"
      :title="title"
      :description="description"
    />
  `,
});

export const Default = Template.bind({});
Default.args = {
  count: 1240,
  title: 'Critical & High SAST vulnerabilities',
};

export const WithDescription = Template.bind({});
WithDescription.args = {
  count: 870,
  title: 'True positive',
  description: 'Vulnerability Resolution',
};
