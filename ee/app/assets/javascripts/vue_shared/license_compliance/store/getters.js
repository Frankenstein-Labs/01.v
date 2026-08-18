import { __, n__, s__, sprintf } from '~/locale';
import { LICENSE_APPROVAL_STATUS, REPORT_GROUPS } from '../constants';
import { addLicensesMatchingReportGroupStatus, reportGroupHasAtLeastOneLicense } from './utils';

export const isLoading = (state) =>
  state.isLoadingManagedLicenses ||
  state.isLoadingLicenseReport ||
  state.isLoadingLicenseCheckApprovalRule;

export const isLicenseBeingUpdated =
  (state) =>
  (id = null) =>
    state.pendingLicenses.includes(id);

export const licenseReport = (state) => state.newLicenses;

export const licenseReportGroups = (state) =>
  REPORT_GROUPS.map(addLicensesMatchingReportGroupStatus(state.newLicenses)).filter(
    reportGroupHasAtLeastOneLicense,
  );

export const hasReportItems = (_, getters) => {
  return Boolean(getters.licenseReportLength);
};

export const baseReportHasLicenses = (state) => {
  return Boolean(state.existingLicenses.length);
};

export const licenseReportLength = (_, getters) => {
  return getters.licenseReport.length;
};

export const licenseSummaryText = (state, getters) => {
  if (getters.isLoading) {
    return sprintf(s__('ciReport|Loading %{reportName} report'), {
      reportName: __('License compliance'),
    });
  }

  if (state.loadLicenseReportError) {
    return sprintf(s__('ciReport|Failed to load %{reportName} report'), {
      reportName: __('License compliance'),
    });
  }

  if (getters.hasReportItems) {
    return state.hasLicenseCheckApprovalRule
      ? getters.summaryTextWithLicenseCheck
      : getters.summaryTextWithoutLicenseCheck;
  }

  if (!getters.baseReportHasLicenses) {
    return s__(
      'LicenseCompliance|License compliance detected no licenses for the source branch only',
    );
  }

  return s__('LicenseCompliance|License compliance detected no new licenses');
};

export const summaryTextWithLicenseCheck = (_, getters) => {
  if (!getters.baseReportHasLicenses) {
    return getters.reportContainsDeniedLicense
      ? n__(
          'LicenseCompliance|License compliance detected %d license and policy violation for the source branch only; approval required',
          'LicenseCompliance|License compliance detected %d licenses and policy violations for the source branch only; approval required',
          getters.licenseReportLength,
        )
      : n__(
          'LicenseCompliance|License compliance detected %d license for the source branch only',
          'LicenseCompliance|License compliance detected %d licenses for the source branch only',
          getters.licenseReportLength,
        );
  }

  return getters.reportContainsDeniedLicense
    ? n__(
        'LicenseCompliance|License compliance detected %d new license and policy violation; approval required',
        'LicenseCompliance|License compliance detected %d new licenses and policy violations; approval required',
        getters.licenseReportLength,
      )
    : n__(
        'LicenseCompliance|License compliance detected %d new license',
        'LicenseCompliance|License compliance detected %d new licenses',
        getters.licenseReportLength,
      );
};

export const summaryTextWithoutLicenseCheck = (_, getters) => {
  if (!getters.baseReportHasLicenses) {
    return getters.reportContainsDeniedLicense
      ? n__(
          'LicenseCompliance|License compliance detected %d license and policy violation',
          'LicenseCompliance|License compliance detected %d licenses and policy violations',
          getters.licenseReportLength,
        )
      : n__(
          'LicenseCompliance|License compliance detected %d license',
          'LicenseCompliance|License compliance detected %d licenses',
          getters.licenseReportLength,
        );
  }

  return getters.reportContainsDeniedLicense
    ? n__(
        'LicenseCompliance|License compliance detected %d new license and policy violation',
        'LicenseCompliance|License compliance detected %d new licenses and policy violations',
        getters.licenseReportLength,
      )
    : n__(
        'LicenseCompliance|License compliance detected %d new license',
        'LicenseCompliance|License compliance detected %d new licenses',
        getters.licenseReportLength,
      );
};

export const reportContainsDeniedLicense = (_, getters) =>
  (getters.licenseReport || []).some(
    (license) => license.approvalStatus === LICENSE_APPROVAL_STATUS.DENIED,
  );
