import { nextTick } from 'vue';
import waitForPromises from 'helpers/wait_for_promises';

export const groups = [
  {
    __typename: 'Group',
    id: 'gid://gitlab/Group/98',
    name: 'gitlab-policies-sub',
    fullPath: 'gitlab-policies/gitlab-policies-sub',
  },
  {
    __typename: 'Group',
    id: 'gid://gitlab/Group/99',
    name: 'gitlab-policies-sub-2',
    fullPath: 'gitlab-policies/gitlab-policies-sub-2',
  },
];

export const projects = [
  {
    __typename: 'Project',
    fullPath: 'gitlab-policies/test',
    id: 'gid://gitlab/Project/37',
    name: 'test',
  },
];

export const complianceFrameworks = [
  {
    color: '#ed9121',
    description: 'test-0.0.1',
    editPath: 'path/to/framework/edit',
    id: 'gid://gitlab/ComplianceManagement::Framework/5',
    name: 'test-0.0.1',
    projects: [],
    __typename: 'ComplianceFramework',
  },
  {
    color: '#ed9121',
    description: 'test-0.0.2',
    editPath: 'path/to/framework/edit',
    id: 'gid://gitlab/ComplianceManagement::Framework/6',
    name: 'test-0.0.2',
    projects: [],
    __typename: 'ComplianceFramework',
  },
];

export const normalizeText = (text) => text.replaceAll(/\r?\n|\r/g, '').replaceAll(' ', '');

export const generateMockResponse = (basis, newPayload) => ({
  ...basis,
  policyScope: {
    ...basis.policyScope,
    ...newPayload,
  },
});

export const openDrawer = async (element, rows) => {
  element.vm.$emit('row-selected', rows);
  await nextTick();
  await waitForPromises();
};
