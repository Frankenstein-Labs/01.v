import { __ } from '~/locale';

export const DAST_EDIT_ACTION = 'edit';
export const DAST_DELETE_ACTION = 'delete';

export const booleanOptions = [
  {
    value: true,
    text: __('True'),
  },
  {
    value: false,
    text: __('False'),
  },
];

export const getEmptyVariable = () => ({
  id: null,
  value: '',
  type: null,
  description: '',
  example: '',
});
