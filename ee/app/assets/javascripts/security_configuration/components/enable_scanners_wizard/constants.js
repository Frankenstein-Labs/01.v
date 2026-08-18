export const ROUTE_ENABLE_SCANNERS = 'enable_scanners';
export const ROUTE_APPROACH = 'enable_step_approach';
export const ROUTE_ITEMS = 'enable_step_items';
export const ROUTE_SCANNERS = 'enable_step_scanners';
export const ROUTE_REVIEW = 'enable_step_review';
export const ROUTE_CONFIRMATION = 'enable_confirmation';

export const APPROACH_QUICK = 'quick';
export const APPROACH_ADVANCED = 'advanced';

export const EVENT_VIEW_STEP = 'view_enable_scanners_wizard_step';
export const EVENT_START_WIZARD = 'start_enable_scanners_wizard';
export const EVENT_SELECT_SCANNER = 'select_enable_scanners_wizard_scanner';
export const EVENT_DESELECT_SCANNER = 'deselect_enable_scanners_wizard_scanner';
export const EVENT_SELECT_ITEM = 'select_enable_scanners_wizard_item';
export const EVENT_DESELECT_ITEM = 'deselect_enable_scanners_wizard_item';
export const EVENT_APPLY_WIZARD = 'apply_enable_scanners_wizard';
export const EVENT_ABANDON_WIZARD = 'abandon_enable_scanners_wizard';

export const STEP_LABEL_APPROACH = 'approach';
export const STEP_LABEL_ITEMS = 'items';
export const STEP_LABEL_SCANNERS = 'scanners';
export const STEP_LABEL_REVIEW = 'review';
export const STEP_LABEL_CONFIRMATION = 'confirmation';

export const ROUTE_TO_STEP_LABEL = {
  [ROUTE_APPROACH]: STEP_LABEL_APPROACH,
  [ROUTE_ITEMS]: STEP_LABEL_ITEMS,
  [ROUTE_SCANNERS]: STEP_LABEL_SCANNERS,
  [ROUTE_REVIEW]: STEP_LABEL_REVIEW,
  [ROUTE_CONFIRMATION]: STEP_LABEL_CONFIRMATION,
};
