import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoConfigurationSettingsRow from 'ee/ai/settings/components/duo_configuration_settings_row.vue';

describe('DuoConfigurationSettingsRow', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DuoConfigurationSettingsRow, {
      propsData: {
        duoConfigurationSettingsRowTypeTitle: 'Duo Row Title',
        configValue: false,
        ...props,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findConfigurationTitle = () => wrapper.findByTestId('duo-configuration-row-title');
  const findConfigurationRowValue = () => wrapper.findByTestId('duo-configuration-row-value');

  describe('component rendering', () => {
    it('renders the title correctly', () => {
      createComponent();

      expect(findConfigurationTitle().text()).toBe('Duo Row Title');
    });

    describe('boolean values', () => {
      describe('when config is enabled', () => {
        beforeEach(() => {
          createComponent({ configValue: true });
        });

        it('displays the enabled text', () => {
          expect(findConfigurationRowValue().text()).toBe('Enabled');
        });

        it('renders the check icon', () => {
          expect(findIcon().exists()).toBe(true);
        });
      });

      describe('when config is disabled', () => {
        beforeEach(() => {
          createComponent({ configValue: false });
        });

        it('displays the disabled text', () => {
          expect(findConfigurationRowValue().text()).toBe('Not enabled');
        });

        it('does not render the check icon', () => {
          expect(findIcon().exists()).toBe(false);
        });
      });
    });

    describe('when config value is a string', () => {
      beforeEach(() => {
        createComponent({ configValue: 'config value' });
      });

      it('displays the string value', () => {
        expect(findConfigurationRowValue().text()).toBe('config value');
      });

      it('does not render the check icon', () => {
        expect(findIcon().exists()).toBe(false);
      });
    });
  });
});
