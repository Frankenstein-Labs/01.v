import { GlDatepicker, GlFormRadio } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import WorkItemDates from 'ee/work_items/components/work_item_dates.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockTracking } from 'helpers/tracking_helper';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { newDate } from '~/lib/utils/datetime/date_calculation_utility';
import { TRACKING_CATEGORY_SHOW } from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import WorkItemSidebarWidget from '~/work_items/components/shared/work_item_sidebar_widget.vue';
import {
  mockWorkItemFeaturesData,
  updateWorkItemMutationErrorResponse,
  updateWorkItemMutationResponse,
} from '../mock_data';

Vue.use(VueApollo);

describe('WorkItemDates component', () => {
  let wrapper;

  const startDateShowSpy = jest.fn();

  const workItemId = 'gid://gitlab/WorkItem/1';
  const updateWorkItemMutationHandler = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);

  const findStartDatePicker = () => wrapper.findComponentByTestId('start-date-picker');
  const findDatePickersWrapper = () => wrapper.findByTestId('date-pickers-wrapper');
  const findDueDatePicker = () => wrapper.findComponentByTestId('due-date-picker');
  const findApplyButton = () => wrapper.findComponentByTestId('apply-button');
  const findEditButton = () => wrapper.findComponentByTestId('edit-button');
  const findStartDateValue = () => wrapper.findByTestId('start-date-value');
  const findDueDateValue = () => wrapper.findByTestId('due-date-value');
  const findFixedRadioButton = () => wrapper.findAllComponents(GlFormRadio).at(0);
  const findInheritedRadioButton = () => wrapper.findAllComponents(GlFormRadio).at(1);

  const editAndApplyStartDate = async (isoDateString) => {
    findEditButton().vm.$emit('click');
    await nextTick();

    findStartDatePicker().vm.$emit('input', new Date(isoDateString));
    findStartDatePicker().vm.$emit('close');

    await nextTick();
    findApplyButton().vm.$emit('click');
  };

  const buildWorkItemWithFeatures = () => {
    const baseWorkItem = updateWorkItemMutationResponse.data.workItemUpdate.workItem;
    const featuresFragment = mockWorkItemFeaturesData();
    return { baseWorkItem, featuresFragment };
  };

  const buildFeaturesMutationHandler = ({ baseWorkItem, featuresFragment }) =>
    jest.fn().mockResolvedValue({
      data: {
        workItemUpdate: {
          ...updateWorkItemMutationResponse.data.workItemUpdate,
          workItem: { ...baseWorkItem, features: featuresFragment },
        },
      },
    });

  const createComponent = ({
    canUpdate = false,
    dueDate = null,
    startDate = null,
    isFixed = false,
    shouldRollUp = true,
    mutationHandler = updateWorkItemMutationHandler,
    workItem = updateWorkItemMutationResponse.data.workItemUpdate.workItem,
    provide = {},
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemDates, {
      apolloProvider: createMockApollo([[updateWorkItemMutation, mutationHandler]]),
      propsData: {
        canUpdate,
        dueDate,
        startDate,
        isFixed,
        shouldRollUp,
        workItemType: 'Epic',
        workItem,
      },
      provide,
      stubs: {
        GlDatepicker: stubComponent(GlDatepicker, {
          methods: {
            show: startDateShowSpy,
          },
        }),
        GlFormRadio,
        WorkItemSidebarWidget,
      },
    });
  };

  describe('when in default state', () => {
    describe('start date', () => {
      it('is rendered correctly when it is passed to the component', () => {
        createComponent({ startDate: '2022-01-01' });

        expect(findStartDateValue().text()).toBe('Jan 1, 2022');
        expect(findStartDateValue().classes('gl-text-subtle')).toBe(false);
      });

      it('renders `None` when it is  not passed to the component`', () => {
        createComponent();

        expect(findStartDateValue().text()).toBe('None');
        expect(findStartDateValue().classes('gl-text-subtle')).toBe(true);
      });
    });

    describe('end date', () => {
      it('is rendered correctly when it is passed to the component', () => {
        createComponent({ dueDate: '2022-01-01' });

        expect(findDueDateValue().text()).toContain('Jan 1, 2022');
        expect(findDueDateValue().classes('gl-text-subtle')).toBe(false);
      });

      it('renders `None` when it is not passed to the component`', () => {
        createComponent();

        expect(findDueDateValue().text()).toContain('None');
        expect(findDueDateValue().classes('gl-text-subtle')).toBe(true);
      });
    });

    it('does not render datepickers', () => {
      createComponent();

      expect(findStartDatePicker().exists()).toBe(false);
      expect(findDueDatePicker().exists()).toBe(false);
    });

    describe('when both start and due date are fixed', () => {
      it('checks "fixed" radio button', async () => {
        createComponent({ isFixed: true });
        await nextTick();

        expect(findFixedRadioButton().props('checked')).toBe('fixed');
      });
    });

    describe('when both start and due date are inherited', () => {
      it('checks "inherited" radio button', async () => {
        createComponent({ isFixed: false });
        await nextTick();

        expect(findInheritedRadioButton().props('checked')).toBe('inherited');
      });
    });
  });

  describe('rollupType updates', () => {
    describe('when isFixed prop changes', () => {
      it('updates rollupType from inherited to fixed', async () => {
        createComponent({ isFixed: false });
        await nextTick();

        expect(findInheritedRadioButton().props('checked')).toBe('inherited');

        await wrapper.setProps({ isFixed: true });

        expect(findFixedRadioButton().props('checked')).toBe('fixed');
      });

      it('updates rollupType from fixed to inherited', async () => {
        createComponent({ isFixed: true });
        await nextTick();

        expect(findFixedRadioButton().props('checked')).toBe('fixed');

        await wrapper.setProps({ isFixed: false });

        expect(findInheritedRadioButton().props('checked')).toBe('inherited');
      });
    });
  });

  describe.each`
    radioType      | findRadioButton             | isFixed
    ${'fixed'}     | ${findFixedRadioButton}     | ${true}
    ${'inherited'} | ${findInheritedRadioButton} | ${false}
  `('$radioType radio button', ({ radioType, findRadioButton, isFixed }) => {
    it('renders as enabled when user can update work item', () => {
      createComponent({ canUpdate: true });

      expect(findRadioButton().props('disabled')).toBe(false);
    });

    it('renders as disabled when user cannot update work item', () => {
      createComponent();

      expect(findRadioButton().props().disabled).toBe(true);
    });

    describe('when clicked', () => {
      let trackingSpy;

      beforeEach(async () => {
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);

        createComponent({ canUpdate: true, isFixed });

        findRadioButton().vm.$emit('change');
        await nextTick();
      });

      it(`calls mutation to update rollup type to ${radioType}`, () => {
        expect(updateWorkItemMutationHandler).toHaveBeenCalledWith({
          input: {
            id: workItemId,
            startAndDueDateWidget: { isFixed },
          },
          useWorkItemFeatures: false,
        });
      });

      it('tracks updating the rollup type', () => {
        expect(trackingSpy).toHaveBeenCalledWith(TRACKING_CATEGORY_SHOW, 'updated_rollup_type', {
          category: TRACKING_CATEGORY_SHOW,
          label: 'item_rolledup_dates',
          property: 'type_Epic',
          extra: { viewContext: 'full_screen' },
        });
      });
    });

    describe('when clicked with workItemFeaturesField feature flag enabled', () => {
      let mutationHandler;

      beforeEach(async () => {
        const { baseWorkItem, featuresFragment } = buildWorkItemWithFeatures();
        mutationHandler = buildFeaturesMutationHandler({ baseWorkItem, featuresFragment });
        createComponent({
          canUpdate: true,
          isFixed,
          mutationHandler,
          workItem: { ...baseWorkItem, features: featuresFragment },
          provide: { glFeatures: { workItemFeaturesField: true } },
        });

        findRadioButton().vm.$emit('change');
        await nextTick();
      });

      it('passes useWorkItemFeatures as true to the mutation', () => {
        expect(mutationHandler).toHaveBeenCalledWith({
          input: {
            id: workItemId,
            startAndDueDateWidget: { isFixed },
          },
          useWorkItemFeatures: true,
        });
      });
    });
  });

  describe('when in editing state', () => {
    it('updates datepicker props when component startDate and dueDate props are updated', async () => {
      createComponent({ canUpdate: true });
      findEditButton().vm.$emit('click');
      await nextTick();

      expect(findStartDatePicker().props('value')).toBe(null);
      expect(findDueDatePicker().props('value')).toBe(null);

      await wrapper.setProps({
        startDate: '2022-01-01',
        dueDate: '2022-01-02',
      });

      expect(findStartDatePicker().props('value')).toEqual(newDate('2022-01-01'));
      expect(findDueDatePicker().props('value')).toEqual(newDate('2022-01-02'));
    });

    describe('start date picker', () => {
      beforeEach(() => {
        createComponent({
          canUpdate: true,
          dueDate: '2022-01-02',
          startDate: '2022-01-02',
        });

        findEditButton().vm.$emit('click');
        return nextTick();
      });

      it('clears the start date input on `clear` event', async () => {
        findStartDatePicker().vm.$emit('clear');
        await nextTick();

        expect(findStartDatePicker().props('value')).toBe(null);
      });

      describe('when the start date is later than the due date', () => {
        const startDate = new Date('2030-01-01T00:00:00.000Z');

        it('updates the due date picker to the same date', async () => {
          findStartDatePicker().vm.$emit('input', startDate);
          findStartDatePicker().vm.$emit('close');
          await nextTick();

          expect(findDueDatePicker().props('value')).toEqual(startDate);
        });
      });
    });

    describe('when updating date', () => {
      describe('when dates are changed', () => {
        let trackingSpy;

        beforeEach(async () => {
          createComponent({
            canUpdate: true,
            dueDate: '2022-12-31',
            startDate: '2022-12-31',
          });
          trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);

          await editAndApplyStartDate('2022-01-01T00:00:00.000Z');
        });

        it('mutation is called to update dates', () => {
          expect(updateWorkItemMutationHandler).toHaveBeenCalledWith({
            input: {
              id: workItemId,
              startAndDueDateWidget: {
                dueDate: '2022-12-31',
                startDate: '2022-01-01',
                isFixed: true,
              },
            },
            useWorkItemFeatures: false,
          });
        });

        it('tracks updating the dates', () => {
          expect(trackingSpy).toHaveBeenCalledWith(TRACKING_CATEGORY_SHOW, 'updated_dates', {
            category: TRACKING_CATEGORY_SHOW,
            label: 'item_rolledup_dates',
            property: 'type_Epic',
            extra: { viewContext: 'full_screen' },
          });
        });
      });

      describe('when workItemFeaturesField feature flag is enabled', () => {
        let mutationHandler;

        beforeEach(async () => {
          const { baseWorkItem, featuresFragment } = buildWorkItemWithFeatures();
          mutationHandler = buildFeaturesMutationHandler({ baseWorkItem, featuresFragment });
          createComponent({
            canUpdate: true,
            dueDate: '2022-12-31',
            startDate: '2022-12-31',
            mutationHandler,
            workItem: { ...baseWorkItem, features: featuresFragment },
            provide: { glFeatures: { workItemFeaturesField: true } },
          });

          await editAndApplyStartDate('2022-01-01T00:00:00.000Z');
        });

        it('passes useWorkItemFeatures as true to the mutation', () => {
          expect(mutationHandler).toHaveBeenCalledWith({
            input: {
              id: workItemId,
              startAndDueDateWidget: {
                dueDate: '2022-12-31',
                startDate: '2022-01-01',
                isFixed: true,
              },
            },
            useWorkItemFeatures: true,
          });
        });
      });

      describe('when dates are unchanged', () => {
        beforeEach(async () => {
          createComponent({
            canUpdate: true,
            dueDate: '2022-12-31',
            startDate: '2022-12-31',
          });

          await editAndApplyStartDate('2022-12-31T00:00:00.000Z');
        });

        it('mutation is not called to update dates', () => {
          expect(updateWorkItemMutationHandler).not.toHaveBeenCalled();
        });
      });

      describe.each`
        description                        | mutationHandler
        ${'when there is a GraphQL error'} | ${jest.fn().mockResolvedValue(updateWorkItemMutationErrorResponse)}
        ${'when there is a network error'} | ${jest.fn().mockRejectedValue(new Error())}
      `('$description', ({ mutationHandler }) => {
        beforeEach(async () => {
          createComponent({
            canUpdate: true,
            dueDate: '2022-12-31',
            startDate: '2022-12-31',
            mutationHandler,
          });

          await editAndApplyStartDate('2022-01-01T00:00:00.000Z');
          return waitForPromises();
        });

        it('emits an error', () => {
          expect(wrapper.emitted('error')).toEqual([
            ['Something went wrong while updating the Epic. Please try again.'],
          ]);
        });
      });
    });

    describe('when escape key is pressed', () => {
      beforeEach(async () => {
        createComponent({
          canUpdate: true,
          dueDate: '2022-12-31',
          startDate: '2022-12-31',
        });

        findEditButton().vm.$emit('click');
        await nextTick();

        findStartDatePicker().vm.$emit('input', new Date('2022-01-01T00:00:00.000Z'));
      });

      it('widget is closed and dates are updated, when date picker is focused', async () => {
        findDatePickersWrapper().trigger('keydown.esc');
        await nextTick();

        expect(updateWorkItemMutationHandler).toHaveBeenCalled();
        expect(findStartDatePicker().exists()).toBe(false);
      });
    });
  });
});
