export const mockEnterpriseUser1 = {
  username: 'Administrator',
  web_url: '/root',
  web_path: '/root',
  avatar_url: '/avatar1',
  id: 1,
  name: 'Admin',
};

export const mockEnterpriseUser2 = {
  username: 'Rookie',
  web_url: '/rookie',
  web_path: '/rookie',
  avatar_url: '/avatar2',
  id: 2,
  name: 'Rookie',
};

export const mockEnterpriseUsersQueryResponse = ({
  enterpriseUser = mockEnterpriseUser1,
} = {}) => ({
  data: [enterpriseUser],
  headers: { 'X-Next-Page': null },
});

export const mockEnterpriseUsersWithPaginationQueryResponse = {
  data: [mockEnterpriseUser2],
  headers: { 'X-Next-Page': 2 },
};
