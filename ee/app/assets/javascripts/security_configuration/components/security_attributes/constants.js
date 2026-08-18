export const DRAWER_MODES = {
  ADD: 'add',
  EDIT: 'edit',
};
export const DRAWER_FLASH_CONTAINER_CLASS = 'attributes-drawer-flash-container';

export const CATEGORY_EDITABLE = 'EDITABLE';
export const CATEGORY_PARTIALLY_EDITABLE = 'EDITABLE_ATTRIBUTES';
export const CATEGORY_LOCKED = 'LOCKED';

export const defaultCategory = {
  name: '',
  description: '',
  multipleSelection: null,
  editableState: CATEGORY_EDITABLE,
};

export const RECENTLY_SAVED_TIMEOUT = 5000; // milliseconds

export const BULK_EDIT_ADD = 'ADD';
export const BULK_EDIT_REMOVE = 'REMOVE';
export const BULK_EDIT_REPLACE = 'REPLACE';
