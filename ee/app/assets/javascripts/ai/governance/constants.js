import { s__ } from '~/locale';

// AiToolActionType GraphQL enum values. Used by the AI tool rules search filter.
export const ACTION_TYPE_READ = 'READ';
export const ACTION_TYPE_WRITE = 'WRITE';
export const ACTION_TYPE_DESTROY = 'DESTROY';

// Filtered-search token type for the action filter.
export const TOKEN_TYPE_ACTION = 'action';

// Static options for the action token, mapping a human title to the enum value.
export const ACTION_TOKEN_OPTIONS = [
  { value: ACTION_TYPE_READ, title: s__('AiGovernance|Read') },
  { value: ACTION_TYPE_WRITE, title: s__('AiGovernance|Write') },
  { value: ACTION_TYPE_DESTROY, title: s__('AiGovernance|Destroy') },
];
