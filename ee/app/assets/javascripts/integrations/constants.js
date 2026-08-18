import { s__ } from '~/locale';

import {
  integrationTriggerEvents as integrationTriggerEventsCE,
  integrationTriggerEventTitles as integrationTriggerEventTitlesCE,
  integrationFormSections as integrationFormSectionsCE,
  integrationFormSectionComponents as integrationFormSectionComponentsCE,
} from '~/integrations/constants';

/* eslint-disable import/export */
export * from '~/integrations/constants';

export const integrationTriggerEvents = {
  ...integrationTriggerEventsCE,
  VULNERABILITY: 'vulnerability_events',
};

export const integrationTriggerEventTitles = {
  ...integrationTriggerEventTitlesCE,
  [integrationTriggerEvents.VULNERABILITY]: s__(
    'IntegrationEvents|A new, unique vulnerability is recorded (available only in GitLab Ultimate)',
  ),
};

export const integrationFormSections = {
  ...integrationFormSectionsCE,
  JIRA_VERIFICATION: 'jira_verification',
};

export const integrationFormSectionComponents = {
  ...integrationFormSectionComponentsCE,
  [integrationFormSections.JIRA_VERIFICATION]: 'IntegrationSectionJiraVerification',
};
/* eslint-enable import/export */
