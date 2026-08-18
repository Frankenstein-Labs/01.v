import {
  GL_COLOR_ORANGE_600,
  GL_COLOR_NEUTRAL_500,
  GL_COLOR_BLUE_500,
  GL_COLOR_GREEN_500,
  GL_COLOR_RED_500,
} from '@gitlab/ui/src/tokens/build/js/tokens';
import * as CE from '~/work_items/constants';
import { s__ } from '~/locale';

/*
 * We're disabling the import/export rule here because we want to
 * re-export the constants from the CE file while also overriding
 * anything that's EE-specific.
 */
/* eslint-disable import/export */
export * from '~/work_items/constants';

export const optimisticUserPermissions = {
  ...CE.optimisticUserPermissions,
  blockedWorkItems: true,
};

export const newWorkItemOptimisticUserPermissions = {
  ...CE.newWorkItemOptimisticUserPermissions,
  blockedWorkItems: true,
};

export const getSettingsConfig = (context = 'root') => {
  const adminContexts = ['admin'];
  const isAdminContext = adminContexts.includes(context);
  const isProjectContext = context === 'project';

  const DEFAULT_SETTINGS_CONFIG = {
    showWorkItemTypesSettings: true,
    showEnabledWorkItemTypesSettings: true,
    showCustomFieldsSettings: true,
    showCustomStatusSettings: true,
    showTypeCustomizationToggle: true,
    workItemTypeSettingsPermissions: isAdminContext
      ? ['edit', 'create', 'archive']
      : ['edit', 'create', 'archive', 'enable', 'disable'],
    enabledWorkItemTypeSettingsPermissions: isProjectContext ? ['enable', 'disable'] : [],
    workItemSettingsLayout: 'list',
  };

  const configurableTypesSubtexts = {
    root: s__('WorkItem|All work item types which can be enabled within this group.'),
    admin: s__('WorkItem|All work item types which can be enabled within this organization.'),
  };

  const enabledTypesSubtexts = {
    root: s__(
      "WorkItem|Work item types usable in this group. Groups are restricted to type 'Epic'.",
    ),
    subgroup: s__(
      "WorkItem|Work item types usable in this group. Groups are restricted to type 'Epic'.",
    ),
    project: s__('WorkItem|Work item types usable in this project.'),
    admin: s__('WorkItem|Work item types usable in this organization'),
  };

  return {
    ...DEFAULT_SETTINGS_CONFIG,
    configurableTypesSubtext: configurableTypesSubtexts[context] || configurableTypesSubtexts.root,
    enabledTypesSubtext: enabledTypesSubtexts[context] || enabledTypesSubtexts.root,
  };
};
/* eslint-enable import/export */

export const DEFAULT_STATE_CLOSED = 'closed';
export const DEFAULT_STATE_DUPLICATE = 'duplicate';
export const DEFAULT_STATE_OPEN = 'open';

export const DEFAULT_STATE_TO_TEXT_MAP = {
  [DEFAULT_STATE_CLOSED]: s__('WorkItem|Closed'),
  [DEFAULT_STATE_DUPLICATE]: s__('WorkItem|Duplicate'),
  [DEFAULT_STATE_OPEN]: s__('WorkItem|Open'),
};

export const STATUS_CATEGORIES = {
  TRIAGE: 'TRIAGE',
  TO_DO: 'TO_DO',
  IN_PROGRESS: 'IN_PROGRESS',
  DONE: 'DONE',
  CANCELED: 'CANCELED',
};

export const STATUS_CATEGORIES_MAP = {
  [STATUS_CATEGORIES.TRIAGE]: {
    icon: 'status-neutral',
    color: GL_COLOR_ORANGE_600,
    label: s__('WorkItem|Triage'),
    defaultState: DEFAULT_STATE_OPEN,
    workItemState: CE.STATE_OPEN,
    description: s__(
      'WorkItem|Use for items that are still in a proposal or ideation phase, not yet accepted or planned for work.',
    ),
  },
  [STATUS_CATEGORIES.TO_DO]: {
    icon: 'status-waiting',
    color: GL_COLOR_NEUTRAL_500,
    label: s__('WorkItem|To do'),
    defaultState: DEFAULT_STATE_OPEN,
    workItemState: CE.STATE_OPEN,
    description: s__('WorkItem|Use for planned work that is not actively being worked on.'),
  },
  [STATUS_CATEGORIES.IN_PROGRESS]: {
    icon: 'status-running',
    color: GL_COLOR_BLUE_500,
    label: s__('WorkItem|In progress'),
    defaultState: DEFAULT_STATE_OPEN,
    workItemState: CE.STATE_OPEN,
    description: s__('WorkItem|Use for items that are actively being worked on.'),
  },
  [STATUS_CATEGORIES.DONE]: {
    icon: 'status-success',
    color: GL_COLOR_GREEN_500,
    label: s__('WorkItem|Done'),
    defaultState: DEFAULT_STATE_CLOSED,
    workItemState: CE.STATE_CLOSED,
    description: s__(
      'WorkItem|Use for items that have been completed. Applying a done status will close the item.',
    ),
  },
  [STATUS_CATEGORIES.CANCELED]: {
    icon: 'status-cancelled',
    color: GL_COLOR_RED_500,
    label: s__('WorkItem|Canceled'),
    defaultState: DEFAULT_STATE_DUPLICATE,
    workItemState: CE.STATE_CLOSED,
    description: s__(
      'WorkItem|Use for items that are no longer relevant and will not be completed. Applying a canceled status will close the item.',
    ),
  },
};

export const ACTIVE_TYPES_LIMIT = 40;
export const WARNING_THRESHOLD = 0.8;
export const HEALTH_STATUS_VALUE_MAP = {
  onTrack: 1,
  needsAttention: 2,
  atRisk: 3,
};

export const STATUS_CATEGORY_VALUE_MAP = {
  triage: 1,
  to_do: 2,
  in_progress: 3,
  done: 4,
  canceled: 5,
};

export const WIDGET_TYPE_AGENT_PLAN = 'AGENT_PLAN';

export const MANAGED_WIDGET_TYPES = [WIDGET_TYPE_AGENT_PLAN];
