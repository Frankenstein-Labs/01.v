import { GlTokenSelector, GlFormGroup, GlToggle } from '@gitlab/ui';
import { cloneDeep, merge } from 'lodash-es';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AddEditRotationForm from 'ee/oncall_schedules/components/rotations/components/add_edit_rotation_form.vue';
import { formEmptyState } from 'ee/oncall_schedules/components/rotations/components/add_edit_rotation_modal.vue';
import { LENGTH_ENUM } from 'ee/oncall_schedules/constants';
import { participants, getOncallSchedulesQueryResponse } from '../../mocks/apollo_mock';

const schedule =
  getOncallSchedulesQueryResponse.data.project.incidentManagementOncallSchedules.nodes[0];

describe('AddEditRotationForm', () => {
  let wrapper;

  const createComponent = ({ data = {}, props = {} } = {}) => {
    wrapper = shallowMountExtended(AddEditRotationForm, {
      data() {
        return {
          ...data,
        };
      },
      propsData: merge(
        {
          schedule,
          isLoading: false,
          validationState: {
            name: true,
            participants: false,
            startsAt: false,
          },
          participants,
          form: cloneDeep(formEmptyState),
        },
        props,
      ),
    });
  };

  const findRotationLength = () => wrapper.find('[id="rotation-length"]');
  const findRotationStartTime = () => wrapper.findComponentByTestId('rotation-start-time');
  const findRotationEndTime = () => wrapper.findComponentByTestId('rotation-end-time');
  const findRotationEndsContainer = () => wrapper.findByTestId('rotation-ends-on');
  const findEndDateToggle = () => wrapper.findComponent(GlToggle);
  const findUserSelector = () => wrapper.findComponent(GlTokenSelector);
  const findRotationFormGroups = () => wrapper.findAllComponents(GlFormGroup);
  const findRestrictedToToggle = () => wrapper.findComponentByTestId('restricted-to-toggle');
  const findRestrictedToContainer = () => wrapper.findByTestId('restricted-to-time');
  const findRestrictedFromListbox = () => wrapper.findComponentByTestId('restricted-from');
  const findRestrictedToListbox = () => wrapper.findComponentByTestId('restricted-to');

  describe('Rotation form validation', () => {
    beforeEach(() => {
      createComponent();
    });

    it.each`
      index | type                | validationState | value
      ${0}  | ${'name'}           | ${true}         | ${'true'}
      ${1}  | ${'participants'}   | ${false}        | ${undefined}
      ${2}  | ${'rotationLength'} | ${false}        | ${undefined}
      ${3}  | ${'startsAt'}       | ${false}        | ${undefined}
    `(
      'form validation for $type returns $value when passed validate state of $validationState',
      ({ index, value }) => {
        const formGroup = findRotationFormGroups();
        expect(formGroup.at(index).attributes('state')).toBe(value);
      },
    );
  });

  describe('Rotation length and start time', () => {
    it('renders the rotation length value', () => {
      createComponent();
      const rotationLength = findRotationLength();
      expect(rotationLength.exists()).toBe(true);
      expect(rotationLength.attributes('value')).toBe('1');
    });

    it('renders the rotation starts on datepicker', () => {
      createComponent();
      const startsOn = findRotationStartTime();
      expect(startsOn.exists()).toBe(true);
      expect(startsOn.attributes('text')).toBe('00:00');
      expect(startsOn.attributes('headertext')).toBe('');
    });

    it('should emit an event with selected value on time selection', () => {
      const option = 3;
      createComponent();
      findRotationStartTime().vm.$emit('select', option);
      const emittedEvent = wrapper.emitted('update-rotation-form');
      expect(emittedEvent).toHaveLength(1);
      expect(emittedEvent[0][0]).toEqual({ type: 'startsAt.time', value: option });
    });

    it('should add a checkmark to a selected start time', async () => {
      const time = 7;
      createComponent({
        props: {
          form: {
            startsAt: {
              time,
            },
            rotationLength: {
              length: 1,
              unit: LENGTH_ENUM.hours,
            },
          },
        },
      });
      await nextTick();
      expect(findRotationStartTime().props('selected')).toBe(time);
    });
  });

  describe('Rotation end time', () => {
    it('toggle state depends on isEndDateEnabled', () => {
      createComponent();
      expect(findEndDateToggle().props('value')).toBe(false);
      expect(findRotationEndsContainer().exists()).toBe(false);

      createComponent({ props: { form: { isEndDateEnabled: true } } });
      expect(findRotationEndsContainer().exists()).toBe(true);
    });

    it('toggles end time visibility on', () => {
      createComponent();
      const toggle = findEndDateToggle().vm;
      toggle.$emit('change', true);
      const emittedEvent = wrapper.emitted('update-rotation-form');
      expect(emittedEvent).toHaveLength(1);
      expect(emittedEvent[0][0]).toEqual({ type: 'isEndDateEnabled', value: true });
    });

    it('toggles end time visibility off', () => {
      createComponent({ props: { form: { isEndDateEnabled: true } } });
      const toggle = findEndDateToggle().vm;
      toggle.$emit('change', false);
      const emittedEvent = wrapper.emitted('update-rotation-form');
      expect(emittedEvent).toHaveLength(1);
      expect(emittedEvent[0][0]).toEqual({ type: 'isEndDateEnabled', value: false });
    });

    it('should emit an event with selected value on time selection', () => {
      const option = 3;
      createComponent({ props: { form: { isEndDateEnabled: true } } });
      findRotationEndTime().vm.$emit('select', option);
      const emittedEvent = wrapper.emitted('update-rotation-form');
      expect(emittedEvent).toHaveLength(1);
      expect(emittedEvent[0][0]).toEqual({ type: 'endsAt.time', value: option });
    });

    it('should add a checkmark to a selected end time', async () => {
      const time = 5;
      createComponent({
        props: {
          form: {
            isEndDateEnabled: true,
            endsAt: {
              time,
            },
            startsAt: {
              time: 0,
            },
            rotationLength: {
              length: 1,
              unit: LENGTH_ENUM.hours,
            },
          },
        },
      });
      await nextTick();
      expect(findRotationEndTime().props('selected')).toBe(time);
    });
  });

  describe('Rotation restricted to time', () => {
    it('toggle state depends on isRestrictedToTime', () => {
      createComponent();
      expect(findRestrictedToToggle().props('value')).toBe(false);
      expect(findRestrictedToContainer().exists()).toBe(false);

      createComponent({ props: { form: { ...formEmptyState, isRestrictedToTime: true } } });
      expect(findRestrictedToToggle().props('value')).toBe(true);
      expect(findRestrictedToContainer().exists()).toBe(true);
    });

    it('toggles end time visibility on', () => {
      createComponent();
      const toggle = findRestrictedToToggle().vm;
      toggle.$emit('change', true);
      const emittedEvent = wrapper.emitted('update-rotation-form');
      expect(emittedEvent).toHaveLength(1);
      expect(emittedEvent[0][0]).toEqual({ type: 'isRestrictedToTime', value: true });
    });

    it('toggles end time visibility off', () => {
      createComponent({ props: { form: { ...formEmptyState, isRestrictedToTime: true } } });
      const toggle = findRestrictedToToggle().vm;
      toggle.$emit('change', false);
      const emittedEvent = wrapper.emitted('update-rotation-form');
      expect(emittedEvent).toHaveLength(1);
      expect(emittedEvent[0][0]).toEqual({ type: 'isRestrictedToTime', value: false });
    });

    describe('when a rotation restriction is selected', () => {
      const timeFrom = 5;
      const timeTo = 22;
      it('should emit an event with selected value on restricted FROM time selection', () => {
        createComponent({ props: { form: { ...formEmptyState, isRestrictedToTime: true } } });
        findRestrictedFromListbox().vm.$emit('select', timeFrom);
        findRestrictedToListbox().vm.$emit('select', timeTo);
        const emittedEvent = wrapper.emitted('update-rotation-form');
        expect(emittedEvent).toHaveLength(2);
        expect(emittedEvent[0][0]).toEqual({ type: 'restrictedTo.startTime', value: timeFrom });
        expect(emittedEvent[1][0]).toEqual({ type: 'restrictedTo.endTime', value: timeTo });
      });

      it('should add a checkmark to a selected restricted FROM time', () => {
        createComponent({
          props: {
            form: {
              ...formEmptyState,
              isRestrictedToTime: true,
              restrictedTo: { startTime: timeFrom, endTime: timeTo },
            },
          },
        });
        expect(findRestrictedFromListbox().props('selected')).toBe(timeFrom);
        expect(findRestrictedToListbox().props('selected')).toBe(timeTo);
      });
    });
  });

  describe('filter participants', () => {
    beforeEach(() => {
      createComponent();
    });

    it('has user options that are populated via apollo', () => {
      expect(findUserSelector().props('dropdownItems')).toHaveLength(participants.length);
    });

    it('calls the API and sets dropdown items as request result', () => {
      const tokenSelector = findUserSelector();

      tokenSelector.vm.$emit('focus');
      tokenSelector.vm.$emit('blur');
      tokenSelector.vm.$emit('focus');

      expect(tokenSelector.props('dropdownItems')).toMatchObject(participants);
      expect(tokenSelector.props('hideDropdownWithNoItems')).toBe(false);
    });

    it('emits `input` event with selected users', () => {
      findUserSelector().vm.$emit('input', participants);

      expect(findUserSelector().emitted().input[0][0]).toEqual(participants);
    });

    it('when text input is blurred the text input clears', () => {
      const tokenSelector = findUserSelector();
      tokenSelector.vm.$emit('blur');

      expect(tokenSelector.props('hideDropdownWithNoItems')).toBe(false);
    });
  });
});
