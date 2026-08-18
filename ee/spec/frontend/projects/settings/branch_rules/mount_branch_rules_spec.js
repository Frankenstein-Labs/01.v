import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import mountBranchRules from 'ee/projects/settings/branch_rules/mount_branch_rules';
import branchRulesMount from '~/projects/settings/branch_rules/mount_branch_rules';

jest.mock('~/projects/settings/branch_rules/mount_branch_rules');

Vue.use(Vuex);

describe('mountBranchRules', () => {
  it.each`
    licenseStatus | description
    ${true}       | ${'enabled'}
    ${false}      | ${'disabled'}
  `(
    'passes correct license flag to mount function when feature is $description',
    ({ licenseStatus }) => {
      window.gon = { licensed_features: { branchRuleSquashOptions: licenseStatus } };
      const element = document.createElement('div');
      mountBranchRules(element);

      expect(branchRulesMount).toHaveBeenCalledWith(element, expect.anything(), licenseStatus);
    },
  );
});
