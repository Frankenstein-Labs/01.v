export const MOCK_LISTBOX_ITEMS = [
  {
    text: 'Listbox A',
    value: 'listbox_a',
  },
  {
    text: 'Listbox B',
    value: 'listbox_b',
  },
  {
    text: 'Listbox C',
    value: 'listbox_c',
  },
];

export const MOCK_FILTER_A = {
  type: 'filter_a',
  value: {
    data: 'value_a',
  },
};

export const MOCK_FILTER_B = {
  type: 'filter_b',
  value: {
    data: 'value_b',
  },
};

export const MOCK_FILTERED_SEARCH_TOKENS = [
  {
    title: 'Filter A',
    type: MOCK_FILTER_A.type,
    options: [MOCK_FILTER_A.value.data],
  },
  {
    title: 'Filter B',
    type: MOCK_FILTER_B.type,
    options: [MOCK_FILTER_B.value.data],
  },
];

export const MOCK_MODAL_DEFINITION = {
  title: 'Test action on %{type}',
  description: 'Executes action on %{type}',
};

export const MOCK_BULK_ACTIONS = [
  {
    id: 'test_action',
    text: 'Test Action',
    action: 'TEST_ACTION',
    modal: MOCK_MODAL_DEFINITION,
  },
  {
    id: 'test_action2',
    text: 'Test Action 2',
    action: 'TEST_ACTION_2',
    modal: MOCK_MODAL_DEFINITION,
  },
];

export const MOCK_ADDITIONAL_BULK_ACTION = {
  id: 'nested_action',
  text: 'Nested bulk action',
  action: 'NESTED_TEST_ACTION',
  modal: MOCK_MODAL_DEFINITION,
};

export const MOCK_STATUSES = [
  {
    tooltip: 'Status: A',
    icon: 'status_preparing',
    variant: 'warning',
    label: 'Label A',
  },
  {
    tooltip: 'Status: B',
    icon: 'status_success',
    variant: 'success',
    label: 'Label B',
  },
];

const MOCK_JUST_NOW = new Date().toISOString();

export const MOCK_TIME_AGO = [
  {
    label: 'Time A',
    dateString: MOCK_JUST_NOW,
    defaultText: 'N/A',
  },
  {
    label: 'Time B',
    dateString: MOCK_JUST_NOW,
    defaultText: 'N/A',
  },
];

export const MOCK_EMPTY_STATE = {
  title: 'There are not Test Items to show',
  description: 'No %{itemTitle} were found. Click %{linkStart}this link%{linkEnd} to learn more.',
  itemTitle: 'Test Items',
  helpLink: '/help/link',
  hasFilters: false,
};

export const MOCK_ERRORS = [
  {
    label: 'Error type A',
    message: 'There was an error',
  },
  {
    label: 'Error type B',
    message: 'There was another error',
  },
];

export const MOCK_SORT = {
  value: 'sort_value',
  direction: 'asc',
};

export const MOCK_SORT_OPTIONS = [
  {
    text: 'Sort value',
    value: 'sort_value',
  },
  {
    text: 'Another sort value',
    value: 'another_sort_value',
  },
];
