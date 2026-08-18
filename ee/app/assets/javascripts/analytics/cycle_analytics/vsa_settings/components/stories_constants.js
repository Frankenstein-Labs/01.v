/* eslint-disable @gitlab/require-i18n-strings */

export const defaultStages = [
  {
    custom: false,
    relativePosition: 1,
    startEventIdentifier: 'issue_created',
    endEventIdentifier: 'issue_stage_end',
    name: 'Issue',
  },
  {
    custom: false,
    relativePosition: 2,
    startEventIdentifier: 'plan_stage_start',
    endEventIdentifier: 'issue_first_mentioned_in_commit',
    name: 'Plan',
  },
  {
    custom: false,
    relativePosition: 3,
    startEventIdentifier: 'code_stage_start',
    endEventIdentifier: 'merge_request_created',
    name: 'Code',
  },
];

export const stageEvents = [
  {
    name: 'Issue closed',
    identifier: 'issue_closed',
    type: 'simple',
    canBeStartEvent: true,
    allowedEndEvents: ['issue_last_edited', 'issue_label_added', 'issue_label_removed'],
  },
  {
    name: 'Issue created',
    identifier: 'issue_created',
    type: 'simple',
    canBeStartEvent: true,
    allowedEndEvents: [
      'issue_deployed_to_production',
      'issue_closed',
      'issue_first_added_to_board',
      'issue_first_associated_with_milestone',
      'issue_first_mentioned_in_commit',
      'issue_last_edited',
      'issue_label_added',
      'issue_label_removed',
      'issue_first_assigned_at',
      'issue_first_added_to_iteration',
    ],
  },
  {
    name: 'Issue first mentioned in a commit',
    identifier: 'issue_first_mentioned_in_commit',
    type: 'simple',
    canBeStartEvent: true,
    allowedEndEvents: [
      'issue_closed',
      'issue_first_associated_with_milestone',
      'issue_first_added_to_board',
      'issue_last_edited',
      'issue_label_added',
      'issue_label_removed',
      'issue_first_assigned_at',
      'issue_first_added_to_iteration',
    ],
  },
  {
    name: 'Issue label added',
    identifier: 'issue_label_added',
    type: 'label',
    canBeStartEvent: true,
    allowedEndEvents: [
      'issue_label_added',
      'issue_label_removed',
      'issue_closed',
      'issue_first_assigned_at',
      'issue_first_added_to_iteration',
    ],
  },
  {
    name: 'Issue label removed',
    identifier: 'issue_label_removed',
    type: 'label',
    canBeStartEvent: true,
    allowedEndEvents: ['issue_closed', 'issue_first_assigned_at', 'issue_first_added_to_iteration'],
  },
  {
    name: 'Merge request merged',
    identifier: 'merge_request_merged',
    type: 'simple',
    canBeStartEvent: true,
    allowedEndEvents: [
      'merge_request_first_deployed_to_production',
      'merge_request_closed',
      'merge_request_first_deployed_to_production',
      'merge_request_last_edited',
      'merge_request_label_added',
      'merge_request_label_removed',
      'merge_request_first_commit_at',
    ],
  },
  {
    name: 'Merge request created',
    identifier: 'merge_request_created',
    type: 'simple',
    canBeStartEvent: true,
    allowedEndEvents: [
      'merge_request_merged',
      'merge_request_closed',
      'merge_request_first_deployed_to_production',
      'merge_request_last_build_started',
      'merge_request_last_build_finished',
      'merge_request_last_edited',
      'merge_request_label_added',
      'merge_request_label_removed',
      'merge_request_first_assigned_at',
      'merge_request_last_approved_at',
    ],
  },
];

export const valueStreamGid = 'gid://gitlab/ValueStream/16';
export const valueStream = { id: 16, name: 'Cool value stream', isCustom: true };

const startEventLabel = { id: 'gid://gitlab/GroupLabel/1' };
const endEventLabel = { id: 'gid://gitlab/GroupLabel/2' };

export const customStage = {
  hidden: false,
  id: 341,
  name: 'Custom stage 1',
  startEventIdentifier: 'issue_label_added',
  endEventIdentifier: 'issue_label_removed',
  startEventLabel,
  endEventLabel,
  startEventLabelId: startEventLabel.id,
  endEventLabelId: endEventLabel.id,
  isDefault: false,
  custom: true,
};

export const valueStreamStages = ({ hideStages = false, addCustomStage = false } = {}) => [
  ...(addCustomStage ? [customStage] : []),
  ...defaultStages.map(({ custom, name }) => ({ custom, name, hidden: hideStages })),
];
