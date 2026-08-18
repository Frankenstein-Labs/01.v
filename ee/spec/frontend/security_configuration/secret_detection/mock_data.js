export const projectSecurityExclusions = [
  {
    id: 'gid://gitlab/Security::ProjectSecurityExclusion/1',
    scanner: 'SECRET_PUSH_PROTECTION',
    type: 'PATH',
    active: true,
    description: 'test1',
    value: 'tmp',
    createdAt: '2024-09-19T14:15:21Z',
    updatedAt: '2024-09-19T14:15:21Z',
    __typename: 'ProjectSecurityExclusion',
  },
  {
    id: 'gid://gitlab/Security::ProjectSecurityExclusion/29',
    scanner: 'SECRET_PUSH_PROTECTION',
    type: 'RAW_VALUE',
    active: true,
    description: 'test secret',
    value: 'glpat-1234567890abcdefg',
    createdAt: '2024-09-19T14:15:21Z',
    updatedAt: '2024-09-19T14:15:21Z',
    __typename: 'ProjectSecurityExclusion',
  },
];
