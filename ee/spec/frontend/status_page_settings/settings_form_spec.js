// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import StatusPageSettingsForm from 'ee/status_page_settings/components/settings_form.vue';
import createStore from 'ee/status_page_settings/store';

describe('Status Page settings form', () => {
  let wrapper;
  const { state } = createStore();
  const updateStatusPageSettingsSpy = jest.fn();

  const fakeStore = () => {
    return new Vuex.Store({
      state,
      actions: {
        updateStatusPageSettings: updateStatusPageSettingsSpy,
      },
    });
  };

  const findForm = () => wrapper.findComponent({ ref: 'settingsForm' });
  const findToggleButton = () => wrapper.findByTestId('settings-block-toggle');
  const findSectionHeader = () => wrapper.findByTestId('settings-block-title');
  const findSectionSubHeader = () => wrapper.findComponent({ ref: 'sectionSubHeader' });

  beforeEach(() => {
    wrapper = shallowMountExtended(StatusPageSettingsForm, {
      store: fakeStore(),
      stubs: { SettingsBlock },
    });
  });

  describe('default state', () => {
    it('should match the default snapshot', () => {
      // Transform snapshot for Vue2 compatibility
      expect(wrapper.html().replace(/ison=/g, 'is-on=')).toMatchSnapshot();
    });
  });

  it('renders header text', () => {
    expect(findSectionHeader().text()).toBe('Status page');
  });

  describe('expand/collapse button', () => {
    it('renders as an expand button by default', () => {
      expect(findToggleButton().attributes('aria-label')).toContain('Expand');
    });
  });

  describe('sub-header', () => {
    it('renders descriptive text', () => {
      expect(findSectionSubHeader().text()).toContain(
        'Configure file storage settings to link issues in this project to an external status page.',
      );
    });
  });

  describe('form', () => {
    describe('submit button', () => {
      it('submits form on click', () => {
        findForm().trigger('submit');
        expect(updateStatusPageSettingsSpy).toHaveBeenCalled();
      });
    });
  });
});
