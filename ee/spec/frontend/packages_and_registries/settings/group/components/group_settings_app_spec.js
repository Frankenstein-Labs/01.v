import { shallowMount } from '@vue/test-utils';

import VirtualRegistriesSetting from 'ee_component/packages_and_registries/settings/group/components/virtual_registries_setting.vue';
import GroupSettingsApp from 'ee_component/packages_and_registries/settings/group/components/group_settings_app.vue';
import CeGroupSettingsApp from '~/packages_and_registries/settings/group/components/group_settings_app.vue';

describe('EE Group Settings App', () => {
  let wrapper;
  let handleSuccessMock;
  let handleErrorMock;

  const mountComponent = ({ shouldRenderVirtualRegistriesSetting = true } = {}) => {
    handleSuccessMock = jest.fn();
    handleErrorMock = jest.fn();

    wrapper = shallowMount(GroupSettingsApp, {
      provide: {
        shouldRenderVirtualRegistriesSetting,
      },
      stubs: {
        CeGroupSettingsApp: {
          template: `
            <div>
              <slot name="virtual-registries-setting" :handle-success="handleSuccess" :handle-error="handleError" />
            </div>
          `,
          methods: {
            handleSuccess: handleSuccessMock,
            handleError: handleErrorMock,
          },
        },
      },
    });
  };

  const findBaseSettingsComponent = () => wrapper.findComponent(CeGroupSettingsApp);
  const findVirtualRegistriesSetting = () => wrapper.findComponent(VirtualRegistriesSetting);

  it('renders the base group settings component', () => {
    mountComponent();

    expect(findBaseSettingsComponent().exists()).toBe(true);
  });

  describe('virtual registries setting component', () => {
    beforeEach(() => {
      mountComponent();
    });

    it('renders the setting', () => {
      expect(findVirtualRegistriesSetting().exists()).toBe(true);
    });

    it('has the correct id', () => {
      expect(findVirtualRegistriesSetting().attributes('id')).toBe('virtual-registries-setting');
    });

    it('calls handleSuccess when success event is emitted', () => {
      findVirtualRegistriesSetting().vm.$emit('success');

      expect(handleSuccessMock).toHaveBeenCalledTimes(1);
    });

    it('calls handleError when error event is emitted', () => {
      findVirtualRegistriesSetting().vm.$emit('error');

      expect(handleErrorMock).toHaveBeenCalledTimes(1);
    });
  });

  describe('when shouldRenderVirtualRegistriesSetting is false', () => {
    beforeEach(() => {
      mountComponent({ shouldRenderVirtualRegistriesSetting: false });
    });

    it('does not render the virtual registries setting section', () => {
      expect(findVirtualRegistriesSetting().exists()).toBe(false);
    });
  });
});
