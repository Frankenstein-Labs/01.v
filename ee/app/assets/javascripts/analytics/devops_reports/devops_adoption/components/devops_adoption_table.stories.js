import { mockDevopsAdoptionNamespace } from './stories_constants';
import DevopsAdoptionTable from './devops_adoption_table.vue';

const mockEnabledSpaces = [mockDevopsAdoptionNamespace];

const mockCols = [
  {
    key: 'mergeRequestApproved',
    label: 'Approvals',
    tooltip: 'At least one approval on a merge request',
    testId: 'approvalsCol',
  },
  {
    key: 'codeOwnersUsedCount',
    label: 'Code owners',
    tooltip: 'Code owners enabled for at least one project',
    testId: 'codeownersCol',
  },
  {
    key: 'issueOpened',
    label: 'Issues',
    tooltip: 'At least one issue created',
    testId: 'issuesCol',
  },
  {
    key: 'mergeRequestOpened',
    label: 'MRs',
    tooltip: 'At least one merge request created',
    testId: 'mrsCol',
  },
];

export default {
  component: DevopsAdoptionTable,
  title: 'ee/analytics/devops_reports/devops_adoption/components/devops_adoption_table',
};

const Template = (args, { argTypes }) => ({
  components: { DevopsAdoptionTable },
  props: Object.keys(argTypes),
  provide: {
    groupGid: 'fake-group',
  },
  template: `<devops-adoption-table v-bind="$props" />`,
});

const defaultArgs = {
  enabledNamespaces: mockEnabledSpaces,
  cols: mockCols,
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const NoData = Template.bind({});
NoData.args = {
  ...defaultArgs,
  enabledNamespaces: [],
};
