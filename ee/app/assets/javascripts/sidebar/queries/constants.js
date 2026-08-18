import { TYPE_EPIC, TYPE_ISSUE } from '~/issues/constants';
import { issuableAttributesQueries as issuableAttributesQueriesFoss } from '~/sidebar/queries/constants';
import updateStatusMutation from '~/sidebar/queries/update_status.mutation.graphql';
import issuableWeightSubscription from 'ee/graphql_shared/subscriptions/issuable_weight.subscription.graphql';
import { IssuableAttributeType } from '../constants';
import groupEpicsQuery from './group_epics.query.graphql';
import groupIterationsQuery from './group_iterations.query.graphql';
import issueHealthStatusQuery from './issue_health_status.query.graphql';
import issueWeightQuery from './issue_weight.query.graphql';
import projectIssueEpicMutation from './project_issue_epic.mutation.graphql';
import projectIssueEpicQuery from './project_issue_epic.query.graphql';
import projectIssueIterationMutation from './project_issue_iteration.mutation.graphql';
import projectIssueIterationQuery from './project_issue_iteration.query.graphql';
import updateIssueWeightMutation from './update_issue_weight.mutation.graphql';
import issueEscalationPolicyQuery from './issue_escalation_policy.query.graphql';
import issueEscalationPolicyMutation from './issue_escalation_policy.mutation.graphql';
import projectEscalationPoliciesQuery from './project_escalation_policies.query.graphql';
import issuableEpicSubscription from './issuable_epic.subscription.graphql';
import workItemParent from './project_issue_parent.query.graphql';
import workItemParentsQuery from './work_item_parents.query.graphql';
import updateWorkItemParent from './project_issue_update_parent.mutation.graphql';
import workItemParentSubscription from './work_item_parent.subscription.graphql';

export const issuableIterationQueries = {
  [TYPE_ISSUE]: {
    query: projectIssueIterationQuery,
    mutation: projectIssueIterationMutation,
  },
};

export const iterationsQueries = {
  [TYPE_ISSUE]: {
    query: groupIterationsQuery,
  },
};

const issuableEpicQueries = {
  [TYPE_ISSUE]: {
    query: projectIssueEpicQuery,
    mutation: projectIssueEpicMutation,
  },
};

const epicsQueries = {
  [TYPE_ISSUE]: {
    query: groupEpicsQuery,
  },
};

const parentsQueries = {
  [TYPE_ISSUE]: {
    query: workItemParentsQuery,
  },
};

const issuableEscalationPolicyQueries = {
  [TYPE_ISSUE]: {
    query: issueEscalationPolicyQuery,
    mutation: issueEscalationPolicyMutation,
  },
};

const escalationPoliciesQueries = {
  [TYPE_ISSUE]: {
    query: projectEscalationPoliciesQuery,
  },
};

export const parentQueries = {
  [TYPE_ISSUE]: {
    query: workItemParent,
    mutation: updateWorkItemParent,
  },
};

export const issuableAttributesQueries = {
  ...issuableAttributesQueriesFoss,
  [IssuableAttributeType.Iteration]: {
    current: issuableIterationQueries,
    list: iterationsQueries,
  },
  [IssuableAttributeType.Epic]: {
    current: issuableEpicQueries,
    list: epicsQueries,
    subscription: issuableEpicSubscription,
  },
  [IssuableAttributeType.EscalationPolicy]: {
    current: issuableEscalationPolicyQueries,
    list: escalationPoliciesQueries,
  },
  [IssuableAttributeType.Parent]: {
    current: parentQueries,
    list: parentsQueries,
    subscription: workItemParentSubscription,
  },
};

export const weightQueries = {
  [TYPE_ISSUE]: {
    query: issueWeightQuery,
    mutation: updateIssueWeightMutation,
    subscription: issuableWeightSubscription,
  },
};

export const healthStatusQueries = {
  [TYPE_ISSUE]: {
    mutation: updateStatusMutation,
    query: issueHealthStatusQuery,
  },
  [TYPE_EPIC]: {
    mutation: updateStatusMutation,
    query: issueHealthStatusQuery,
  },
};
