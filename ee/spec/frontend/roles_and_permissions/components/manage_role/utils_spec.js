import {
  getCustomPermissionsTreeTemplate,
  getAdminPermissionsTreeTemplate,
  getPermissionsTree,
} from 'ee/roles_and_permissions/components/manage_role/utils';

const CONTINUOUSLY_DELIVERY_PERMISSIONS = [
  { value: 'MANAGE_DEPLOY_TOKENS', name: 'Manage deploy tokens' },
  { value: 'ADMIN_PROTECTED_ENVIRONMENTS', name: 'Manage Protected Environments' },
];

const READ_DEPENDENCY_PERMISSION = {
  value: 'READ_DEPENDENCY',
  name: 'View dependency list',
};
const ADMIN_VULNERABILITY_PERMISSION = {
  value: 'ADMIN_VULNERABILITY',
  name: 'Manage vulnerabilities',
};
const READ_VULNERABILITY_PERMISSION = {
  value: 'READ_VULNERABILITY',
  name: 'View vulnerability reports and dashboards',
};
const VULNERABILITY_MANAGEMENT_PERMISSIONS = [
  READ_DEPENDENCY_PERMISSION,
  ADMIN_VULNERABILITY_PERMISSION,
  READ_VULNERABILITY_PERMISSION,
];

const ADMIN_PERMISSIONS = [
  { value: 'READ_ADMIN_CICD', name: 'Read CI/CD' },
  { value: 'READ_ADMIN_GROUPS', name: 'Read Groups' },
  { value: 'READ_ADMIN_PROJECTS', name: 'Read Projects' },
  { value: 'READ_ADMIN_SUBSCRIPTION', name: 'Read subscription details' },
  { value: 'READ_ADMIN_MONITORING', name: 'Read system monitoring' },
  { value: 'READ_ADMIN_USERS', name: 'View users' },
];
const UNRECOGNIZED_PERMISSIONS = [
  {
    value: 'OTHER_PERMISSION',
    name: 'Other permission',
  },
];

describe('getPermissionsTree function', () => {
  describe('for custom permissions', () => {
    it('returns custom permissions tree', () => {
      const template = getCustomPermissionsTreeTemplate();
      const tree = getPermissionsTree(template, [
        ...CONTINUOUSLY_DELIVERY_PERMISSIONS,
        ...VULNERABILITY_MANAGEMENT_PERMISSIONS,
      ]);

      expect(tree).toEqual([
        { name: 'Continuous delivery', permissions: CONTINUOUSLY_DELIVERY_PERMISSIONS },
        {
          name: 'Vulnerability management',
          permissions: [
            READ_DEPENDENCY_PERMISSION,
            { ...ADMIN_VULNERABILITY_PERMISSION, children: [READ_VULNERABILITY_PERMISSION] },
          ],
        },
      ]);
    });

    it('returns custom permissions tree with other permissions', () => {
      const template = getCustomPermissionsTreeTemplate();
      const tree = getPermissionsTree(template, [
        ...CONTINUOUSLY_DELIVERY_PERMISSIONS,
        ...UNRECOGNIZED_PERMISSIONS,
      ]);

      expect(tree).toEqual([
        { name: 'Continuous delivery', permissions: CONTINUOUSLY_DELIVERY_PERMISSIONS },
        { name: 'Other', permissions: UNRECOGNIZED_PERMISSIONS },
      ]);
    });
  });

  describe('for admin permissions', () => {
    it('returns admin permissions tree', () => {
      const template = getAdminPermissionsTreeTemplate();
      const tree = getPermissionsTree(template, ADMIN_PERMISSIONS);

      expect(tree).toEqual([{ name: 'Admin', permissions: ADMIN_PERMISSIONS }]);
    });

    it('returns admin permissions tree with other permissions', () => {
      const template = getAdminPermissionsTreeTemplate();
      const tree = getPermissionsTree(template, [
        ...ADMIN_PERMISSIONS,
        ...UNRECOGNIZED_PERMISSIONS,
      ]);

      expect(tree).toEqual([
        { name: 'Admin', permissions: ADMIN_PERMISSIONS },
        { name: 'Other', permissions: UNRECOGNIZED_PERMISSIONS },
      ]);
    });
  });
});
