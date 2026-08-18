import Vue, { nextTick } from 'vue';
import { GlLink } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import WorkItemCustomFieldsSingleSelect from 'ee/work_items/components/work_item_custom_fields_single_select.vue';
import { newWorkItemId } from '~/work_items/utils';
import {
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
  CUSTOM_FIELDS_TYPE_NUMBER,
} from '~/work_items/constants';
import updateWorkItemCustomFieldsMutation from 'ee/work_items/graphql/update_work_item_custom_fields.mutation.graphql';
import customFieldSelectOptionsQuery from 'ee/work_items/graphql/work_item_custom_field_select_options.query.graphql';
import { customFieldsWidgetResponseFactory } from 'jest/work_items/mock_data';

describe('WorkItemCustomFieldsSingleSelect', () => {
  let wrapper;

  Vue.use(VueApollo);

  const defaultWorkItemType = 'Issue';
  const defaultWorkItemId = 'gid://gitlab/WorkItem/1';

  const defaultField = {
    customField: {
      id: 'gid://gitlab/Issuables::CustomField/1',
      fieldType: CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
      name: 'Single select custom field label',
    },
    selectedOptions: [
      {
        id: 'gid://gitlab/Issuables::CustomFieldSelectOption/1',
        value: 'Option 1',
      },
    ],
  };

  const querySuccessHandler = jest.fn().mockResolvedValue({
    data: {
      customField: {
        id: '1-select',
        selectOptions: [
          {
            id: 'gid://gitlab/Issuables::CustomFieldSelectOption/1',
            value: 'Option 1',
            __typename: 'CustomFieldSelectOption',
          },
          {
            id: 'gid://gitlab/Issuables::CustomFieldSelectOption/2',
            value: 'Option 2',
            __typename: 'CustomFieldSelectOption',
          },
          {
            id: 'gid://gitlab/Issuables::CustomFieldSelectOption/3',
            value: 'Option 3',
            __typename: 'CustomFieldSelectOption',
          },
        ],
        __typename: 'CustomField',
      },
    },
  });

  const mutationSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      workItemUpdate: {
        workItem: {
          id: defaultWorkItemId,
          widgets: [customFieldsWidgetResponseFactory],
        },
        errors: [],
      },
    },
  });

  const findComponent = () => wrapper.findComponent(WorkItemCustomFieldsSingleSelect);
  const findSidebarDropdownWidget = () => wrapper.findComponent(WorkItemSidebarDropdownWidget);
  const findSelectValue = () => wrapper.findComponent(GlLink);

  const mockWorkItemConfigGetter = jest.fn().mockImplementation(() => {
    return {
      isGroupWorkItemType: null,
    };
  });

  const defaultProvide = {
    issuesListPath: '/flightjs/Flight/-/issues',
    epicsListPath: '/groups/flightjs/-/epics',
    getWorkItemTypeConfiguration: mockWorkItemConfigGetter,
  };

  const createComponent = ({
    canUpdate = true,
    workItemType = defaultWorkItemType,
    customField = defaultField,
    workItemId = defaultWorkItemId,
    queryHandler = querySuccessHandler,
    mutationHandler = mutationSuccessHandler,
    provide = {},
  } = {}) => {
    wrapper = shallowMount(WorkItemCustomFieldsSingleSelect, {
      apolloProvider: createMockApollo([
        [customFieldSelectOptionsQuery, queryHandler],
        [updateWorkItemCustomFieldsMutation, mutationHandler],
      ]),
      provide: {
        ...defaultProvide,
        ...provide,
      },
      propsData: {
        canUpdate,
        customField,
        workItemType,
        workItemId,
      },
    });
  };

  describe('rendering', () => {
    it('renders if custom field exists and type is correct', async () => {
      createComponent();

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findSidebarDropdownWidget().exists()).toBe(true);
    });

    it('does not render if custom field is empty', async () => {
      createComponent({ customField: {} });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findSidebarDropdownWidget().exists()).toBe(false);
    });

    it('does not render if custom field type is incorrect', async () => {
      createComponent({
        customField: {
          customField: {
            id: '1-number',
            fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
            name: 'Number custom field label',
          },
          selectedOptions: {
            id: 'number',
            value: 3,
          },
        },
      });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findSidebarDropdownWidget().exists()).toBe(false);
    });
  });

  it('displays correct label', () => {
    createComponent();

    expect(findSidebarDropdownWidget().props('dropdownLabel')).toBe(
      'Single select custom field label',
    );
  });

  describe('value', () => {
    it('shows None when no option is set', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-select',
            fieldType: CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            name: 'Single select custom field label',
          },
          selectedOptions: null,
        },
      });

      expect(findSidebarDropdownWidget().props().toggleDropdownText).toContain('None');
    });

    it('shows None when invalid value is received', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-select',
            fieldType: CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            name: 'Single select custom field label',
          },
          selectedOptions: 'Sample text',
        },
      });

      expect(findSidebarDropdownWidget().props().toggleDropdownText).toContain('None');
    });

    it('shows option selected on render when it is defined', () => {
      createComponent();

      expect(findSelectValue().attributes('title')).toBe('Option 1');
    });

    it('generates correct search path for project/issues list for each option link for an issue', () => {
      createComponent();

      expect(findSelectValue().attributes('href')).toBe(
        '/flightjs/Flight/-/issues/?custom-field[1]=1',
      );
    });

    it('generates correct search path for group/epics list for each option link when isGroupWorkItemType is true', () => {
      const provide = {
        getWorkItemTypeConfiguration: jest.fn().mockReturnValue({ isGroupWorkItemType: true }),
      };
      createComponent({ workItemType: 'Epic', provide });

      expect(findSelectValue().attributes('href')).toBe(
        '/groups/flightjs/-/epics/?custom-field[1]=1',
      );
    });
  });

  describe('Dropdown options', () => {
    it('fetches options when dropdown is shown', async () => {
      createComponent();

      expect(querySuccessHandler).not.toHaveBeenCalled();

      await findSidebarDropdownWidget().vm.$emit('dropdown-shown');

      expect(querySuccessHandler).toHaveBeenCalled();
    });

    it('shows dropdown options on list according to their state', async () => {
      createComponent();

      findSidebarDropdownWidget().vm.$emit('dropdown-shown');
      await waitForPromises();

      expect(findSidebarDropdownWidget().props('toggleDropdownText')).toBe('Option 1');
      expect(findSidebarDropdownWidget().props('listItems')).toEqual([
        {
          options: [
            { text: 'Option 1', value: 'gid://gitlab/Issuables::CustomFieldSelectOption/1' },
          ],
          text: 'Selected',
        },
        {
          options: [
            { text: 'Option 2', value: 'gid://gitlab/Issuables::CustomFieldSelectOption/2' },
            { text: 'Option 3', value: 'gid://gitlab/Issuables::CustomFieldSelectOption/3' },
          ],
          text: 'All',
          textSrOnly: true,
        },
      ]);
    });

    it('shows "None" on value when dropdown is open and no option was selected', async () => {
      createComponent({
        customField: {
          customField: {
            id: '1-select',
            fieldType: CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            name: 'Single select custom field label',
          },
          selectedOptions: null,
        },
      });

      findSidebarDropdownWidget().vm.$emit('dropdown-shown');
      await waitForPromises();

      expect(findSidebarDropdownWidget().props('toggleDropdownText')).toBe('None');
      expect(findSidebarDropdownWidget().props('listItems')).toEqual([
        { text: 'Option 1', value: 'gid://gitlab/Issuables::CustomFieldSelectOption/1' },
        { text: 'Option 2', value: 'gid://gitlab/Issuables::CustomFieldSelectOption/2' },
        { text: 'Option 3', value: 'gid://gitlab/Issuables::CustomFieldSelectOption/3' },
      ]);
    });

    it('shows alert error when fetching options fails', async () => {
      const errorQueryHandler = jest.fn().mockRejectedValue(new Error('Network error'));

      createComponent({ queryHandler: errorQueryHandler });

      findSidebarDropdownWidget().vm.$emit('dropdown-shown');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        [
          'Options could not be loaded for field: Single select custom field label. Please try again.',
        ],
      ]);
    });
  });

  describe('updating the selection', () => {
    it('does not call "workItemUpdate" mutation when option is selected if is create flow', async () => {
      createComponent({ workItemId: newWorkItemId(defaultWorkItemType) });
      await nextTick();

      findSidebarDropdownWidget().vm.$emit(
        'update-value',
        'gid://gitlab/Issuables::CustomFieldSelectOption/2',
      );
      await nextTick();

      expect(mutationSuccessHandler).not.toHaveBeenCalled();
    });

    it('sends mutation with correct variables when selecting an option', async () => {
      createComponent();
      await nextTick();

      const newSelectedId = 'gid://gitlab/Issuables::CustomFieldSelectOption/2';
      findSidebarDropdownWidget().vm.$emit('update-value', newSelectedId);
      await nextTick();

      expect(mutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: defaultWorkItemId,
          customFieldsWidget: [
            {
              customFieldId: defaultField.customField.id,
              selectedOptionIds: [newSelectedId],
            },
          ],
        },
        useWorkItemFeatures: false,
      });
    });

    describe('when workItemFeaturesField feature flag is enabled', () => {
      it('passes useWorkItemFeatures as true to the mutation', async () => {
        createComponent({ provide: { glFeatures: { workItemFeaturesField: true } } });
        await nextTick();

        const newSelectedId = 'gid://gitlab/Issuables::CustomFieldSelectOption/2';
        findSidebarDropdownWidget().vm.$emit('update-value', newSelectedId);
        await nextTick();

        expect(mutationSuccessHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            useWorkItemFeatures: true,
          }),
        );
      });
    });

    it('sends null when clearing the selection', async () => {
      createComponent();
      await nextTick();

      findSidebarDropdownWidget().vm.$emit('update-value', null);

      await waitForPromises();

      expect(mutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: defaultWorkItemId,
          customFieldsWidget: [
            {
              customFieldId: defaultField.customField.id,
              selectedOptionIds: [null],
            },
          ],
        },
        useWorkItemFeatures: false,
      });
    });

    it('shows loading state while updating', async () => {
      const mutationHandler = jest.fn().mockImplementation(() => new Promise(() => {}));

      createComponent({ mutationHandler });
      await nextTick();

      findSidebarDropdownWidget().vm.$emit(
        'update-value',
        'gid://gitlab/Issuables::CustomFieldSelectOption/2',
      );
      await nextTick();

      expect(findSidebarDropdownWidget().props('updateInProgress')).toBe(true);
    });

    it('emits error event when mutation returns an error', async () => {
      jest.spyOn(Sentry, 'captureException');

      const errorMessage = 'Failed to update';
      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemUpdate: {
            errors: [errorMessage],
          },
        },
      });

      createComponent({ mutationHandler });
      await nextTick();

      findSidebarDropdownWidget().vm.$emit(
        'update-value',
        'gid://gitlab/Issuables::CustomFieldSelectOption/2',
      );

      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the Issue. Please try again.'],
      ]);
      expect(Sentry.captureException).toHaveBeenCalled();
    });

    it('emits error event when mutation catches error', async () => {
      jest.spyOn(Sentry, 'captureException');

      const errorHandler = jest.fn().mockRejectedValue(new Error());

      createComponent({ mutationHandler: errorHandler });
      await nextTick();

      findSidebarDropdownWidget().vm.$emit(
        'update-value',
        'gid://gitlab/Issuables::CustomFieldSelectOption/2',
      );
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the Issue. Please try again.'],
      ]);
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });

  describe('work item type configuration', () => {
    describe('isGroupWorkItemType check', () => {
      it.each`
        workItemType | isGroupWorkItemType | expectedListPath
        ${'Epic'}    | ${true}             | ${'/groups/flightjs/-/epics'}
        ${'Epic'}    | ${null}             | ${'/flightjs/Flight/-/issues'}
        ${'Issue'}   | ${false}            | ${'/flightjs/Flight/-/issues'}
        ${'Issue'}   | ${null}             | ${'/flightjs/Flight/-/issues'}
      `(
        'generates correct search path when workItemType=$workItemType, isGroupWorkItemType=$isGroupWorkItemType',
        ({ workItemType, isGroupWorkItemType, expectedListPath }) => {
          mockWorkItemConfigGetter.mockImplementation(() => {
            return { isGroupWorkItemType };
          });

          const provide = { getWorkItemTypeConfiguration: mockWorkItemConfigGetter };

          createComponent({ workItemType, provide });

          expect(findSelectValue().attributes('href')).toContain(expectedListPath);
        },
      );
    });
  });
});
