import '~/pages/projects/settings/merge_requests';
import mountApprovals from 'ee/approvals/project_settings/mount_project_settings';
import { initMergeRequestMergeChecksApp } from 'ee/merge_checks';
import { initMergeOptionSettings } from 'ee/pages/projects/edit/merge_options';
import mountStatusChecks from 'ee/status_checks/mount';
import { initTargetBranchRefSwitcher } from './init_target_branch_ref_switcher';
import { initTitleRegexToggle } from './init_title_regex_toggle';

mountApprovals(document.getElementById('js-mr-approvals-settings'));
mountStatusChecks(document.getElementById('js-status-checks-settings'));

initMergeOptionSettings();
initMergeRequestMergeChecksApp();
initTitleRegexToggle();

requestIdleCallback(() => {
  initTargetBranchRefSwitcher();
});
