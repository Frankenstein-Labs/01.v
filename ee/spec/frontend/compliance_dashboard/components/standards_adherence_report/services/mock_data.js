export const createMockGroupComplianceRequirementsStatusesData = () => ({
  data: {
    container: {
      id: 'gid://gitlab/Group/123',
      complianceRequirementStatuses: {
        nodes: [
          {
            id: 'gid://gitlab/ProjectComplianceRequirementStatus/1',
            pendingCount: 3,
            passCount: 12,
            failCount: 2,
            updatedAt: '2023-10-15T14:30:45Z',
            complianceFramework: {
              id: 'gid://gitlab/ComplianceFramework/1',
              name: 'GDPR',
              default: true,
              color: '#428BCA',
            },
            complianceRequirement: {
              id: 'gid://gitlab/ComplianceRequirement/1',
              name: 'Data Protection Impact Assessment',
              description:
                'Conduct an assessment of data protection risks for high-risk processing activities',
              complianceRequirementsControls: {
                nodes: [
                  { id: 'gid://gitlab/ComplianceRequirementsControl/101' },
                  { id: 'gid://gitlab/ComplianceRequirementsControl/102' },
                ],
              },
            },
            project: {
              id: 'gid://gitlab/Project/201',
              name: 'Customer Portal',
              webUrl: 'https://gitlab.example.com/groups/example-group/customer-portal',
              complianceControlStatus: {
                nodes: [
                  {
                    id: 'gid://gitlab/ComplianceControlStatus/301',
                    status: 'PASSED',
                    complianceRequirementsControl: {
                      id: 'gid://gitlab/ComplianceRequirementsControl/101',
                      name: 'Documentation Control',
                      controlType: 'PROCESS',
                      externalUrl: 'https://example.com/compliance/docs',
                      externalControlName: '',
                      pingEnabled: true,
                    },
                  },
                  {
                    id: 'gid://gitlab/ComplianceControlStatus/302',
                    status: 'FAILED',
                    complianceRequirementsControl: {
                      id: 'gid://gitlab/ComplianceRequirementsControl/102',
                      name: 'Security Review',
                      controlType: 'TECHNICAL',
                      externalUrl: 'https://example.com/compliance/security',
                      externalControlName: '',
                      pingEnabled: true,
                    },
                  },
                ],
              },
            },
          },
          {
            id: 'gid://gitlab/ProjectComplianceRequirementStatus/2',
            pendingCount: 1,
            passCount: 8,
            failCount: 0,
            updatedAt: '2023-10-14T09:15:22Z',
            complianceFramework: {
              id: 'gid://gitlab/ComplianceFramework/2',
              name: 'SOC 2',
              default: false,
              color: '#6B4FBB',
            },
            complianceRequirement: {
              id: 'gid://gitlab/ComplianceRequirement/2',
              name: 'Access Control',
              description: 'Implement appropriate access controls for sensitive data',
              complianceRequirementsControls: {
                nodes: [{ id: 'gid://gitlab/ComplianceRequirementsControl/103' }],
              },
            },
            project: {
              id: 'gid://gitlab/Project/202',
              name: 'Financial System',
              webUrl: 'https://gitlab.example.com/groups/example-group/financial-system',
              complianceControlStatus: {
                nodes: [
                  {
                    id: 'gid://gitlab/ComplianceControlStatus/303',
                    status: 'PENDING',
                    complianceRequirementsControl: {
                      id: 'gid://gitlab/ComplianceRequirementsControl/103',
                      name: 'Two-Factor Authentication',
                      controlType: 'TECHNICAL',
                      externalUrl: 'https://example.com/compliance/2fa',
                      externalControlName: '',
                      pingEnabled: true,
                    },
                  },
                ],
              },
            },
          },
          {
            id: 'gid://gitlab/ProjectComplianceRequirementStatus/3',
            pendingCount: 5,
            passCount: 15,
            failCount: 3,
            updatedAt: '2023-10-13T11:45:30Z',
            complianceFramework: {
              id: 'gid://gitlab/ComplianceFramework/3',
              name: 'HIPAA',
              default: false,
              color: '#FC6D26',
            },
            complianceRequirement: {
              id: 'gid://gitlab/ComplianceRequirement/3',
              name: 'Patient Data Encryption',
              description:
                'Ensure all patient health information is encrypted in transit and at rest',
              complianceRequirementsControls: {
                nodes: [
                  { id: 'gid://gitlab/ComplianceRequirementsControl/104' },
                  { id: 'gid://gitlab/ComplianceRequirementsControl/105' },
                ],
              },
            },
            project: {
              id: 'gid://gitlab/Project/203',
              name: 'Healthcare App',
              webUrl: 'https://gitlab.example.com/groups/example-group/healthcare-app',
              complianceControlStatus: {
                nodes: [
                  {
                    id: 'gid://gitlab/ComplianceControlStatus/304',
                    status: 'PASSED',
                    complianceRequirementsControl: {
                      id: 'gid://gitlab/ComplianceRequirementsControl/104',
                      name: 'Data Encryption',
                      controlType: 'TECHNICAL',
                      externalUrl: 'https://example.com/compliance/encryption',
                      externalControlName: '',
                      pingEnabled: true,
                    },
                  },
                  {
                    id: 'gid://gitlab/ComplianceControlStatus/305',
                    status: 'FAILED',
                    complianceRequirementsControl: {
                      id: 'gid://gitlab/ComplianceRequirementsControl/105',
                      name: 'Audit Trail',
                      controlType: 'PROCESS',
                      externalUrl: 'https://example.com/compliance/audit',
                      externalControlName: '',
                      pingEnabled: true,
                    },
                  },
                ],
              },
            },
          },
        ],
        pageInfo: {
          startCursor: 'eyJpZCI6IjEifQ==',
          endCursor: 'eyJpZCI6IjMifQ==',
          hasNextPage: false,
          hasPreviousPage: true,
        },
      },
    },
  },
});
