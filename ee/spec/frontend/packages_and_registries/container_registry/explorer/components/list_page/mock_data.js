export const graphQLProjectContainerScanningForRegistryOnMock = {
  data: {
    project: {
      id: '1',
      containerScanningForRegistry: {
        isEnabled: true,
        isVisible: true,
        __typename: 'LocalContainerScanningForRegistry',
      },
      vulnerabilitySeveritiesCount: {
        critical: 3,
        high: 12,
        info: 5,
        low: 9,
        medium: 1,
        unknown: 20,
        __typename: 'VulnerabilitySeveritiesCount',
      },
      __typename: 'Project',
    },
  },
};

export const graphQLProjectContainerScanningForRegistryOnMockCapped = {
  data: {
    project: {
      id: '1',
      containerScanningForRegistry: {
        isEnabled: true,
        isVisible: true,
        __typename: 'LocalContainerScanningForRegistry',
      },
      vulnerabilitySeveritiesCount: {
        critical: 2000,
        high: 20,
        info: 2000,
        low: 2000,
        medium: 2000,
        unknown: 2000,
        __typename: 'VulnerabilitySeveritiesCount',
      },
      __typename: 'Project',
    },
  },
};

export const graphQLProjectContainerScanningForRegistryOffMock = {
  data: {
    project: {
      id: '1',
      containerScanningForRegistry: {
        isEnabled: false,
        isVisible: true,
        __typename: 'LocalContainerScanningForRegistry',
      },
      vulnerabilitySeveritiesCount: {
        critical: 0,
        high: 0,
        info: 0,
        low: 0,
        medium: 0,
        unknown: 0,
        __typename: 'VulnerabilitySeveritiesCount',
      },
      __typename: 'Project',
    },
  },
};

export const graphQLProjectContainerScanningForRegistryHiddenMock = {
  data: {
    project: {
      id: '1',
      containerScanningForRegistry: {
        isEnabled: false,
        isVisible: false,
        __typename: 'LocalContainerScanningForRegistry',
      },
      vulnerabilitySeveritiesCount: {
        critical: 0,
        high: 0,
        info: 0,
        low: 0,
        medium: 0,
        unknown: 0,
        __typename: 'VulnerabilitySeveritiesCount',
      },
      __typename: 'Project',
    },
  },
};
