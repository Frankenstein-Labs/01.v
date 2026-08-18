import { GlToggle, GlFormTextarea, GlForm, GlLoadingIcon, GlModal } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import MaintenanceModeSettingsApp from 'ee/maintenance_mode_settings/components/app.vue';
import { updateApplicationSettings } from '~/rest_api';
import { createAlert } from '~/alert';

jest.mock('~/rest_api.js');
jest.mock('~/alert');

describe('MaintenanceModeSettingsApp', () => {
  let wrapper;

  const defaultProps = {
    initialBannerMessage: '',
    initialMaintenanceEnabled: false,
  };

  const createComponent = (props, mountFn = shallowMountExtended) => {
    wrapper = mountFn(MaintenanceModeSettingsApp, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findMaintenanceModeSettingsForm = () => wrapper.findComponent(GlForm);
  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findGlToggle = () => wrapper.findComponent(GlToggle);
  const findGlFormTextarea = () => wrapper.findComponent(GlFormTextarea);
  const findGlModal = () => wrapper.findComponent(GlModal);

  describe('when maintenance mode is enabled', () => {
    beforeEach(() => {
      createComponent({
        initialBannerMessage: 'test message',
        initialMaintenanceEnabled: true,
      });
    });

    it('renders the form and not loading icon', () => {
      expect(findGlLoadingIcon().exists()).toBe(false);
      expect(findMaintenanceModeSettingsForm().exists()).toBe(true);
    });

    it('sets the GlToggle to true', () => {
      expect(findGlToggle().attributes('value')).toBe('true');
    });

    it('renders and sets the GlFormTextarea to the banner message', () => {
      expect(findGlFormTextarea().attributes('value')).toBe('test message');
    });

    it('properly calls updateApplicationSettings when the form is updated and submitted', async () => {
      findGlFormTextarea().vm.$emit('input', '');
      findGlToggle().vm.$emit('change', false);
      await nextTick();

      findMaintenanceModeSettingsForm().vm.$emit('submit', { preventDefault: () => {} });
      await nextTick();

      expect(findGlLoadingIcon().exists()).toBe(true);
      expect(updateApplicationSettings).toHaveBeenCalledWith({
        maintenance_mode: false,
        maintenance_mode_message: '',
      });

      await waitForPromises();
      expect(findGlLoadingIcon().exists()).toBe(false);
    });
  });

  describe('when maintenance mode is disabled', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the form and not loading icon', () => {
      expect(findGlLoadingIcon().exists()).toBe(false);
      expect(findMaintenanceModeSettingsForm().exists()).toBe(true);
    });

    it('sets the GlToggle to undefined', () => {
      expect(findGlToggle().attributes('value')).toBeUndefined();
    });

    it('does not render the GlFormTextArea', () => {
      expect(findGlFormTextarea().exists()).toBe(false);
    });

    it('properly calls updateApplicationSettings when the form is updated and submitted', async () => {
      findGlToggle().vm.$emit('change', true);
      await nextTick();

      findGlFormTextarea().vm.$emit('input', 'test message');
      await nextTick();

      findMaintenanceModeSettingsForm().vm.$emit('submit', { preventDefault: () => {} });
      await nextTick();

      expect(findGlLoadingIcon().exists()).toBe(true);
      expect(updateApplicationSettings).toHaveBeenCalledWith({
        maintenance_mode: true,
        maintenance_mode_message: 'test message',
      });

      await waitForPromises();
      expect(findGlLoadingIcon().exists()).toBe(false);
    });
  });

  describe('when updating maintenance mode fails', () => {
    beforeEach(() => {
      updateApplicationSettings.mockImplementation(() => Promise.reject());
      createComponent();
    });

    it('sends a createAlert error', async () => {
      findMaintenanceModeSettingsForm().vm.$emit('submit', { preventDefault: () => {} });
      await nextTick();

      expect(findGlLoadingIcon().exists()).toBe(true);
      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error updating the Maintenance Mode Settings',
      });

      await waitForPromises();
      expect(findGlLoadingIcon().exists()).toBe(false);
    });
  });

  describe('when maintenance mode is disabled while a message exists', () => {
    beforeEach(async () => {
      createComponent({
        initialBannerMessage: 'test message',
        initialMaintenanceEnabled: true,
      });

      findGlToggle().vm.$emit('change', false);
      await nextTick();
    });

    it('does not change the toggle or textbox and shows a confirmation modal', () => {
      expect(findGlToggle().attributes('value')).toBe('true');
      expect(findGlFormTextarea().attributes('value')).toBe('test message');

      expect(findGlModal().props('visible')).toBe(true);
    });

    it('does not change toggle or textbox if user cancels modal', async () => {
      findGlModal().vm.$emit('change', false);
      await nextTick();

      expect(findGlToggle().attributes('value')).toBe('true');
      expect(findGlFormTextarea().attributes('value')).toBe('test message');
    });

    it('changes toggle to false and hides the GlFormTextbox if user confirms modal', async () => {
      findGlModal().vm.$emit('primary');
      await nextTick();

      expect(findGlToggle().attributes('value')).toBeUndefined();
      expect(findGlFormTextarea().exists()).toBe(false);
    });
  });

  describe('when updating the banner text', () => {
    beforeEach(() => {
      createComponent(
        {
          initialBannerMessage: '',
          initialMaintenanceEnabled: true,
        },
        mountExtended,
      );
    });

    it('when empty the character count reads 255 characters remaining.', () => {
      expect(wrapper.findByText('255 characters remaining.').exists()).toBe(true);
    });

    it('when exactly 255 characters the character counter reads 0 characters remaining.', async () => {
      findGlFormTextarea().vm.$emit('input', 'a'.repeat(255));
      await nextTick();

      expect(wrapper.findByText('0 characters remaining.').exists()).toBe(true);
    });

    it('when 1 character over 255 characters the character counter reads 1 character over limit.', async () => {
      findGlFormTextarea().vm.$emit('input', 'a'.repeat(256));
      await nextTick();

      expect(wrapper.findByText('1 character over limit.').exists()).toBe(true);
    });
  });
});
