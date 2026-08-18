import { s__ } from '~/locale';
import { mapToListboxItems } from 'ee/security_orchestration/utils';

export const PROJECTS_WITH_FRAMEWORK = 'projects_with_framework';
export const ALL_PROJECTS_IN_GROUP = 'all_projects_in_group';
export const SPECIFIC_PROJECTS = 'specific_projects';
export const ALL_PROJECTS_IN_LINKED_GROUPS = 'all_projects_in_linked_groups';
export const SECURITY_CATEGORIES = 'security_categories';

export const PROJECT_SCOPE_TYPE_TEXTS = {
  [PROJECTS_WITH_FRAMEWORK]: s__('SecurityOrchestration|projects with compliance frameworks'),
  [ALL_PROJECTS_IN_GROUP]: s__('SecurityOrchestration|all projects in this group'),
  [SPECIFIC_PROJECTS]: s__('SecurityOrchestration|specific projects'),
  [ALL_PROJECTS_IN_LINKED_GROUPS]: s__('SecurityOrchestration|all projects in the linked groups'),
  [SECURITY_CATEGORIES]: s__('SecurityOrchestration|security attributes'),
};

const CSP_SCOPE_TYPE_TEXTS_WITHOUT_GROUP = {
  [PROJECTS_WITH_FRAMEWORK]: s__('SecurityOrchestration|projects with compliance frameworks'),
  [ALL_PROJECTS_IN_GROUP]: s__('SecurityOrchestration|all projects in this instance'),
  [SPECIFIC_PROJECTS]: s__('SecurityOrchestration|specific projects'),
  [SECURITY_CATEGORIES]: s__('SecurityOrchestration|security attributes'),
};

export const CSP_SCOPE_TYPE_TEXTS = {
  ...CSP_SCOPE_TYPE_TEXTS_WITHOUT_GROUP,
  [ALL_PROJECTS_IN_LINKED_GROUPS]: s__('SecurityOrchestration|all projects in the groups'),
};

export const PROJECT_SCOPE_TYPE_LISTBOX_ITEMS = mapToListboxItems(PROJECT_SCOPE_TYPE_TEXTS);

export const CSP_SCOPE_TYPE_WITHOUT_GROUP_LISTBOX_ITEMS = mapToListboxItems(
  CSP_SCOPE_TYPE_TEXTS_WITHOUT_GROUP,
);

export const CSP_SCOPE_TYPE_LISTBOX_ITEMS = mapToListboxItems(CSP_SCOPE_TYPE_TEXTS);

export const WITHOUT_EXCEPTIONS = 'without_exceptions';
export const EXCEPT_PROJECTS = 'except_projects';
export const EXCEPT_PERSONAL_PROJECTS = 'except_personal_projects';
export const EXCEPT_GROUPS = 'except_groups';
export const INCLUDING = 'including';
export const EXCLUDING = 'excluding';
export const COMPLIANCE_FRAMEWORKS_KEY = 'compliance_frameworks';
export const PROJECTS_KEY = 'projects';
export const GROUPS_KEY = 'groups';
export const RESERVED_SCOPE_KEYS = [PROJECTS_KEY, GROUPS_KEY, COMPLIANCE_FRAMEWORKS_KEY];

export const SUPPORTED_SECURITY_CATEGORY_KEYS = [
  'business_impact',
  'application',
  'business_unit',
  'exposure',
];

export const EXCEPTION_TYPE_TEXTS = {
  [WITHOUT_EXCEPTIONS]: s__('SecurityOrchestration|without project exceptions'),
  [EXCEPT_PROJECTS]: s__('SecurityOrchestration|except projects'),
};

const EXCEPTION_WITH_PERSONAL_TYPE_TEXTS = {
  ...EXCEPTION_TYPE_TEXTS,
  [EXCEPT_PERSONAL_PROJECTS]: s__('SecurityOrchestration|except personal projects'),
};

export const GROUP_EXCEPTION_TYPE_TEXTS = {
  [WITHOUT_EXCEPTIONS]: s__('SecurityOrchestration|without group exceptions'),
  [EXCEPT_GROUPS]: s__('SecurityOrchestration|except groups'),
};

export const EXCEPTION_TYPE_LISTBOX_ITEMS = mapToListboxItems(EXCEPTION_TYPE_TEXTS);
export const EXCEPTION_WITH_PERSONAL_TYPE_LISTBOX_ITEMS = mapToListboxItems(
  EXCEPTION_WITH_PERSONAL_TYPE_TEXTS,
);
export const GROUP_EXCEPTION_TYPE_LISTBOX_ITEMS = mapToListboxItems(GROUP_EXCEPTION_TYPE_TEXTS);

export const PROJECT_EXCEPTION_TYPE_PAYLOADS = {
  [WITHOUT_EXCEPTIONS]: { projects: { [EXCLUDING]: [] } },
  [EXCEPT_PROJECTS]: { projects: { [EXCLUDING]: [] } },
  [EXCEPT_PERSONAL_PROJECTS]: { projects: { [EXCLUDING]: [{ type: 'personal' }] } },
};

export const GROUP_EXCEPTION_TYPE_PAYLOADS = {
  [WITHOUT_EXCEPTIONS]: { groups: { [EXCLUDING]: [] } },
};
