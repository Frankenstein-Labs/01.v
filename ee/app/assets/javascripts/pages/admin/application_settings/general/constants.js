import { s__ } from '~/locale';

export const I18N = {
  passwordNumberRequiredLabel: s__('ApplicationSettings|Require numbers'),
  passwordNumberRequiredHelpText: s__(
    'ApplicationSettings|When enabled, new passwords must contain at least one number (0-9).',
  ),
  passwordUppercaseRequiredLabel: s__('ApplicationSettings|Require uppercase letters'),
  passwordUppercaseRequiredHelpText: s__(
    'ApplicationSettings|When enabled, new passwords must contain at least one uppercase letter (A-Z).',
  ),
  passwordLowercaseRequiredLabel: s__('ApplicationSettings|Require lowercase letters'),
  passwordLowercaseRequiredHelpText: s__(
    'ApplicationSettings|When enabled, new passwords must contain at least one lowercase letter (a-z).',
  ),
  passwordSymbolRequiredLabel: s__('ApplicationSettings|Require symbols'),
  passwordSymbolRequiredHelpText: s__(
    'ApplicationSettings|When enabled, new passwords must contain at least one symbol.',
  ),
};

const OFF = 0;
const USER_CAP = 1;
const BLOCK_OVERAGES = 2;

export const SEAT_CONTROL = Object.freeze({
  OFF,
  USER_CAP,
  BLOCK_OVERAGES,
});

export const USER_PROVISIONING_METHOD = Object.freeze({
  LDAP: 'ldap',
  SAML_SCIM: 'saml-scim',
  LDAP_SAML_SCIM: 'ldap-saml-scim',
});
