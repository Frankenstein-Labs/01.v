import { shallowMount } from '@vue/test-utils';
import { GlFormRadioGroup, GlFormInput, GlFormGroup } from '@gitlab/ui';
import DuoChatHistoryExpirationForm from 'ee/ai/settings/components/duo_chat_history_expiration.vue';

describe('DuoChatHistoryExpirationForm', () => {
  let wrapper;

  const createComponent = (provide = {}) => {
    return shallowMount(DuoChatHistoryExpirationForm, {
      provide: {
        duoChatExpirationDays: 30,
        duoChatExpirationColumn: 'created_at',
        ...provide,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findFormInput = () => wrapper.findComponent(GlFormInput);
  const findFormRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findDaysText = () => wrapper.find('span');

  describe('component rendering', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('renders the form group with correct title and description', () => {
      expect(findFormGroup().attributes('label')).toBe('GitLab Duo Chat conversations');
      expect(findFormGroup().props('labelDescription')).toBe('Chat conversations expire:');
    });

    it('renders the days input with correct attributes', () => {
      const input = findFormInput();
      expect(input.exists()).toBe(true);
      expect(input.attributes('id')).toBe('history-expiration-days');
      expect(input.attributes('type')).toBe('number');
      expect(input.attributes('min')).toBe('1');
      expect(input.attributes('max')).toBe('30');
      expect(input.props('width')).toBe('xs');
    });

    it('renders the days label with correct text', () => {
      expect(findDaysText().text()).toBe('days');
    });

    it('renders the expiration column radio group with correct options', () => {
      const radioGroup = findFormRadioGroup();
      expect(radioGroup.exists()).toBe(true);
      expect(radioGroup.props('options')).toEqual([
        {
          text: 'After the conversation was last updated',
          value: 'last_updated_at',
        },
        {
          text: 'After the conversation was created',
          value: 'created_at',
        },
      ]);
    });
  });

  describe('initial values', () => {
    it('initializes with injected values', () => {
      wrapper = createComponent({
        duoChatExpirationDays: 15,
        duoChatExpirationColumn: 'last_updated_at',
      });

      expect(findFormInput().props('value')).toBe(15);
      expect(findFormRadioGroup().attributes('checked')).toBe('last_updated_at');
    });
  });

  describe('computed properties', () => {
    it('displays singular form when days is 1', () => {
      wrapper = createComponent({ duoChatExpirationDays: 1 });
      expect(findDaysText().text()).toBe('day');
    });

    it('displays plural form when days is greater than 1', () => {
      wrapper = createComponent({ duoChatExpirationDays: 2 });
      expect(findDaysText().text()).toBe('days');
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('emits the `change-expiration-days` event when days input changes correctly as a number', () => {
      findFormInput().vm.$emit('change', '20');
      expect(wrapper.emitted('change-expiration-days')[0][0]).toBe(20);
    });

    it('emits the `change-expiration-column` event when radio selection changes', () => {
      findFormRadioGroup().vm.$emit('change', 'changed_at');
      expect(wrapper.emitted('change-expiration-column')[0][0]).toBe('changed_at');
    });
  });
});
