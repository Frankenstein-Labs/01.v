import siteProfilesFixture from 'test_fixtures/graphql/security_configuration/dast_profiles/graphql/dast_site_profiles.query.graphql.basic.json';
import scannerProfilesFixtures from 'test_fixtures/graphql/security_configuration/dast_profiles/graphql/dast_scanner_profiles.query.graphql.basic.json';
import policySiteProfilesFixtures from 'test_fixtures/graphql/security_configuration/dast_profiles/graphql/dast_site_profiles.query.graphql.from_policies.json';
import policyScannerProfilesFixtures from 'test_fixtures/graphql/security_configuration/dast_profiles/graphql/dast_scanner_profiles.query.graphql.from_policies.json';
import dastFailedSiteValidationsFixtures from 'test_fixtures/graphql/security_configuration/dast_profiles/graphql/dast_failed_site_validations.query.graphql.json';

export const siteProfiles = siteProfilesFixture.data.project.siteProfiles.nodes;

export const nonValidatedSiteProfile = siteProfiles.find(
  ({ validationStatus }) => validationStatus === 'NONE',
);
export const validatedSiteProfile = siteProfiles.find(
  ({ validationStatus }) => validationStatus === 'PASSED_VALIDATION',
);

export const policySiteProfiles = policySiteProfilesFixtures.data.project.siteProfiles.nodes;

export const policyScannerProfiles =
  policyScannerProfilesFixtures.data.project.scannerProfiles.nodes;

export const scannerProfiles = scannerProfilesFixtures.data.project.scannerProfiles.nodes;

export const activeScannerProfile = scannerProfiles.find(({ scanType }) => scanType === 'ACTIVE');
export const passiveScannerProfile = scannerProfiles.find(({ scanType }) => scanType === 'PASSIVE');

export const failedSiteValidations =
  dastFailedSiteValidationsFixtures.data.project.validations.nodes;

export const mockSharedData = {
  showDiscardChangesModal: false,
  formTouched: false,
  history: [],
  cashedPayload: {
    __typename: 'CachedPayload',
    profileType: '',
    mode: '',
  },
  resetAndClose: false,
  __typename: 'SharedData',
};

export const mockVariables = [
  {
    name: 'Active scan timeout',
    variable: 'DAST_ACTIVE_SCAN_TIMEOUT',
    value: '3h',
  },
  {
    name: 'Clear input fields',
    variable: 'DAST_AUTH_CLEAR_INPUT_FIELDS',
    value: 'true',
  },
];

export const mockAdditionalVariableOptions = {
  DAST_ACTIVE_SCAN_TIMEOUT: {
    additional: true,
    type: 'Duration string',
    example: '3h',
    name: 'Active scan timeout',
    description:
      'The maximum amount of time to wait for the active scan phase of the scan to complete. Defaults to 3h.',
  },
  DAST_AUTH_CLEAR_INPUT_FIELDS: {
    additional: true,
    auth: true,
    type: 'boolean',
    example: true,
    name: 'Clear input fields',
    description:
      'Disables clearing of username and password fields before attempting manual login. Set to false by default.',
  },
  DAST_AUTH_BEFORE_LOGIN_ACTIONS: {
    additional: true,
    auth: true,
    type: 'selector',
    example: 'css:.user,id:show-login-form',
    name: 'Before-login actions',
    description:
      'A comma-separated list of selectors representing elements to click on prior to entering the DAST_AUTH_USERNAME and DAST_AUTH_PASSWORD into the login form.',
  },
};
