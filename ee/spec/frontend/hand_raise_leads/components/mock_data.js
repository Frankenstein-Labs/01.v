export const COUNTRY_WITH_STATES = 'US';
export const STATE = 'CA';
export const COUNTRIES = [
  { id: COUNTRY_WITH_STATES, name: 'United States', flag: 'US', internationalDialCode: '1' },
  { id: 'CA', name: 'Canada', flag: 'CA', internationalDialCode: '1' },
  { id: 'NL', name: 'Netherlands', flag: 'NL', internationalDialCode: '31' },
];

export const STATES = [
  { countryId: COUNTRY_WITH_STATES, id: STATE, name: 'California' },
  { countryId: 'CA', id: 'BC', name: 'British Columbia' },
];

export const USER = {
  namespaceId: '1',
  userName: 'joe',
  firstName: 'Joe',
  lastName: 'Doe',
  companyName: 'ACME',
};

export const GLM_CONTENT = 'some-content';
export const PRODUCT_INTERACTION = '_product_interaction_';
export const BUTTON_TEXT = '_button_text_';
export const CREATE_HAND_RAISE_LEAD_PATH = '/-/gitlab_subscriptions/hand_raise_leads';

export const BUTTON_ATTRIBUTES = {
  href: '#',
  buttonTextClasses: 'mocked-testing-class',
};
