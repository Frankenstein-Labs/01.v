import axios from '~/lib/utils/axios_utils';
import pollUntilComplete from '~/lib/utils/poll_until_complete';
import * as types from './mutation_types';
import { convertToOldReportFormat } from './utils';

export const setAPISettings = ({ commit }, data) => {
  commit(types.SET_API_SETTINGS, data);
};

export const requestManagedLicenses = ({ commit }) => {
  commit(types.REQUEST_MANAGED_LICENSES);
};
export const receiveManagedLicensesSuccess = ({ commit }, licenses) => {
  commit(types.RECEIVE_MANAGED_LICENSES_SUCCESS, licenses);
};
export const receiveManagedLicensesError = ({ commit }) => {
  commit(types.RECEIVE_MANAGED_LICENSES_ERROR);
};
export const fetchManagedLicenses = ({ dispatch, state }) => {
  dispatch('requestManagedLicenses');

  const { apiUrlManageLicenses } = state;

  return axios
    .get(apiUrlManageLicenses, { params: { per_page: 100 } })
    .then(({ data }) => {
      dispatch('receiveManagedLicensesSuccess', data);
    })
    .catch(() => {
      dispatch('receiveManagedLicensesError');
    });
};

export const requestParsedLicenseReport = ({ commit }) => {
  commit(types.REQUEST_PARSED_LICENSE_REPORT);
};
export const receiveParsedLicenseReportSuccess = ({ commit }, reports) => {
  commit(types.RECEIVE_PARSED_LICENSE_REPORT_SUCCESS, reports);
};
export const receiveParsedLicenseReportError = ({ commit }, error) => {
  commit(types.RECEIVE_PARSED_LICENSE_REPORT_ERROR, error);
};
export const fetchParsedLicenseReport = ({ dispatch, state }) => {
  dispatch('requestParsedLicenseReport');

  pollUntilComplete(state.licensesApiPath)
    .then(({ data }) => {
      const newLicenses = (data.new_licenses || data).map(convertToOldReportFormat);
      const existingLicenses = (data.existing_licenses || []).map(convertToOldReportFormat);
      dispatch('receiveParsedLicenseReportSuccess', { newLicenses, existingLicenses });
    })
    .catch((error) => {
      dispatch('receiveParsedLicenseReportError', error);
    });
};
