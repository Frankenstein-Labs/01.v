import { STATUS_TRIGGERED, STATUS_ACKNOWLEDGED } from '~/sidebar/constants';

export const mockEscalationPolicy1 = {
  __typename: 'EscalationPolicyType',
  id: 'gid://gitlab/IncidentManagement::EscalationPolicy/1',
  title: 'First policy',
};

export const mockEscalationPolicy2 = {
  __typename: 'EscalationPolicyType',
  id: 'gid://gitlab/IncidentManagement::EscalationPolicy/2',
  title: 'Second policy',
};

export const mockEscalationPoliciesResponse = {
  data: {
    namespace: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/1',
      attributes: {
        nodes: [mockEscalationPolicy1, mockEscalationPolicy2],
        __typename: 'EscalationPolicyTypeConnection',
      },
    },
  },
};

export const noParentUpdatedResponse = {
  data: {
    workItem: {
      id: 'gid://gitlab/Issue/1',
      widgets: [{}],
      __typename: 'Project',
    },
  },
};

export const mockCurrentEscalationPolicyResponse = {
  data: {
    namespace: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/1',
      issuable: {
        __typename: 'Issue',
        id: 'gid://gitlab/Issue/1',
        attribute: mockEscalationPolicy1,
        escalationStatus: STATUS_ACKNOWLEDGED,
      },
    },
  },
};

export const mockNullEscalationPolicyResponse = {
  data: {
    namespace: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/1',
      issuable: {
        __typename: 'Issue',
        id: 'gid://gitlab/Issue/1',
        attribute: null,
        escalationStatus: STATUS_TRIGGERED,
      },
    },
  },
};

// -------- Core methods & overrides ---------------------

export const mutationData = {
  issueSetEscalationStatus: {
    __typename: 'IssueSetEscalationStatusPayload',
    errors: [],
    clientMutationId: null,
    issue: {
      __typename: 'Issue',
      id: 'gid://gitlab/Issue/4',
      escalationStatus: STATUS_ACKNOWLEDGED,
      escalationPolicy: null,
    },
  },
};

export { fetchData, fetchError, mutationError } from 'jest/sidebar/components/incidents/mock_data';
