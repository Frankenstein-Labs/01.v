export const mockBranchPatterns = [
  { id: 'pattern_1', source: { pattern: 'main-*' }, target: { pattern: 'target-1' } },
  { id: 'pattern_2', source: { pattern: 'feature-.*' }, target: { pattern: 'target-2' } },
];

export const mockTokens = [
  { id: 1, name: 'project-token-1', full_name: 'project-token-1-full-name' },
  { id: 2, name: 'project-token-2', full_name: 'project-token-2-full-name' },
  { id: 3, name: 'project-token-3', full_name: 'project-token-3-full-name' },
  { id: 4, name: 'project-token-4', full_name: 'project-token-4-full-name' },
];

export const mockAccounts = [
  { id: 1, name: 'project-account-1', username: 'project-account-1-username' },
  { id: 2, name: 'project-account-2', username: 'project-account-2-username' },
  { id: 3, name: 'project-account-3', username: 'project-account-3-username' },
];

export const mockGroups = [
  { name: 'group-1', id: '1' },
  { name: 'group-2', id: '2' },
];

export const mockUsers = [
  { id: 'user-1', username: 'user-1' },
  { id: 'user-2', username: 'user-2' },
];

export const mockRoles = ['maintainer', 'developer'];

export const mockServiceAccounts = [
  { id: 1, name: 'service-account-1', username: 'sa1' },
  { id: 2, name: 'service-account-2', username: 'sa2' },
  { id: 3, name: 'service-account-3', username: 'sa3' },
];

export const mockSelectedAccounts = [
  { id: '1', account: { username: 'project-account-1-username' } },
  { id: '2', account: { username: 'project-account-2-username' } },
];
