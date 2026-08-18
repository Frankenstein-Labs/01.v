import { mutationErrorMock } from 'jest/packages_and_registries/settings/group/mock_data';

export { mutationErrorMock };

export const virtualRegistriesSetting = (extend) => ({
  enabled: true,
  ...extend,
});

export const groupVirtualRegistriesSettingMock = {
  data: {
    group: {
      id: '1',
      fullPath: 'foo_group_path',
      virtualRegistriesSetting: virtualRegistriesSetting(),
      __typename: 'Group',
    },
  },
};

export const virtualRegistriesSettingMutationMock = (override) => ({
  data: {
    updateVirtualRegistriesSetting: {
      __typename: 'UpdateVirtualRegistriesSettingPayload',
      virtualRegistriesSetting: {
        __typename: 'VirtualRegistriesSetting',
        ...virtualRegistriesSetting(),
      },
      errors: [],
      ...override,
    },
  },
});

export const virtualRegistriesCleanupPolicyMock = (options) => ({
  __typename: 'VirtualRegistriesCleanupPolicy',
  enabled: true,
  status: 'SCHEDULED',
  cadence: 7,
  createdAt: '2025-11-01T10:00:00Z',
  keepNDaysAfterDownload: 30,
  lastRunAt: '2025-12-01T10:00:00Z',
  lastRunDeletedSize: 1024,
  lastRunDeletedEntriesCount: 10,
  nextRunAt: '2025-12-15T10:00:00Z',
  notifyOnFailure: true,
  notifyOnSuccess: false,
  failureMessage: null,
  ...options,
});

export const groupVirtualRegistriesCleanupPolicyMock = (cleanupPolicyOverride) => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      fullPath: 'foo_group_path',
      virtualRegistriesCleanupPolicy:
        cleanupPolicyOverride === null
          ? null
          : virtualRegistriesCleanupPolicyMock(cleanupPolicyOverride),
      __typename: 'Group',
    },
  },
});

export const virtualRegistriesCleanupPolicyMutationMock = (override) => ({
  data: {
    virtualRegistriesCleanupPolicyUpsert: {
      __typename: 'VirtualRegistriesCleanupPolicyUpsertPayload',
      virtualRegistriesCleanupPolicy: {
        __typename: 'VirtualRegistryCleanupPolicy',
        ...virtualRegistriesCleanupPolicyMock(),
      },
      errors: [],
      ...override,
    },
  },
});
