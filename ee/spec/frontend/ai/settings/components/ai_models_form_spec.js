import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlSprintf } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import AiModelsForm from 'ee/ai/settings/components/ai_models_form.vue';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';

describe('AiModelsForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, injectedProps = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(AiModelsForm, {
        provide: {
          ...injectedProps,
        },
        propsData: {
          ...props,
        },
        stubs: {
          GlFormCheckbox,
          GlSprintf,
        },
      }),
    );
  };

  beforeEach(() => {
    createComponent({ injectedProps: { betaSelfHostedModelsEnabled: true } });
  });

  const findTitle = () => wrapper.find('h3').text();
  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findCheckboxLabel = () => wrapper.findByTestId('label');
  const findCheckboxHelpText = () => wrapper.find('.help-text');
  const findTestingAgreementLink = () => wrapper.findComponent(PromoPageLink);

  it('has the correct title', () => {
    expect(findTitle()).toBe('Self-hosted beta models and features');
  });

  it('has the correct label', () => {
    expect(findCheckboxLabel().text()).toBe(
      'Use beta models and features in GitLab Duo Self-Hosted',
    );
  });

  describe('help text', () => {
    it('renders the correct text', () => {
      expect(findCheckboxHelpText().text().replace(/\s+/g, ' ')).toMatch(
        'Enabling self-hosted beta models and features is your acceptance of the GitLab Testing Agreement',
      );
    });

    it('links to the testing agreement', () => {
      expect(findTestingAgreementLink().attributes('path')).toBe(
        '/handbook/legal/testing-agreement/',
      );
    });
  });

  describe('when beta self-hosted models have been enabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { betaSelfHostedModelsEnabled: true } });
    });

    it('renders the checkbox checked', () => {
      expect(findCheckbox().props('checked')).toBe(true);
    });
  });

  describe('when beta self-hosted models have not been enabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { betaSelfHostedModelsEnabled: false } });
    });

    it('renders the checkbox unchecked', () => {
      expect(findCheckbox().attributes('checked')).toBeUndefined();
    });
  });
});
