import { flatMap, keyBy } from 'lodash-es';
import { s__, __ } from '~/locale';

// This declares the order that custom permissions should be shown in. When a new custom permission
// is added to backend, its value should also be added to this tree, or else the permission will
// show in a catch-all Other category.
export const getCustomPermissionsTreeTemplate = () => [
  {
    name: s__('MemberRole|Code review workflow'),
    permissions: [{ value: 'MANAGE_MERGE_REQUEST_SETTINGS' }],
  },
  {
    name: s__('MemberRole|Compliance management'),
    permissions: [
      { value: 'ADMIN_COMPLIANCE_FRAMEWORK', children: [{ value: 'READ_COMPLIANCE_DASHBOARD' }] },
    ],
  },
  {
    name: s__('MemberRole|Continuous delivery'),
    permissions: [{ value: 'MANAGE_DEPLOY_TOKENS' }, { value: 'ADMIN_PROTECTED_ENVIRONMENTS' }],
  },
  {
    name: s__('MemberRole|Duo Agent Platform'),
    permissions: [{ value: 'ADMIN_AI_CATALOG_ITEM' }, { value: 'ADMIN_AI_CATALOG_ITEM_CONSUMER' }],
  },
  {
    name: __('Groups and projects'),
    permissions: [
      { value: 'ADMIN_GROUP_MEMBER' },
      { value: 'REMOVE_GROUP' },
      { value: 'ARCHIVE_PROJECT' },
      { value: 'REMOVE_PROJECT' },
    ],
  },
  {
    name: s__('MemberRole|Infrastructure as code'),
    permissions: [{ value: 'ADMIN_TERRAFORM_STATE' }],
  },
  {
    name: __('Integrations'),
    permissions: [{ value: 'ADMIN_INTEGRATIONS' }],
  },
  {
    name: __('Runner'),
    permissions: [{ value: 'ADMIN_RUNNERS', children: [{ value: 'READ_RUNNERS' }] }],
  },
  {
    name: s__('MemberRole|Secrets management'),
    permissions: [{ value: 'ADMIN_CICD_VARIABLES' }],
  },
  {
    name: s__('MemberRole|Security asset inventories'),
    permissions: [
      { value: 'ADMIN_SECURITY_ATTRIBUTES', children: [{ value: 'READ_SECURITY_ATTRIBUTE' }] },
    ],
  },
  {
    name: s__('MemberRole|Security policy management'),
    permissions: [{ value: 'MANAGE_SECURITY_POLICY_LINK' }],
  },
  {
    name: s__('MemberRole|Source code management'),
    permissions: [
      { value: 'READ_CODE' },
      { value: 'ADMIN_MERGE_REQUEST' },
      { value: 'ADMIN_PROTECTED_BRANCH' },
      { value: 'ADMIN_PUSH_RULES' },
    ],
  },
  {
    name: s__('MemberRole|System access'),
    permissions: [
      { value: 'MANAGE_GROUP_ACCESS_TOKENS' },
      { value: 'MANAGE_PROJECT_ACCESS_TOKENS' },
    ],
  },
  {
    name: s__('MemberRole|Team planning'),
    permissions: [{ value: 'READ_CRM_CONTACT' }],
  },
  {
    name: __('Vulnerability management'),
    permissions: [
      { value: 'READ_DEPENDENCY' },
      { value: 'ADMIN_VULNERABILITY', children: [{ value: 'READ_VULNERABILITY' }] },
    ],
  },
  {
    name: __('Webhooks'),
    permissions: [{ value: 'ADMIN_WEB_HOOK' }],
  },
];

export const getAdminPermissionsTreeTemplate = () => [
  {
    name: s__('Navigation|Admin'),
    permissions: [
      { value: 'READ_ADMIN_CICD' },
      { value: 'READ_ADMIN_GROUPS' },
      { value: 'READ_ADMIN_PROJECTS' },
      { value: 'READ_ADMIN_SUBSCRIPTION' },
      { value: 'READ_ADMIN_MONITORING' },
      { value: 'READ_ADMIN_USERS' },
    ],
  },
];

// Gather all the permissions in the tree into a single array.
const traversePermissions = (permissions) =>
  flatMap(permissions, (p) => [p, ...traversePermissions(p.children)]);

// For the permissions tree, get an object where the key is the permission value (e.g. 'READ_CODE')
// and the value is the permission object (e.g. { value: 'READ_CODE' }). This is used to get the
// permission object given its key.
const getPermissionsLookup = (categories) => {
  const permissions = flatMap(categories, (category) => traversePermissions(category.permissions));

  return keyBy(permissions, (p) => p.value);
};

// Project the permissions onto the template and return the permissions tree.
export const getPermissionsTree = (template, permissions) => {
  const lookup = getPermissionsLookup(template);
  const unknownPermissions = [];
  // permissions is a list of permission values (e.g. ['READ_CODE', 'ADMIN_RUNNERS']), and the tree
  // contains permission placeholder objects that only have a value property. Using the lookup
  // object, check if there's a corresponding permission for the value. If there is, copy over all
  // the properties from the permission into the placeholder. Otherwise, it's an unknown permission
  // that will be added to an Other category later on.
  permissions.forEach((permission) => {
    const placeholder = lookup[permission.value];
    if (placeholder) {
      Object.assign(placeholder, permission);
    } else {
      unknownPermissions.push(permission);
    }
  });
  // Add the Other category for permissions not in the permission tree.
  if (unknownPermissions.length) {
    template.push({ name: __('Other'), permissions: unknownPermissions });
  }
  // Remove categories where all the permissions are only placeholders.
  return template.filter((category) => category.permissions.some((permission) => permission.name));
};
