import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecretsManagerSettings from 'ee_component/pages/projects/shared/permissions/secrets_manager/secrets_manager_settings.vue';
import settingsPanel from '~/pages/projects/shared/permissions/components/settings_panel.vue';

const defaultProps = {
  currentSettings: {
    showDefaultAwardEmojis: true,
  },
  canAddCatalogResource: false,
  confirmationPhrase: 'my-fake-project',
  membersPagePath: '/my-fake-project/-/project_members',
  topLevelGroupFullPath: 'my-fake-root-group',
};

describe('Settings Panel', () => {
  let wrapper;

  const mountComponent = ({ ...customProps } = {}) => {
    const propsData = {
      ...defaultProps,
      ...customProps,
      currentSettings: { ...defaultProps.currentSettings },
    };

    return shallowMountExtended(settingsPanel, {
      propsData,
      provide: {
        cascadingSettingsData: {},
      },
    });
  };

  const findSecretsManagerSettings = () => wrapper.findComponent(SecretsManagerSettings);

  describe('Secrets Manager Settings', () => {
    it('does not render the secrets manager when feature is not licensed', () => {
      wrapper = mountComponent({ isSecretsManagerAvailable: false });

      expect(findSecretsManagerSettings().exists()).toBe(false);
    });

    it('renders the secrets manager when feature is licensed', () => {
      wrapper = mountComponent({ isSecretsManagerAvailable: true });

      expect(findSecretsManagerSettings().exists()).toBe(true);
    });

    it('passes the correct props', () => {
      wrapper = mountComponent({ canManageSecretsManager: true, isSecretsManagerAvailable: true });

      expect(findSecretsManagerSettings().props()).toMatchObject({
        canManageSecretsManager: true,
        fullPath: 'my-fake-project',
        topLevelGroupFullPath: 'my-fake-root-group',
      });
    });
  });
});
