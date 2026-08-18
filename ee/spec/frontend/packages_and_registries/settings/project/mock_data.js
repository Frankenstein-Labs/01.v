export const dependencyProxyPackagesSettingsData = {
  __typename: 'DependencyProxyPackagesSetting',
  enabled: true,
  mavenExternalRegistryUrl: 'https://test.dev',
  mavenExternalRegistryUsername: 'user1',
};

export const dependencyProxyPackagesSettingsPayload = (override) => ({
  data: {
    project: {
      id: '1',
      dependencyProxyPackagesSetting: {
        ...dependencyProxyPackagesSettingsData,
        ...override,
      },
    },
  },
});

export const dependencyProxyPackagesSettingMutationMock = (override) => ({
  data: {
    updateDependencyProxyPackagesSettings: {
      dependencyProxyPackagesSetting: {
        ...dependencyProxyPackagesSettingsData,
      },
      errors: [],
      ...override,
    },
  },
});

export const mutationErrorMock = {
  errors: [
    {
      message: 'Some error',
      locations: [{ line: 1, column: 41 }],
      extensions: {
        value: {
          enabled: 'gitlab-org',
        },
        problems: [
          {
            path: ['enabled'],
            explanation: 'explanation',
            message: 'message',
          },
        ],
      },
    },
  ],
};
