import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import NoLongerDetectedVulnerabilitiesAlert from 'ee/security_dashboard/components/shared/no_longer_detected_vulnerabilities_alert.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';

describe('No longer detected vulnerabilities alert component', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(NoLongerDetectedVulnerabilitiesAlert);
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);

  it('displays the alert', () => {
    createComponent();

    expect(findAlert().exists()).toBe(true);
    expect(findAlert().props('variant')).toBe('info');
    expect(findAlert().text()).toBe(
      'In GitLab 19.2 and later, vulnerabilities that are no longer detected are excluded from vulnerability counts in the security dashboard.',
    );
  });

  it('persists the dismissed state to local storage', () => {
    createComponent();

    expect(findLocalStorageSync().props('storageKey')).toBe(
      'security_dashboard_no_longer_detected_vulnerabilities_alert_dismissed',
    );
    expect(findLocalStorageSync().props('value')).toBe(false);
  });

  it('hides the alert once dismissed', async () => {
    createComponent();

    findAlert().vm.$emit('dismiss');
    await nextTick();

    expect(findAlert().exists()).toBe(false);
    expect(findLocalStorageSync().props('value')).toBe(true);
  });

  it('hides the alert when local storage reports it was previously dismissed', async () => {
    createComponent();

    findLocalStorageSync().vm.$emit('input', true);
    await nextTick();

    expect(findAlert().exists()).toBe(false);
  });
});
