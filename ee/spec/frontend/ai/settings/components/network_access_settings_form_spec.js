import { GlFormGroup, GlFormCheckbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NetworkAccessSettingsForm from 'ee/ai/settings/components/network_access_settings_form.vue';

describe('NetworkAccessSettingsForm', () => {
  let wrapper;

  const defaultProps = {
    includeRecommendedAllowedDomains: false,
    allowAllUnixSockets: false,
    allowProjectExtension: true,
    disabledCheckbox: false,
  };

  const createComponent = ({ props = {} } = {}) => {
    return shallowMountExtended(NetworkAccessSettingsForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlFormGroup,
      },
    });
  };

  const findAllCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);
  const findIncludeRecommendedDomainsCheckbox = () =>
    wrapper.findComponentByTestId('include-recommended-allowed-domains-checkbox');
  const findAllowUnixSocketsCheckbox = () =>
    wrapper.findComponentByTestId('allow-all-unix-sockets-checkbox');
  const findAllowProjectExtensionCheckbox = () =>
    wrapper.findComponentByTestId('allow-project-extension-checkbox');

  beforeEach(() => {
    wrapper = createComponent();
  });

  it('renders the section title', () => {
    expect(wrapper.text()).toContain('Network access controls');
  });

  it('renders the section description', () => {
    expect(wrapper.text()).toContain(
      'Control which external network resources the GitLab Duo Agent Platform can access.',
    );
  });

  it('renders all three checkboxes', () => {
    expect(findAllCheckboxes()).toHaveLength(3);
  });

  describe('initial checkbox states', () => {
    it('sets include recommended allowed domains to unchecked by default', () => {
      expect(findIncludeRecommendedDomainsCheckbox().props('checked')).toBe(false);
    });

    it('sets allow project extension to checked by default', () => {
      expect(findAllowProjectExtensionCheckbox().props('checked')).toBe(true);
    });
  });

  describe('emitting events', () => {
    it('emits include-recommended-allowed-domains-changed when checkbox is toggled', () => {
      expect(wrapper.emitted('include-recommended-allowed-domains-changed')).toBeUndefined();

      findIncludeRecommendedDomainsCheckbox().vm.$emit('change', true);

      expect(wrapper.emitted('include-recommended-allowed-domains-changed')).toHaveLength(1);
      expect(wrapper.emitted('include-recommended-allowed-domains-changed')[0]).toEqual([true]);
    });

    it('emits allow-all-unix-sockets-changed when checkbox is toggled', () => {
      expect(wrapper.emitted('allow-all-unix-sockets-changed')).toBeUndefined();

      findAllowUnixSocketsCheckbox().vm.$emit('change', true);

      expect(wrapper.emitted('allow-all-unix-sockets-changed')).toHaveLength(1);
      expect(wrapper.emitted('allow-all-unix-sockets-changed')[0]).toEqual([true]);
    });

    it('emits allow-project-extension-changed when checkbox is toggled', () => {
      expect(wrapper.emitted('allow-project-extension-changed')).toBeUndefined();

      findAllowProjectExtensionCheckbox().vm.$emit('change', false);

      expect(wrapper.emitted('allow-project-extension-changed')).toHaveLength(1);
      expect(wrapper.emitted('allow-project-extension-changed')[0]).toEqual([false]);
    });
  });

  describe('when checkboxes are disabled', () => {
    beforeEach(() => {
      wrapper = createComponent({ props: { disabledCheckbox: true } });
    });

    it('disables all checkboxes', () => {
      findAllCheckboxes().wrappers.forEach((checkbox) => {
        expect(checkbox.props('disabled')).toBe(true);
      });
    });
  });

  describe('checkbox labels', () => {
    it('renders include recommended domains label', () => {
      expect(findIncludeRecommendedDomainsCheckbox().text()).toContain(
        'Include recommended domains in the allowlist',
      );
    });

    it('renders allow all unix sockets label', () => {
      expect(findAllowUnixSocketsCheckbox().text()).toContain('Allow all Unix sockets');
    });

    it('renders allow project extension label', () => {
      expect(findAllowProjectExtensionCheckbox().text()).toContain(
        'Allow projects to extend network sandbox settings',
      );
    });
  });
});
