export const usageDataInstanceAggregated = [
  {
    billingMonth: 'February 2025',
    billingMonthIso8601: '2025-02-01',
    computeMinutesUsage: 300.25,
    durationMinutes: 300.25,
    rootNamespace: null,
    __typename: 'CiDedicatedHostedRunnerUsage',
  },
  {
    billingMonth: 'January 2025',
    billingMonthIso8601: '2025-01-01',
    computeMinutesUsage: 200.75,
    durationMinutes: 200.75,
    rootNamespace: null,
    __typename: 'CiDedicatedHostedRunnerUsage',
  },
];

export const usageDataNamespaceAggregated = [
  {
    billingMonth: 'January 2025',
    billingMonthIso8601: '2025-01-01',
    computeMinutesUsage: 200.33,
    durationMinutes: 200.33,
    rootNamespace: {
      id: 'gid://gitlab/Namespaces::UserNamespace/1',
      name: 'Administrator',
      avatarUrl:
        'https://secure.gravatar.com/avatar/258d8dc916db8cea2cafb6c3cd0cb0246efe061421dbd83ec3a350428cabda4f?s=80&d=identicon',
      __typename: 'Namespace',
    },
  },
  {
    billingMonth: 'February 2025',
    billingMonthIso8601: '2025-02-01',
    computeMinutesUsage: 100.67,
    durationMinutes: 100.67,
    rootNamespace: {
      id: 'gid://gitlab/Group/33',
      name: 'Flightjs',
      avatarUrl:
        'https://secure.gravatar.com/avatar/258d8dc916db8cea2cafb6c3cd0cb0246efe061421dbd83ec3a350428cabda4f?s=80&d=identicon',
      __typename: 'Namespace',
    },
  },
  {
    billingMonth: 'March 2025',
    billingMonthIso8601: '2025-03-01',
    computeMinutesUsage: 100.25,
    durationMinutes: 100.25,
    rootNamespace: {
      id: 'gid://gitlab/Group/34',
      name: '',
      avatarUrl:
        'https://secure.gravatar.com/avatar/258d8dc916db8cea2cafb6c3cd0cb0246efe061421dbd83ec3a350428cabda4f?s=80&d=identicon',
      __typename: 'Namespace',
    },
  },
];

export const mockInstanceAggregatedUsage = {
  data: {
    ciDedicatedHostedRunnerUsage: {
      nodes: usageDataInstanceAggregated,
    },
  },
};

export const mockInstanceNamespaceUsage = {
  data: {
    ciDedicatedHostedRunnerUsage: {
      nodes: usageDataNamespaceAggregated,
    },
  },
};

export const mockRunnerFilters = {
  data: {
    ciDedicatedHostedRunnerFilters: {
      runners: {
        nodes: [
          {
            id: 'gid://gitlab/Ci::Runner/55',
            runnerType: 'INSTANCE_TYPE',
            description: 'My runner',
            adminUrl: 'https://gdk.test:3443/admin/runners/55',
            status: 'STALE',
          },
          {
            id: 'gid://gitlab/Ci::Runner/60',
            runnerType: 'INSTANCE_TYPE',
            description: 'My other runner',
            adminUrl: 'https://gdk.test:3443/admin/runners/60',
            status: 'ONLINE',
          },
        ],
      },
      deletedRunners: {
        nodes: [
          {
            id: 'gid://gitlab/Ci::Runner/70',
          },
          {
            id: 'gid://gitlab/Ci::Runner/71',
          },
        ],
      },
      years: [2025, 2024, 2023, 2022],
    },
  },
};
