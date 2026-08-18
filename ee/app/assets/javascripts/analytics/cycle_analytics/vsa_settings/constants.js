import { __, s__, sprintf } from '~/locale';

export const NAME_MAX_LENGTH = 100;
export const NAME_MIN_LENGTH = 3;

export const i18n = {
  FORM_CREATED: s__("CreateValueStreamForm|'%{name}' Value Stream created"),
  FORM_EDITED: s__("CreateValueStreamForm|'%{name}' Value Stream saved"),
  RECOVER_HIDDEN_STAGE: s__('CreateValueStreamForm|Recover hidden stage'),
  DEFAULT_STAGE_LABEL: s__('CreateValueStreamForm|Default stage'),
  RECOVER_STAGE_TITLE: s__('CreateValueStreamForm|Default stages'),
  RECOVER_STAGES_VISIBLE: s__('CreateValueStreamForm|All default stages are currently visible'),
  SELECT_START_EVENT: s__('CreateValueStreamForm|Select start event'),
  SELECT_END_EVENT: s__('CreateValueStreamForm|Select end event'),
  FORM_FIELD_STAGE_NAME_PLACEHOLDER: s__('CreateValueStreamForm|Enter stage name'),
  FORM_FIELD_START_EVENT: s__('CreateValueStreamForm|Start event'),
  FORM_FIELD_START_EVENT_LABEL: s__('CreateValueStreamForm|Start event label'),
  FORM_FIELD_END_EVENT: s__('CreateValueStreamForm|End event'),
  FORM_FIELD_END_EVENT_LABEL: s__('CreateValueStreamForm|End event label'),
  DEFAULT_FIELD_START_EVENT_LABEL: s__('CreateValueStreamForm|Start event: '),
  DEFAULT_FIELD_END_EVENT_LABEL: s__('CreateValueStreamForm|End event: '),
  BTN_UPDATE_STAGE: s__('CreateValueStreamForm|Update stage'),
  TITLE_EDIT_STAGE: s__('CreateValueStreamForm|Editing stage'),
  TITLE_ADD_STAGE: s__('CreateValueStreamForm|New stage'),
  BTN_CANCEL: __('Cancel'),
  TEMPLATE_DEFAULT: s__('CreateValueStreamForm|Create from default template'),
  TEMPLATE_BLANK: s__('CreateValueStreamForm|Create from no template'),
  ISSUE_STAGE_END: s__('CreateValueStreamForm|Issue stage end'),
  PLAN_STAGE_START: s__('CreateValueStreamForm|Plan stage start'),
  CODE_STAGE_START: s__('CreateValueStreamForm|Code stage start'),
  CUSTOM_BADGE_LABEL: __('Custom'),
};

export const ERRORS = {
  VALUE_STREAM_NAME_REQUIRED: s__('CreateValueStreamForm|Name is required'),
  VALUE_STREAM_NAME_MIN_LENGTH: sprintf(
    s__('CreateValueStreamForm|Minimum length %{minLength} characters'),
    {
      minLength: NAME_MIN_LENGTH,
    },
  ),
  STAGE_NAME_MIN_LENGTH: s__('CreateValueStreamForm|Stage name is required'),
  MAX_LENGTH: sprintf(s__('CreateValueStreamForm|Maximum length %{maxLength} characters'), {
    maxLength: NAME_MAX_LENGTH,
  }),
  START_EVENT_REQUIRED: s__('CreateValueStreamForm|Start event is required'),
  END_EVENT_REQUIRED: s__('CreateValueStreamForm|End event is required'),
  EVENT_LABEL_REQUIRED: s__('CreateValueStreamForm|Label is required'),
  STAGE_NAME_EXISTS: s__('CreateValueStreamForm|Stage name already exists'),
  INVALID_EVENT_PAIRS: s__(
    'CreateValueStreamForm|Start event changed, please select a valid end event',
  ),
};

export const STAGE_SORT_DIRECTION = {
  UP: 'UP',
  DOWN: 'DOWN',
};

export const formFieldKeys = [
  'id',
  'name',
  'hidden',
  'startEventIdentifier',
  'endEventIdentifier',
  'startEventLabelId',
  'endEventLabelId',
];

export const editableFormFieldKeys = [...formFieldKeys, 'custom'];

export const defaultFields = formFieldKeys.reduce((acc, field) => ({ ...acc, [field]: null }), {});
export const defaultErrors = formFieldKeys.reduce((acc, field) => ({ ...acc, [field]: [] }), {});

export const defaultCustomStageFields = { ...defaultFields, custom: true };

export const PRESET_OPTIONS_DEFAULT = 'default';
export const PRESET_OPTIONS_BLANK = 'blank';
export const PRESET_OPTIONS = [
  {
    text: i18n.TEMPLATE_DEFAULT,
    value: PRESET_OPTIONS_DEFAULT,
  },
  {
    text: i18n.TEMPLATE_BLANK,
    value: PRESET_OPTIONS_BLANK,
  },
];

// These events can only be set on the back end, they are used in the
// initial configuration of some default stages, but should not be
// selectable by users via the form, they are added here only for display
// purposes when we are editing a default value stream
export const ADDITIONAL_DEFAULT_STAGE_EVENTS = [
  {
    identifier: 'issue_stage_end',
    name: i18n.ISSUE_STAGE_END,
  },
  {
    identifier: 'plan_stage_start',
    name: i18n.PLAN_STAGE_START,
  },
  {
    identifier: 'code_stage_start',
    name: i18n.CODE_STAGE_START,
  },
];

export const VSA_SETTINGS_FORM_SUBMISSION_SUCCESS_ALERT_ID = 'vsa-settings-form-submission-success';
