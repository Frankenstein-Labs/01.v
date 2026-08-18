import {
  GlToggle,
  GlFormGroup,
  GlFormSelect,
  GlFormInput,
  GlButton,
  GlSkeletonLoader,
  GlAlert,
  GlForm,
} from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { visitUrl, visitUrlWithAlerts } from '~/lib/utils/url_utility';
import VirtualRegistriesCleanupPolicyForm from 'ee/packages_and_registries/settings/group/components/virtual_registries_cleanup_policy_form.vue';
import getVirtualRegistriesCleanupPolicyDetails from 'ee/packages_and_registries/settings/group/graphql/queries/get_virtual_registries_cleanup_policy_details.query.graphql';
import upsertVirtualRegistriesCleanupPolicy from 'ee/packages_and_registries/settings/group/graphql/mutations/upsert_virtual_registries_cleanup_policy.mutation.graphql';
import {
  groupVirtualRegistriesCleanupPolicyMock,
  virtualRegistriesCleanupPolicyMutationMock,
} from '../mock_data';

jest.mock('~/lib/utils/url_utility');

Vue.use(VueApollo);

describe('VirtualRegistriesCleanupPolicyForm', () => {
  let wrapper;
  let apolloProvider;
  let queryHandler;
  let mutationHandler;

  const defaultProvide = {
    groupPath: 'test-group',
    settingsPath: '/groups/test-group/-/settings/packages_and_registries',
  };

  const findLoadingIcon = () => wrapper.findComponent(GlSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEnableToggle = () => wrapper.findComponent(GlToggle);
  const findCadenceSelect = () => wrapper.findComponent(GlFormSelect);
  const findKeepNDaysInput = () => wrapper.findComponent(GlFormInput);
  const findKeepNDaysFormGroup = () => wrapper.findAllComponents(GlFormGroup).at(1);
  const findNotifyOnSuccessCheckbox = () => wrapper.findByTestId('notify-on-success-checkbox');
  const findNotifyOnFailureCheckbox = () => wrapper.findByTestId('notify-on-failure-checkbox');
  const findForm = () => wrapper.findComponent(GlForm);
  const findButtons = () => wrapper.findAllComponents(GlButton);
  const findSaveButton = () => findButtons().at(0);
  const findCancelButton = () => findButtons().at(1);
  const findNextRunText = () => wrapper.findByTestId('cleanup-policy-next-run');

  const submitForm = () => findForm().vm.$emit('submit', { preventDefault: jest.fn() });

  const fillApolloCache = () => {
    apolloProvider.defaultClient.cache.writeQuery({
      query: getVirtualRegistriesCleanupPolicyDetails,
      variables: {
        fullPath: defaultProvide.groupPath,
      },
      ...groupVirtualRegistriesCleanupPolicyMock(),
    });
  };

  const createComponent = ({
    provide = defaultProvide,
    queryResponse = groupVirtualRegistriesCleanupPolicyMock(),
    mutationResponse = virtualRegistriesCleanupPolicyMutationMock(),
    queryError = null,
    mutationError = null,
  } = {}) => {
    if (queryError) {
      queryHandler = jest.fn().mockRejectedValue(queryError);
    } else {
      queryHandler = jest.fn().mockResolvedValue(queryResponse);
    }

    if (mutationError) {
      mutationHandler = jest.fn().mockRejectedValue(mutationError);
    } else {
      mutationHandler = jest.fn().mockResolvedValue(mutationResponse);
    }

    apolloProvider = createMockApollo([
      [getVirtualRegistriesCleanupPolicyDetails, queryHandler],
      [upsertVirtualRegistriesCleanupPolicy, mutationHandler],
    ]);

    wrapper = shallowMountExtended(VirtualRegistriesCleanupPolicyForm, {
      apolloProvider,
      provide: {
        ...provide,
      },
    });
  };

  describe('loading state', () => {
    it('shows loading icon while fetching policy', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('hides loading icon after policy is fetched', async () => {
      createComponent();
      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('does not render form while loading', () => {
      createComponent();

      expect(findForm().exists()).toBe(false);
    });

    it('renders form after loading completes', async () => {
      createComponent();
      await waitForPromises();

      expect(findForm().exists()).toBe(true);
    });
  });

  describe('when no existing policy', () => {
    beforeEach(async () => {
      createComponent({ queryResponse: groupVirtualRegistriesCleanupPolicyMock(null) });
      await waitForPromises();
    });

    it('renders form with default values', () => {
      expect(findEnableToggle().props('value')).toBe(false);
      expect(findCadenceSelect().attributes('value')).toBe('1');
      expect(findKeepNDaysInput().attributes('value')).toBe('7');
    });

    it('disables form fields when policy is not enabled', () => {
      expect(findCadenceSelect().attributes('disabled')).toBeDefined();
      expect(findKeepNDaysInput().attributes('disabled')).toBeDefined();
      expect(findNotifyOnSuccessCheckbox().attributes('disabled')).toBeDefined();
      expect(findNotifyOnFailureCheckbox().attributes('disabled')).toBeDefined();
    });

    it('shows "Not yet scheduled" for next run when disabled', () => {
      expect(findNextRunText().text()).toBe('Not yet scheduled');
    });

    it('save button is not in loading state', () => {
      expect(findSaveButton().props('loading')).toBe(false);
    });

    it('save button has type submit', () => {
      expect(findSaveButton().attributes('type')).toBe('submit');
    });
  });

  describe('when there is an existing policy', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('populates form with existing policy values', () => {
      expect(findEnableToggle().props('value')).toBe(true);
      expect(findCadenceSelect().attributes('value')).toBe('7');
      expect(findKeepNDaysInput().attributes('value')).toBe('30');
      expect(findNotifyOnSuccessCheckbox().attributes('checked')).toBeUndefined();
      expect(findNotifyOnFailureCheckbox().attributes('checked')).toBe('true');
      expect(findNextRunText().text()).toContain('December 15, 2025');
    });

    it('enables form fields when policy is enabled', () => {
      expect(findCadenceSelect().attributes('disabled')).toBeUndefined();
      expect(findKeepNDaysInput().attributes('disabled')).toBeUndefined();
    });

    it('save button is not in loading state', () => {
      expect(findSaveButton().props('loading')).toBe(false);
    });
  });

  describe('form validation', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('does not show validation error before blur', async () => {
      await findKeepNDaysInput().vm.$emit('input', 0);

      expect(findKeepNDaysFormGroup().attributes('invalid-feedback')).toBeUndefined();
    });

    it('shows error when keepNDaysAfterDownload is less than 1 after blur', async () => {
      await findKeepNDaysInput().vm.$emit('input', 0);
      await findKeepNDaysInput().vm.$emit('blur');

      expect(findKeepNDaysFormGroup().attributes('invalid-feedback')).toBe(
        'Must be at least 1 day.',
      );
    });

    it('shows error when keepNDaysAfterDownload is greater than 365 after blur', async () => {
      await findKeepNDaysInput().vm.$emit('input', 400);
      await findKeepNDaysInput().vm.$emit('blur');

      expect(findKeepNDaysFormGroup().attributes('invalid-feedback')).toBe(
        'Must be 365 days or less.',
      );
    });

    it('shows error when keepNDaysAfterDownload is not a whole number after blur', async () => {
      await findKeepNDaysInput().vm.$emit('input', 30.5);
      await findKeepNDaysInput().vm.$emit('blur');

      expect(findKeepNDaysFormGroup().attributes('invalid-feedback')).toBe(
        'Must be a whole number.',
      );
    });

    it('shows required error when keepNDaysAfterDownload is empty after blur', async () => {
      await findKeepNDaysInput().vm.$emit('input', '');
      await findKeepNDaysInput().vm.$emit('blur');

      expect(findKeepNDaysFormGroup().attributes('invalid-feedback')).toBe(
        'This field is required.',
      );
    });

    it('sets isFormValid to false when validation fails', async () => {
      await findKeepNDaysInput().vm.$emit('input', 0);

      expect(wrapper.vm.isFormValid).toBe(false);
    });

    it('prevents form submission when form is invalid', async () => {
      await findKeepNDaysInput().vm.$emit('input', 0);

      expect(wrapper.vm.isFormValid).toBe(false);

      submitForm();

      expect(wrapper.vm.isFormValid).toBe(false);
    });
  });

  describe('cancel button', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('redirects to settings page on cancel', async () => {
      await findCancelButton().vm.$emit('click');

      expect(visitUrl).toHaveBeenCalledWith(defaultProvide.settingsPath);
    });
  });

  describe('error handling', () => {
    it('shows error alert when query fails', async () => {
      createComponent({ queryError: new Error('Query failed') });
      await waitForPromises();

      expect(findAlert().props('variant')).toBe('danger');
      expect(findAlert().text()).toContain('Failed to load cleanup policy');
    });

    it('dismisses error alert when dismiss event is emitted', async () => {
      createComponent({ queryError: new Error('Query failed') });
      await waitForPromises();

      await findAlert().vm.$emit('dismiss');

      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('next run at', () => {
    beforeEach(() => {
      jest.useFakeTimers({ legacyFakeTimers: false });
      jest.setSystemTime(new Date('2025-01-15T12:00:00Z'));
    });

    afterEach(() => {
      jest.useFakeTimers({ legacyFakeTimers: true });
    });

    it('calculates nextRunAt from lastRunAt when cadence is changed', async () => {
      createComponent();
      await waitForPromises();

      findCadenceSelect().vm.$emit('input', 30);
      await findCadenceSelect().vm.$emit('change', 30);

      // lastRunAt (2025-12-01T10:00:00Z) + 30 days = 2025-12-31T10:00:00Z
      expect(findNextRunText().text()).toContain('December 31, 2025');
      expect(findNextRunText().text()).toContain('estimated cleanup time');
    });

    it('calculates nextRunAt from createdAt when policy has never run', async () => {
      createComponent({
        queryResponse: groupVirtualRegistriesCleanupPolicyMock({ lastRunAt: null }),
      });
      await waitForPromises();

      findCadenceSelect().vm.$emit('input', 30);
      await findCadenceSelect().vm.$emit('change', 30);

      // createdAt (2025-11-01T10:00:00Z) + 30 days = 2025-12-01T10:00:00Z
      expect(findNextRunText().text()).toContain('December 1, 2025');
      expect(findNextRunText().text()).toContain('estimated cleanup time');
    });

    it('calculates nextRunAt from current time when no policy exists', async () => {
      createComponent({ queryResponse: groupVirtualRegistriesCleanupPolicyMock(null) });
      await waitForPromises();

      await findEnableToggle().vm.$emit('change', true);
      findCadenceSelect().vm.$emit('input', 30);
      await findCadenceSelect().vm.$emit('change', 30);

      // System time (2025-01-15T12:00:00Z) + 30 days = 2025-02-14T12:00:00Z
      expect(findNextRunText().text()).toContain('February 14, 2025');
      expect(findNextRunText().text()).toContain('estimated cleanup time');
    });
  });

  describe('form submission', () => {
    describe('success state', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
        fillApolloCache();
      });

      it('calls mutation with correct variables', async () => {
        submitForm();
        await waitForPromises();

        expect(mutationHandler).toHaveBeenCalledWith({
          input: {
            fullPath: defaultProvide.groupPath,
            enabled: true,
            cadence: 7,
            keepNDaysAfterDownload: 30,
            notifyOnSuccess: false,
            notifyOnFailure: true,
          },
        });
      });

      it('redirects to settings page with success alert on success', async () => {
        submitForm();
        await waitForPromises();

        expect(visitUrlWithAlerts).toHaveBeenCalledWith(defaultProvide.settingsPath, [
          {
            id: 'virtual-registries-cleanup-policy-saved',
            message: 'Cleanup policy has been successfully saved.',
            variant: 'success',
          },
        ]);
      });
    });

    describe('error handling', () => {
      it('shows error alert when mutation returns errors', async () => {
        createComponent({
          mutationResponse: virtualRegistriesCleanupPolicyMutationMock({
            errors: ['Something went wrong'],
          }),
        });
        await waitForPromises();
        fillApolloCache();

        submitForm();
        await waitForPromises();

        expect(findAlert().text()).toContain('Something went wrong');
      });

      it('shows error alert when mutation fails with network error', async () => {
        createComponent({
          mutationError: new Error('Network error'),
        });
        await waitForPromises();
        fillApolloCache();

        submitForm();
        await waitForPromises();

        expect(findAlert().text()).toContain('Failed to save cleanup policy');
      });

      it('does not redirect when mutation fails', async () => {
        createComponent({
          mutationError: new Error('Network error'),
        });
        await waitForPromises();
        fillApolloCache();

        submitForm();
        await waitForPromises();

        expect(visitUrlWithAlerts).not.toHaveBeenCalled();
      });

      it('does not call mutation when form is invalid', async () => {
        createComponent();
        await waitForPromises();
        fillApolloCache();

        await findKeepNDaysInput().vm.$emit('input', 0);
        submitForm();
        await waitForPromises();

        expect(mutationHandler).not.toHaveBeenCalled();
      });
    });

    describe('with updated form values', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
        fillApolloCache();
      });

      it('sends updated values when form fields are changed', async () => {
        await findEnableToggle().vm.$emit('change', false);
        await findCadenceSelect().vm.$emit('input', 14);
        await findKeepNDaysInput().vm.$emit('input', 60);

        submitForm();
        await waitForPromises();

        expect(mutationHandler).toHaveBeenCalledWith({
          input: expect.objectContaining({
            enabled: false,
            cadence: 14,
            keepNDaysAfterDownload: 60,
          }),
        });
      });
    });
  });
});
