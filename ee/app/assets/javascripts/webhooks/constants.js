import { s__ } from '~/locale';

export const EE_TRIGGER_CONFIG = {
  memberApproval: {
    key: 'memberApprovalEvents',
    inputName: 'hook[member_approval_events]',
    label: s__('WebhooksTrigger|Member approval events'),
    helpText: s__('WebhooksTrigger|A member promotion request is queued, approved, or denied.'),
  },
  vulnerability: {
    key: 'vulnerabilityEvents',
    inputName: 'hook[vulnerability_events]',
    label: s__('WebhooksTrigger|Vulnerability events'),
    helpText: s__('WebhooksTrigger|A vulnerability is created or updated.'),
  },
  member: {
    key: 'memberEvents',
    inputName: 'hook[member_events]',
    label: s__('WebhooksTrigger|Member events'),
    helpText: s__('WebhooksTrigger|A group member is created, updated, or removed.'),
  },
  project: {
    key: 'projectEvents',
    inputName: 'hook[project_events]',
    label: s__('WebhooksTrigger|Project events'),
    helpText: s__('WebhooksTrigger|A project is created or removed.'),
  },
  subgroup: {
    key: 'subgroupEvents',
    inputName: 'hook[subgroup_events]',
    label: s__('WebhooksTrigger|Subgroup events'),
    helpText: s__('WebhooksTrigger|A subgroup is created or removed.'),
  },
};
