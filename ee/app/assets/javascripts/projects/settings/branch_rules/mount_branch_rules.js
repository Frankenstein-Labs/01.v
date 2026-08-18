import { getParameterByName } from '~/lib/utils/url_utility';
import { parseBoolean } from '~/lib/utils/common_utils';
import createStore from 'ee/approvals/stores';
import { mergeRequestApprovalSettingsMappers } from 'ee/approvals/mappers';
import approvalSettingsModule from 'ee/approvals/stores/modules/approval_settings';
import projectSettingsModule from 'ee/approvals/stores/modules/project_settings';
import mount from '~/projects/settings/branch_rules/mount_branch_rules';

export default function mountBranchRules(el) {
  if (!el) return;

  const modules = {
    approvals: projectSettingsModule(),
    approvalSettings: approvalSettingsModule(mergeRequestApprovalSettingsMappers),
  };

  const store = createStore(modules, {
    ...el.dataset,
    prefix: 'project-settings',
    allowAllProtectedBranchesOption: true,
    allowMultiRule: parseBoolean(el.dataset.allowMultiRule),
    canEdit: parseBoolean(el.dataset.canEdit),
    targetBranch: getParameterByName('branch'),
  });

  mount(el, store, gon.licensed_features?.branchRuleSquashOptions);
}
