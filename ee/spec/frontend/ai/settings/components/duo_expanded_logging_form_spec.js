import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import DuoExpandedLoggingForm from 'ee/ai/settings/components/duo_expanded_logging_form.vue';

describe('DuoExpandedLoggingForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, injectedProps = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(DuoExpandedLoggingForm, {
        provide: {
          ...injectedProps,
        },
        propsData: {
          ...props,
        },
        stubs: {
          GlFormCheckbox,
        },
      }),
    );
  };

  beforeEach(() => {
    createComponent({ injectedProps: { enabledExpandedLogging: true } });
  });

  const findTitle = () => wrapper.find('h5').text();
  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);

  it('has the correct title', () => {
    expect(findTitle()).toBe('Enable AI logs');
  });

  it('has the correct label', () => {
    expect(findCheckbox().text()).toContain(
      'Capture detailed information about AI-related activities and requests.',
    );
  });

  describe('when expanded AI logs have been enabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { enabledExpandedLogging: true } });
    });

    it('renders the checkbox checked', () => {
      expect(findCheckbox().props('checked')).toBe(true);
    });
  });

  it('disables the checkbox when disabledCheckbox prop is true', () => {
    createComponent({
      injectedProps: { enabledExpandedLogging: true },
      props: { disabledCheckbox: true },
    });

    expect(findCheckbox().props('disabled')).toBe(true);
  });

  it('does not disable the checkbox when disabledCheckbox prop is false', () => {
    createComponent({
      injectedProps: { enabledExpandedLogging: true },
      props: { disabledCheckbox: false },
    });

    expect(findCheckbox().props('disabled')).toBe(false);
  });

  describe('when expanded AI logs have not been enabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { enabledExpandedLogging: false } });
    });

    it('renders the checkbox unchecked', () => {
      expect(findCheckbox().props('checked')).toBe(false);
    });
  });
});
