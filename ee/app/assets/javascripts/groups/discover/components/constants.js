import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export const PREMIUM_FEATURES_CICD = [
  {
    id: 'merge-trains',
    text: s__('BillingPlans|Merge Trains'),
    description: s__(
      'BillingPlans|Automatically merge changes in sequence to prevent conflicts and keep your branch stable.',
    ),
    link: helpPagePath('ci/pipelines/merge_trains.md'),
  },
  {
    id: 'push-rules',
    text: s__('BillingPlans|Push Rules'),
    description: s__(
      'BillingPlans|Customizable pre-receive Git hooks that enforce commit content standards, message formats, branch naming rules, and file requirements.',
    ),
    link: helpPagePath('user/project/repository/push_rules.md'),
  },
  {
    id: 'merge-request-guardrails',
    text: s__('BillingPlans|Merge Request Guardrails'),
    description: s__(
      'BillingPlans|Customize approval workflows with rules defining who must review code before merging, including options to prevent self-approvals and require authentication.',
    ),
    link: helpPagePath('administration/merge_requests_approvals.md'),
  },
];

export const PREMIUM_FEATURES_PLATFORM = [
  {
    id: 'repository-pull-mirroring',
    text: s__('BillingPlans|Repository Pull Mirroring'),
    description: s__(
      'BillingPlans|Automatically sync branches, tags, and commits from an external repository.',
    ),
    link: helpPagePath('user/project/repository/mirror/pull.md'),
  },
  {
    id: 'epics',
    text: s__('BillingPlans|Epics'),
    description: s__(
      'BillingPlans|Track related issues to manage large initiatives and monitor progress toward long-term goals.',
    ),
    link: helpPagePath('user/group/epics/_index.md'),
  },
  {
    id: 'protected-environments',
    text: s__('BillingPlans|Protected Environments'),
    description: s__(
      'BillingPlans|Safeguard testing and production environments by restricting deployment access to authorized users only.',
    ),
    link: helpPagePath('ci/environments/protected_environments.md'),
  },
];

export const PREMIUM_FEATURES_VISIBILITY = [
  {
    id: 'event-audits',
    text: s__('BillingPlans|Event Audits'),
    description: s__(
      'BillingPlans|Track critical security actions like permission changes and user modifications with comprehensive, permanent audit logs, providing detailed reports for compliance, incident response, and access reviews.',
    ),
    link: helpPagePath('user/compliance/audit_events.md', { anchor: 'group-audit-events' }),
  },
  {
    id: 'escalation-policies',
    text: s__('BillingPlans|Escalation Policies'),
    description: s__(
      'BillingPlans|Automatically notify the next responder when critical alerts are unacknowledged and ensure no incident is missed.',
    ),
    link: helpPagePath('operations/incident_management/escalation_policies.md'),
  },
  {
    id: 'compliance-center',
    text: s__('BillingPlans|Compliance Center'),
    description: s__(
      'BillingPlans|A central hub to manage standards adherence, violations reporting, and compliance frameworks.',
    ),
    link: helpPagePath('user/compliance/compliance_center/_index.md'),
  },
];

export const PREMIUM_FEATURES_SCALE = [
  {
    id: 'unlimited-licensed-users',
    text: s__('BillingPlans|Unlimited Licensed Users'),
    description: s__(
      'BillingPlans|Get unlimited user licenses, which includes guest user licenses, up from a maximum of 5 users on the Free plan.',
    ),
  },
  {
    id: 'priority-support',
    text: s__('BillingPlans|Priority Support'),
    description: s__('BillingPlans|Get support from GitLab with guaranteed response times.'),
  },
  {
    id: 'compute-minutes',
    text: s__('BillingPlans|10,000 Compute Minutes per Month'),
    description: s__(
      'BillingPlans|Get 10,000 compute minutes per month for your CI/CD pipelines, up from 400 on the Free plan.',
    ),
  },
];

export const DUO_FEATURES_COMPANION = [
  {
    id: 'gitlab-duo-chat',
    text: s__('BillingPlans|GitLab Duo Chat'),
    description: s__(
      'BillingPlans|Chat that can be used throughout the GitLab platform, granting a much more fluid and efficient workflow experience.',
    ),
  },
  {
    id: 'flow',
    text: s__('BillingPlans|Flows'),
    description: s__(
      'BillingPlans|Combine one or more agents to solve complex problems. Use pre-built flows for common development tasks or create custom workflows with your own triggers and steps.',
    ),
  },
  {
    id: 'agents',
    text: s__('BillingPlans|Agents'),
    description: s__(
      "BillingPlans|AI-powered assistants that help you accomplish specific tasks and answer complex questions. Use pre-built agents for common workflows or create custom ones for your team's needs.",
    ),
  },
];

export const DUO_AGENTIC_PLATFORM_LINK = helpPagePath('user/duo_agent_platform/_index.md');
