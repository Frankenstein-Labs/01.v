import { GlAlert, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ExceedingActionsBanner from 'ee/security_orchestration/components/policies/banners/exceeding_actions_banner.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';

describe('BreakingChangesBanner', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(ExceedingActionsBanner, {
      provide: {
        maxScanExecutionPolicyActions: 10,
      },
      stubs: {
        GlAlert,
        GlSprintf,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);

  beforeEach(() => {
    createComponent();
  });

  it('renders alert info with message', () => {
    expect(findLocalStorageSync().exists()).toBe(true);
    expect(findAlert().exists()).toBe(true);
    expect(findAlert().props('title')).toContain(
      'Maximum action limit for scan execution policies exceeded',
    );

    expect(wrapper.emitted('dismiss')).toEqual([[false]]);
  });

  it('dismisses the alert', async () => {
    await findAlert().vm.$emit('dismiss');

    expect(findAlert().exists()).toBe(false);
    expect(wrapper.emitted('dismiss')).toEqual([[false], [true]]);
  });
});
