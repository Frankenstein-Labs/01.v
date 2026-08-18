import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlFormRadioGroup } from '@gitlab/ui';

import AllowedIntegrations from 'ee/pages/admin/application_settings/general/components/allowed_integrations.vue';

describe('AllowedIntegrations', () => {
  let wrapper;

  const mockIntegrations = [
    { name: 'asana', title: 'Asana' },
    { name: 'jira', title: 'Jira' },
    { name: 'slack', title: 'Slack' },
  ];
  const defaultProps = {
    integrations: mockIntegrations,
  };
  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(AllowedIntegrations, {
      propsData: { ...props, ...defaultProps },
    });
  };

  const findAllCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findAllowAllIntegrationsInput = () =>
    wrapper.find('input[name="application_setting[allow_all_integrations]"]');
  const findAllowedIntegrationsInput = () =>
    wrapper.find('input[name="application_setting[allowed_integrations_raw]"]');

  it('renders radio group', () => {
    createComponent();

    expect(findRadioGroup().exists()).toBe(true);
  });

  describe('when allow_all_integrations is true', () => {
    beforeEach(() => {
      createComponent({
        props: {
          initialAllowAllIntegrations: true,
        },
      });
    });

    it('passes correct value to hidden input', () => {
      expect(findAllowAllIntegrationsInput().attributes('value')).toBe('true');
    });

    it('does not render a list of integrations', () => {
      expect(findAllCheckboxes()).toHaveLength(0);
    });
  });

  describe('when allow_all_integrations is false', () => {
    beforeEach(() => {
      createComponent({
        props: {
          initialAllowAllIntegrations: false,
          initialAllowedIntegrations: ['jira'],
        },
      });
    });

    it('passes correct value to hidden input', () => {
      expect(findAllowAllIntegrationsInput().attributes('value')).toBe('false');
    });

    it('renders a list of integrations', () => {
      expect(findAllCheckboxes()).toHaveLength(mockIntegrations.length);
    });

    it('passes allowedIntegrations to hidden input', () => {
      expect(findAllowedIntegrationsInput().attributes('value')).toBe('["jira"]');
    });

    describe('when selecting more integrations', () => {
      it('updates allowedIntegrations hidden input', async () => {
        await findAllCheckboxes().at(0).vm.$emit('input', ['asana', 'jira']);

        expect(findAllowedIntegrationsInput().attributes('value')).toBe('["asana","jira"]');
      });
    });
  });
});
