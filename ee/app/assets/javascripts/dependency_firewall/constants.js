import { s__ } from '~/locale';

export const MODE_ENFORCE = 'ENFORCE';
export const NAMESPACE_GROUP = 'group';
export const NAMESPACE_PROJECT = 'project';
export const ICON_BLOCKED = 'status-failed';
export const ICON_WARNED = 'status-alert';
export const ICON_NEUTRAL = 'trigger-source';

// Maps the backend `ruleType` enum (Security::DependencyFirewallPolicyRule)
export const RULE_TYPE_LABELS = {
  LICENSE: s__('DependencyFirewall|License compliance rule'),
  VULNERABILITY: s__('DependencyFirewall|Vulnerability severity rule'),
  MALICIOUS: s__('DependencyFirewall|Malicious package rule'),
};

export const RULE_TYPE_UNKNOWN_LABEL = s__('DependencyFirewall|Unknown policy type');

export const TIME_WINDOW_7_DAYS = 7;
export const TIME_WINDOW_30_DAYS = 30;
export const DEFAULT_TIME_WINDOW_DAYS = TIME_WINDOW_7_DAYS;

export const TIME_WINDOW_OPTIONS = [
  { value: TIME_WINDOW_7_DAYS, text: s__('DependencyFirewall|Last 7 days') },
  { value: TIME_WINDOW_30_DAYS, text: s__('DependencyFirewall|Last 30 days') },
];
