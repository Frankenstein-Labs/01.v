import { LICENSE_APPROVAL_STATUS } from 'ee/vue_shared/license_compliance/constants';
import createStore from 'ee/vue_shared/license_compliance/store';
import * as types from 'ee/vue_shared/license_compliance/store/mutation_types';

import { TEST_HOST } from 'spec/test_constants';

describe('License store mutations', () => {
  let store;

  beforeEach(() => {
    store = createStore();
  });

  describe('SET_API_SETTINGS', () => {
    it('assigns data to the store', () => {
      const data = { apiUrlManageLicenses: TEST_HOST };

      store.commit(`licenseManagement/${types.SET_API_SETTINGS}`, data);

      expect(store.state.licenseManagement.apiUrlManageLicenses).toBe(TEST_HOST);
    });
  });

  describe('RECEIVE_MANAGED_LICENSES_SUCCESS', () => {
    it('sets isLoadingManagedLicenses to false and saves managed licenses', () => {
      store.replaceState({
        ...store.state,
        licenseManagement: {
          managedLicenses: false,
          isLoadingManagedLicenses: true,
        },
      });

      store.commit(`licenseManagement/${types.RECEIVE_MANAGED_LICENSES_SUCCESS}`, [
        { name: 'Foo', approval_status: LICENSE_APPROVAL_STATUS.approved },
      ]);

      expect(store.state.licenseManagement.managedLicenses).toEqual([
        { name: 'Foo', approvalStatus: LICENSE_APPROVAL_STATUS.approved },
      ]);

      expect(store.state.licenseManagement.isLoadingManagedLicenses).toBe(false);
    });
  });

  describe('RECEIVE_MANAGED_LICENSES_ERROR', () => {
    it('sets isLoadingManagedLicenses to true and saves the error', () => {
      const error = new Error('test');
      store.replaceState({
        ...store.state,
        licenseManagement: {
          isLoadingManagedLicenses: true,
        },
      });

      store.commit(`licenseManagement/${types.RECEIVE_MANAGED_LICENSES_ERROR}`, error);

      expect(store.state.licenseManagement.isLoadingManagedLicenses).toBe(false);
    });
  });

  describe('REQUEST_MANAGED_LICENSES', () => {
    it('sets isLoadingManagedLicenses to true', () => {
      store.replaceState({
        ...store.state,
        licenseManagement: {
          isLoadingManagedLicenses: true,
        },
      });

      store.commit(`licenseManagement/${types.REQUEST_MANAGED_LICENSES}`);

      expect(store.state.licenseManagement.isLoadingManagedLicenses).toBe(true);
    });
  });

  describe('REQUEST_PARSED_LICENSE_REPORT', () => {
    beforeEach(() => {
      store.replaceState({
        ...store.state,
        licenseManagement: {
          isLoadingLicenseReport: false,
        },
      });
      store.commit(`licenseManagement/${types.REQUEST_PARSED_LICENSE_REPORT}`);
    });

    it('should initiate loading', () => {
      expect(store.state.licenseManagement.isLoadingLicenseReport).toBe(true);
    });
  });

  describe('RECEIVE_PARSED_LICENSE_REPORT_SUCCESS', () => {
    const newLicenses = [];
    const existingLicenses = [];

    beforeEach(() => {
      store.replaceState({
        ...store.state,
        licenseManagement: {
          isLoadingLicenseReport: true,
          loadLicenseReportError: new Error('test'),
        },
      });
      store.commit(`licenseManagement/${types.RECEIVE_PARSED_LICENSE_REPORT_SUCCESS}`, {
        newLicenses,
        existingLicenses,
      });
    });

    it('should set the new and existing reports', () => {
      expect(store.state.licenseManagement.newLicenses).toStrictEqual(newLicenses);
      expect(store.state.licenseManagement.existingLicenses).toStrictEqual(existingLicenses);
    });

    it('should cancel loading and clear any errors', () => {
      expect(store.state.licenseManagement.isLoadingLicenseReport).toBe(false);
      expect(store.state.licenseManagement.loadLicenseReportError).toBe(false);
    });
  });

  describe('RECEIVE_PARSED_LICENSE_REPORT_ERROR', () => {
    const error = new Error('test');
    beforeEach(() => {
      store.replaceState({
        ...store.state,
        licenseManagement: {
          isLoadingLicenseReport: true,
          loadLicenseReportError: false,
        },
      });
      store.commit(`licenseManagement/${types.RECEIVE_PARSED_LICENSE_REPORT_ERROR}`, error);
    });

    it('should set the error on the state', () => {
      expect(store.state.licenseManagement.loadLicenseReportError).toBe(error);
    });

    it('should cancel loading', () => {
      expect(store.state.licenseManagement.isLoadingLicenseReport).toBe(false);
    });
  });
});
