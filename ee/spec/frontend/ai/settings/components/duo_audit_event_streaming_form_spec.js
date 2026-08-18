import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox } from '@gitlab/ui';
import { nextTick } from 'vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import DuoAuditEventStreamingForm from 'ee/ai/settings/components/duo_audit_event_streaming_form.vue';

describe('DuoAuditEventStreamingForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, injectedProps = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(DuoAuditEventStreamingForm, {
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
    createComponent({ injectedProps: { aiAuditEventsStreamingEnabled: false } });
  });

  const findTitle = () => wrapper.find('h5').text();
  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);

  it('has the correct title', () => {
    expect(findTitle()).toBe('Enable AI audit event streaming');
  });

  it('has a label that calls out that events are still recorded when the toggle is off', () => {
    expect(findCheckbox().text()).toContain(
      'Stream AI audit events to configured external audit event streaming destinations. AI audit events are still saved to the database when this setting is off.',
    );
  });

  describe('when AI audit event streaming is enabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { aiAuditEventsStreamingEnabled: true } });
    });

    it('renders the checkbox checked', () => {
      expect(findCheckbox().props('checked')).toBe(true);
    });
  });

  describe('when AI audit event streaming is disabled (default)', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { aiAuditEventsStreamingEnabled: false } });
    });

    it('renders the checkbox unchecked', () => {
      expect(findCheckbox().props('checked')).toBe(false);
    });
  });

  it('disables the checkbox when disabledCheckbox prop is true', () => {
    createComponent({
      injectedProps: { aiAuditEventsStreamingEnabled: false },
      props: { disabledCheckbox: true },
    });

    expect(findCheckbox().props('disabled')).toBe(true);
  });

  it('does not disable the checkbox when disabledCheckbox prop is false', () => {
    createComponent({
      injectedProps: { aiAuditEventsStreamingEnabled: false },
      props: { disabledCheckbox: false },
    });

    expect(findCheckbox().props('disabled')).toBe(false);
  });

  it('emits the change event with the new value when the checkbox toggles', async () => {
    createComponent({ injectedProps: { aiAuditEventsStreamingEnabled: false } });

    findCheckbox().vm.$emit('input', true);
    await nextTick();
    findCheckbox().vm.$emit('change', true);

    expect(wrapper.emitted('change')).toHaveLength(1);
    expect(wrapper.emitted('change').at(-1)).toEqual([true]);
  });
});
