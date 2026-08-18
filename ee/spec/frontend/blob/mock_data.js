export const propsMock = {
  currentRef: 'current-ref',
  projectPath: 'my-namespace/my-project',
  filePath: 'CODEOWNERS',
};

export const validateCodeownerFile = {
  total: 10,
  validationErrors: [
    {
      code: 'invalid_entry_owner_format',
      lines: [2, 4],
      __typename: 'RepositoryCodeownerError',
    },
    {
      code: 'missing_entry_owner',
      lines: [5, 6],
      __typename: 'RepositoryCodeownerError',
    },
    {
      code: 'malformed_entry_owner',
      lines: [9],
      __typename: 'RepositoryCodeownerError',
    },
    {
      code: 'invalid_section_format',
      lines: [36],
      __typename: 'RepositoryCodeownerError',
    },
    {
      code: 'invalid_section_owner_format',
      lines: [43],
      __typename: 'RepositoryCodeownerError',
    },
    {
      code: 'inaccessible_owner',
      lines: [22],
      __typename: 'RepositoryCodeownerError',
    },
    {
      code: 'unqualified_group',
      lines: [12],
      __typename: 'RepositoryCodeownerError',
    },
    {
      code: 'group_without_eligible_approvers',
      lines: [19],
      __typename: 'RepositoryCodeownerError',
    },
  ],
  __typename: 'RepositoryCodeownerValidation',
};

export const valdateCodeownerFileNoErrors = {
  total: 0,
  validationErrors: [],
  __typename: 'RepositoryCodeownerValidation',
};
