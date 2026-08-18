export const mockComplianceFrameworks = {
  project: {
    id: '1',
    complianceFrameworks: {
      nodes: [
        {
          id: 'gid://gitlab/ComplianceManagement::Framework/1',
          name: 'Framework 1',
          color: '#009966',
          namespaceId: 'gid://gitlab/Group/1',
          default: false,
          description: 'Framework 1',
        },
        {
          id: 'gid://gitlab/ComplianceManagement::Framework/2',
          name: 'Framework 2',
          color: '#336699',
          namespaceId: 'gid://gitlab/Group/1',
          default: true,
          description: 'Framework 2',
        },
      ],
    },
  },
};
