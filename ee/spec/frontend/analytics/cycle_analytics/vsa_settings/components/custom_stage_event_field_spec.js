import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { i18n, ERRORS } from 'ee/analytics/cycle_analytics/vsa_settings/constants';
import CustomStageEventField from 'ee/analytics/cycle_analytics/vsa_settings/components/custom_stage_event_field.vue';
import { customStageEvents as stageEvents } from '../../mock_data';

const formatStartEventOpts = (_events) =>
  _events
    .filter((ev) => ev.canBeStartEvent)
    .map(({ name: text, identifier: value }) => ({ text, value }));

const index = 0;
const eventType = 'stage-start-event';
const fieldLabel = i18n.FORM_FIELD_START_EVENT;
const defaultDropdownText = 'default value';
const eventsList = formatStartEventOpts(stageEvents);
const identifierError = ERRORS.START_EVENT_REQUIRED;

const defaultProps = {
  index,
  eventType,
  eventsList,
  fieldLabel,
  defaultDropdownText,
};

describe('CustomStageEventField', () => {
  function createComponent(props = {}) {
    return shallowMountExtended(CustomStageEventField, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  }

  let wrapper = null;

  const findEventField = () => wrapper.findByTestId(`custom-stage-${eventType}-${index}`);
  const findCollapsibleListbox = () => findEventField().findComponent(GlCollapsibleListbox);

  beforeEach(() => {
    wrapper = createComponent();
  });

  describe('Event collapsible listbox', () => {
    it('renders the listbox', () => {
      expect(findEventField().attributes()).toMatchObject({
        label: fieldLabel,
        state: 'true',
        'invalid-feedback': '',
      });

      expect(findCollapsibleListbox().attributes('disabled')).toBeUndefined();
      expect(findCollapsibleListbox().props('toggleText')).toBe(defaultDropdownText);
    });

    it('renders each item in the event list', () => {
      expect(findCollapsibleListbox().props('items')).toBe(eventsList);
    });

    it('emits the `update-identifier` event when an event is selected', () => {
      expect(wrapper.emitted('update-identifier')).toBeUndefined();

      const firstEvent = eventsList[0];
      findCollapsibleListbox().vm.$emit('select', firstEvent.value);

      expect(wrapper.emitted('update-identifier')[0]).toEqual([firstEvent.value]);
    });

    it('sets disables the listbox when the disabled prop is set', () => {
      expect(findCollapsibleListbox().attributes('disabled')).toBeUndefined();

      wrapper = createComponent({ disabled: true });

      expect(findCollapsibleListbox().attributes('disabled')).toBeDefined();
    });
  });

  describe('with an event field error', () => {
    beforeEach(() => {
      wrapper = createComponent({
        isIdentifierValid: false,
        identifierError,
      });
    });

    it('sets the form group error state', () => {
      expect(findEventField().attributes('state')).toBeUndefined();
      expect(findEventField().attributes('invalid-feedback')).toBe(identifierError);
    });

    it('sets the listbox error state', () => {
      expect(findCollapsibleListbox().props('state')).toBe(false);
    });
  });

  describe('initialValue prop', () => {
    beforeEach(() => {
      wrapper = createComponent({ initialValue: eventsList[0].value });
    });

    it('sets the selected listbox item', () => {
      expect(findCollapsibleListbox().props().selected).toBe(eventsList[0].value);
    });

    it('updates the selected listbox item when the prop changes', async () => {
      await wrapper.setProps({ initialValue: eventsList[1].value });
      expect(findCollapsibleListbox().props().selected).toBe(eventsList[1].value);
    });
  });
});
