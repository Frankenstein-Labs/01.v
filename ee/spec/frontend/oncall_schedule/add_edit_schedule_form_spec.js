import { GlFormGroup } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import mockTimezones from 'test_fixtures/timezones/full.json';
import TimezoneDropdown from '~/vue_shared/components/timezone_dropdown/timezone_dropdown.vue';
import AddEditScheduleForm from 'ee/oncall_schedules/components/add_edit_schedule_form.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import { getOncallSchedulesQueryResponse } from './mocks/apollo_mock';

Vue.use(VueApollo);

describe('AddEditScheduleForm', () => {
  let wrapper;
  const mockSchedule =
    getOncallSchedulesQueryResponse.data.project.incidentManagementOncallSchedules.nodes[0];

  const createComponent = ({ props = {}, stubs = {} } = {}) => {
    wrapper = shallowMount(AddEditScheduleForm, {
      propsData: {
        form: {
          name: mockSchedule.name,
          description: mockSchedule.description,
          timezone: mockTimezones[0],
        },
        validationState: {
          name: true,
          timezone: true,
        },
        ...props,
      },
      provide: {
        timezones: mockTimezones,
      },
      apolloProvider: createMockApollo(),
      stubs,
    });
  };

  const findTimezoneDropdown = () => wrapper.findComponent(TimezoneDropdown);
  const findScheduleName = () => wrapper.findComponent(GlFormGroup);

  it('renders form layout', () => {
    createComponent({
      stubs: {
        TimezoneDropdown: stubComponent(TimezoneDropdown, {
          template: `<div />`,
        }),
      },
    });
    expect(wrapper.element).toMatchSnapshot();
  });

  describe('setTimezone', () => {
    beforeEach(() => {
      createComponent();
      findTimezoneDropdown().vm.$emit('input', mockTimezones[0]);
    });

    it('emits custom event upon timezone selection', () => {
      const emittedEvent = wrapper.emitted('update-schedule-form');
      expect(emittedEvent).toHaveLength(1);
      expect(emittedEvent[0][0]).toEqual({ type: 'timezone', value: mockTimezones[0] });
    });

    it('sets a value for selectedDropdownTimezone', () => {
      expect(wrapper.vm.selectedDropdownTimezone).toEqual(mockTimezones[0]);
    });
  });

  describe('Schedule form validation', () => {
    it('should show feedback for an invalid name input validation state', () => {
      createComponent({
        props: {
          validationState: { name: false },
        },
      });
      expect(findScheduleName().attributes('state')).toBeUndefined();
    });
  });

  describe('Form validation', () => {
    describe('Timezone select', () => {
      it('has a validation red border when timezone field is invalid', () => {
        createComponent({
          props: {
            schedule: null,
            form: { name: '', description: '', timezone: '' },
            validationState: { timezone: false },
          },
        });
        expect(findTimezoneDropdown().props('additionalClass')).toStrictEqual([
          { 'invalid-dropdown': true },
        ]);
      });

      it('does not have a validation red border when timezone field is valid', () => {
        createComponent({
          props: {
            validationState: { timezone: true },
          },
        });
        expect(findTimezoneDropdown().props('additionalClass')).toStrictEqual([
          { 'invalid-dropdown': false },
        ]);
      });
    });
  });
});
