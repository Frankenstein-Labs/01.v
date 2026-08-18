import { GlIcon, GlPopover, GlLink, GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PrivateProfileRestrictions from 'ee/admin/application_settings/user_restrictions/components/private_profile_restrictions.vue';
import {
  PRIVATE_PROFILES_DISABLED_ICON,
  PRIVATE_PROFILES_DISABLED_HELP_LINK,
} from 'ee/admin/application_settings/user_restrictions/constants';

describe('PrivateProfileRestrictions', () => {
  let wrapper;

  const defaultProps = {
    defaultToPrivateProfiles: {
      id: 'defaultToPrivateProfiles',
      name: 'defaultToPrivateProfiles',
      value: 'false',
    },
    allowPrivateProfiles: {
      id: 'allowPrivateProfiles',
      name: 'allowPrivateProfiles',
      value: 'true',
    },
  };

  const createComponent = ({ props = {}, licensedFeatures = {} } = {}) => {
    wrapper = shallowMountExtended(PrivateProfileRestrictions, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        glLicensedFeatures: {
          disablePrivateProfiles: true,
          ...licensedFeatures,
        },
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findDefaultToPrivateProfilesHiddenField = () =>
    wrapper.findByTestId(`${defaultProps.defaultToPrivateProfiles.id}-hidden`);
  const findDefaultToPrivateProfilesCheckbox = () =>
    wrapper.findByTestId(defaultProps.defaultToPrivateProfiles.id);
  const findAllowPrivateProfilesHiddenField = () =>
    wrapper.findByTestId(`${defaultProps.allowPrivateProfiles.id}-hidden`);
  const findAllowPrivateProfilesCheckbox = () =>
    wrapper.findComponentByTestId(defaultProps.allowPrivateProfiles.id);

  const findDisabledLockIcon = () => wrapper.findComponent(GlIcon);
  const findDisabledPopover = () => wrapper.findComponent(GlPopover);
  const findDisabledHelpLink = () => wrapper.findComponent(GlLink);

  describe('template', () => {
    describe('when feature is enabled', () => {
      describe('with allowPrivateProfiles set to true', () => {
        beforeEach(() => {
          createComponent({
            props: {
              allowPrivateProfiles: {
                ...defaultProps.allowPrivateProfiles,
                value: 'true',
              },
            },
          });
        });

        it('renders all fields', () => {
          expect(findDefaultToPrivateProfilesHiddenField().exists()).toBe(true);
          expect(findDefaultToPrivateProfilesCheckbox().exists()).toBe(true);
          expect(findAllowPrivateProfilesHiddenField().exists()).toBe(true);
          expect(findAllowPrivateProfilesCheckbox().exists()).toBe(true);
        });

        it('does not disable the defaultToPrivateProfiles checkbox', () => {
          expect(findDefaultToPrivateProfilesCheckbox().attributes('disabled')).toBeUndefined();
        });

        it('does not render disabled icon, popover, or help text', () => {
          expect(findDisabledLockIcon().exists()).toBe(false);
          expect(findDisabledPopover().exists()).toBe(false);
          expect(findDisabledHelpLink().exists()).toBe(false);
        });
      });

      describe('with allowPrivateProfiles set to false', () => {
        beforeEach(() => {
          createComponent({
            props: {
              allowPrivateProfiles: {
                ...defaultProps.allowPrivateProfiles,
                value: 'false',
              },
            },
          });
        });

        it('renders all fields', () => {
          expect(findDefaultToPrivateProfilesHiddenField().exists()).toBe(true);
          expect(findDefaultToPrivateProfilesCheckbox().exists()).toBe(true);
          expect(findAllowPrivateProfilesHiddenField().exists()).toBe(true);
          expect(findAllowPrivateProfilesCheckbox().exists()).toBe(true);
        });

        it('does disable the defaultToPrivateProfiles checkbox', () => {
          expect(findDefaultToPrivateProfilesCheckbox().attributes().disabled).toBe('true');
        });

        it('does render disabled icon, popover, or help text', () => {
          expect(findDisabledLockIcon().attributes('id')).toBe(PRIVATE_PROFILES_DISABLED_ICON);
          expect(findDisabledPopover().text()).toContain(
            'The option to make profiles private has been disabled.',
          );
          expect(findDisabledHelpLink().attributes('href')).toBe(
            PRIVATE_PROFILES_DISABLED_HELP_LINK,
          );
        });
      });
    });

    describe('when feature is disabled', () => {
      beforeEach(() => {
        createComponent({
          props: {
            allowPrivateProfiles: {
              ...defaultProps.allowPrivateProfiles,
              value: 'false',
            },
          },
          licensedFeatures: {
            disablePrivateProfiles: false,
          },
        });
      });

      it('does not render allowPrivateProfiles checkbox', () => {
        expect(findDefaultToPrivateProfilesHiddenField().exists()).toBe(true);
        expect(findDefaultToPrivateProfilesCheckbox().exists()).toBe(true);
        expect(findAllowPrivateProfilesHiddenField().exists()).toBe(false);
        expect(findAllowPrivateProfilesCheckbox().exists()).toBe(false);
      });

      it('does not disable the defaultToPrivateProfiles checkbox', () => {
        expect(findDefaultToPrivateProfilesCheckbox().attributes('disabled')).toBeUndefined();
      });

      it('does not render disabled icon, popover, or help text', () => {
        expect(findDisabledLockIcon().exists()).toBe(false);
        expect(findDisabledPopover().exists()).toBe(false);
        expect(findDisabledHelpLink().exists()).toBe(false);
      });
    });
  });

  describe('onMount', () => {
    beforeEach(() => {
      createComponent();
    });

    it('properly assigns HAML Boolean-String to model', () => {
      expect(findDefaultToPrivateProfilesCheckbox().attributes('checked')).toBeUndefined();
      expect(findAllowPrivateProfilesCheckbox().attributes('checked')).toBe('true');
    });
  });

  describe('events', () => {
    describe('when feature is enabled and both fields are checked', () => {
      beforeEach(() => {
        createComponent({
          props: {
            defaultToPrivateProfiles: {
              ...defaultProps.defaultToPrivateProfiles,
              value: 'true',
            },
            allowPrivateProfiles: {
              ...defaultProps.allowPrivateProfiles,
              value: 'true',
            },
          },
        });
      });

      it('by default, field is not disabled and no disabled elements exist', () => {
        expect(findDefaultToPrivateProfilesCheckbox().attributes('disabled')).toBeUndefined();
        expect(findDisabledLockIcon().exists()).toBe(false);
        expect(findDisabledPopover().exists()).toBe(false);
        expect(findDisabledHelpLink().exists()).toBe(false);
      });

      it('when allowPrivateProfiles is updated to false, defaultToPrivateProfiles is also disabled and set to false', async () => {
        expect(findDefaultToPrivateProfilesCheckbox().attributes('checked')).toBe('true');

        findAllowPrivateProfilesCheckbox().vm.$emit('input', false);
        await nextTick();

        expect(findDefaultToPrivateProfilesCheckbox().attributes('checked')).toBeUndefined();
        expect(findDefaultToPrivateProfilesCheckbox().attributes().disabled).toBe('true');
        expect(findDisabledLockIcon().exists()).toBe(true);
        expect(findDisabledPopover().exists()).toBe(true);
        expect(findDisabledHelpLink().exists()).toBe(true);
      });
    });
  });
});
