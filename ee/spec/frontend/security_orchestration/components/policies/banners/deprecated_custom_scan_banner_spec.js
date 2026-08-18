import { GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DeprecatedCustomScanBanner from 'ee/security_orchestration/components/policies/banners/deprecated_custom_scan_banner.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';

const HELP_PATH = '/help/user/application_security/policies/pipeline_execution_policies';

describe('DeprecatedCustomScanBanner', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(DeprecatedCustomScanBanner, {
      stubs: {
        GlAlert,
        GlSprintf,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);
  const findAllLinks = () => wrapper.findAllComponents(GlLink);

  beforeEach(() => {
    createComponent();
  });

  it('renders alert info with message', () => {
    expect(findLocalStorageSync().exists()).toBe(true);
    expect(findAlert().exists()).toBe(true);
    expect(findAlert().props('title')).toContain('Custom scan experiment has ended in 17.3');

    expect(findAllLinks().at(0).attributes('href')).toBe(HELP_PATH);

    expect(wrapper.emitted('dismiss')).toEqual([[false]]);
  });

  it('dismisses the alert', async () => {
    await findAlert().vm.$emit('dismiss');

    expect(findAlert().exists()).toBe(false);
    expect(wrapper.emitted('dismiss')).toEqual([[false], [true]]);
  });
});
