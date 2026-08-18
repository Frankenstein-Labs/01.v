import createMockApollo from 'helpers/mock_apollo_helper';
import getWebBasedCommitSigningQuery from 'ee/graphql_shared/queries/web_based_commit_signing.query.graphql';
import { groupQueryResponse } from 'ee_jest/vue_shared/components/web_based_commit_signing/mock_data';
import WebBasedCommitSigningCheckbox from './checkbox.vue';

export default {
  component: WebBasedCommitSigningCheckbox,
  title: 'vue_shared/web_based_commit_signing/checkbox',
  argTypes: {
    hasGroupPermissions: {
      control: 'boolean',
      description: 'Whether user has permissions to enable web based commit signing',
    },
    groupSettingsRepositoryPath: {
      control: 'text',
      description: 'Path to the group repository settings page',
    },
    isGroupLevel: {
      control: 'boolean',
      description: 'Whether this is a group-level setting',
    },
    fullPath: {
      control: 'text',
      description: 'Full path of the group or project',
    },
  },
};

const requestHandlers = [
  [getWebBasedCommitSigningQuery, () => Promise.resolve(groupQueryResponse(true))],
];

const apolloProvider = createMockApollo(requestHandlers);

const Template = (args, { argTypes }) => ({
  components: { WebBasedCommitSigningCheckbox },
  props: Object.keys(argTypes),
  apolloProvider,
  template: `
    <web-based-commit-signing-checkbox v-bind="$props" />
  `,
});

export const Editable = Template.bind({});
Editable.args = {
  hasGroupPermissions: true,
  groupSettingsRepositoryPath: '/groups/my-group/-/settings/repository',
  isGroupLevel: true,
  fullPath: 'my-group',
};

export const Inherited = Template.bind({});
Inherited.args = {
  hasGroupPermissions: true,
  groupSettingsRepositoryPath: '/groups/my-group/-/settings/repository',
  isGroupLevel: false,
  fullPath: 'my-group/my-project',
};
