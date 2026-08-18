/* eslint-disable no-new */
import 'vendor/bootstrap/js/src/collapse';
import ProtectedBranchEditList from 'ee/protected_branches/protected_branch_edit_list';
import initDatePicker from '~/behaviors/date_picker';
import initDeployKeys from '~/deploy_keys';
import fileUpload from '~/lib/utils/file_upload';
import { initWebBasedCommitSigningProjectSettings } from 'ee/projects/settings/init_web_based_commit_signing_settings';
import ProtectedBranchCreate from '~/protected_branches/protected_branch_create';
import CEProtectedBranchEditList from '~/protected_branches/protected_branch_edit_list';
import ProtectedTagCreate from '~/protected_tags/protected_tag_create';
import ProtectedTagEditList from '~/protected_tags/protected_tag_edit_list';
import initSearchSettings from '~/search_settings';
import initSettingsPanels from '~/settings_panels';
import UserCallout from '~/user_callout';
import mountBranchRulesListing from '~/projects/settings/repository/branch_rules/mount_branch_rules_listing';
import mountDefaultBranchSelector from '~/projects/settings/mount_default_branch_selector';
import mountMirrorTable from '~/mirrors/mount_mirror_table';
import mountRepositoryMaintenance from '~/projects/settings/repository/maintenance/mount_repository_maintenance';
import EEMirrorRepos from './ee_mirror_repos';

new UserCallout();

initDeployKeys();
initSettingsPanels();

const PROTECTED_BRANCHES_SELECTOR = '#js-protected-branches-settings';
const PROTECTED_TAGS_SELECTOR = '#js-protected-tags-settings';
const protectedBranchesConfig = { hasLicense: true, sectionSelector: PROTECTED_BRANCHES_SELECTOR };
const protectedTagsConfig = { hasLicense: true, sectionSelector: PROTECTED_TAGS_SELECTOR };

if (document.querySelector('.js-protected-refs-for-users')) {
  new ProtectedBranchCreate(protectedBranchesConfig);
  new ProtectedBranchEditList(PROTECTED_BRANCHES_SELECTOR);

  new ProtectedTagCreate(protectedTagsConfig);
  new ProtectedTagEditList(protectedTagsConfig);
} else {
  new ProtectedBranchCreate({ ...protectedBranchesConfig, hasLicense: false });
  new CEProtectedBranchEditList(PROTECTED_BRANCHES_SELECTOR);
  new ProtectedTagCreate({ ...protectedTagsConfig, hasLicense: false });
  new ProtectedTagEditList({ ...protectedTagsConfig, hasLicense: false });
}

const pushPullContainer = document.querySelector('.js-mirror-settings');
if (pushPullContainer) new EEMirrorRepos(pushPullContainer).init();

mountMirrorTable();

initDatePicker(); // Used for deploy token "expires at" field

fileUpload('.js-choose-file', '.js-object-map-input');

initSearchSettings();
initWebBasedCommitSigningProjectSettings();
mountBranchRulesListing(document.getElementById('js-branch-rules-listing'));
mountDefaultBranchSelector(document.querySelector('.js-select-default-branch'));
mountRepositoryMaintenance();
