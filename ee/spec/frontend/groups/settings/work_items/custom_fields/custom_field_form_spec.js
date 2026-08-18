import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlModal } from '@gitlab/ui';
import { ignoreConsoleMessages } from 'helpers/console_watcher';
import Draggable from '~/lib/utils/vue3compat/draggable_compat.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { ENTER_KEY } from '~/lib/utils/keys';
import CustomFieldForm from 'ee/groups/settings/work_items/custom_fields/custom_field_form.vue';
import createCustomFieldMutation from 'ee/groups/settings/work_items/custom_fields/create_custom_field.mutation.graphql';
import updateCustomFieldMutation from 'ee/groups/settings/work_items/custom_fields/update_custom_field.mutation.graphql';
import groupCustomFieldQuery from 'ee/groups/settings/work_items/custom_fields/group_custom_field.query.graphql';
import namespaceWorkItemTypesQuery from 'ee/groups/settings/work_items/custom_fields/group_work_item_types_for_select.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('CustomFieldForm', () => {
  let wrapper;

  const findToggleModalButton = () => wrapper.findComponentByTestId('toggle-modal');
  const findEditButton = () => wrapper.findComponentByTestId('toggle-edit-modal');
  const findModal = () => wrapper.findComponent(GlModal);
  const findFieldTypeSelect = () => wrapper.findComponent('#field-type');
  const findFieldNameFormGroup = () => wrapper.find('[label-for="field-name"]');
  const findFieldNameInput = () => wrapper.findComponent('#field-name');
  const findWorkItemTypeListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  const mockWorkItemTypes = [
    {
      id: 'gid://gitlab/WorkItems::Type/1',
      name: 'Issue',
      widgetDefinitions: [{ type: 'DESCRIPTION' }, { type: 'CUSTOM_FIELDS' }],
    },
    {
      id: 'gid://gitlab/WorkItems::Type/2',
      name: 'Incident',
      widgetDefinitions: [{ type: 'DESCRIPTION' }],
    },
    {
      id: 'gid://gitlab/WorkItems::Type/3',
      name: 'Task',
      widgetDefinitions: [{ type: 'DESCRIPTION' }, { type: 'CUSTOM_FIELDS' }],
    },
    {
      id: 'gid://gitlab/WorkItems::Type/8',
      name: 'Epic',
      widgetDefinitions: [{ type: 'DESCRIPTION' }, { type: 'CUSTOM_FIELDS' }],
    },
    {
      id: 'gid://gitlab/WorkItems::Type/9',
      name: 'Custom Type',
      widgetDefinitions: [{ type: 'CUSTOM_FIELDS' }],
    },
  ];

  const findCustomFieldOptionsFormGroup = () =>
    wrapper.find('[data-testid="custom-field-options"]');
  const findAddSelectOptionButton = () => wrapper.findComponentByTestId('add-select-option');
  const findAddSelectInputAt = (i) => wrapper.findComponentByTestId(`select-options-${i}`);
  const findAllAddSelectInputs = () => wrapper.findAll('[data-testid^="select-options"]');
  const findDraggableComponent = () => wrapper.findComponent(Draggable);
  const findDragHandles = () => wrapper.findAll('.drag-handle');

  const findRemoveSelectButtonAt = (i) =>
    wrapper.findComponentByTestId(`remove-select-option-${i}`);

  const findSaveCustomFieldButton = () => wrapper.findComponentByTestId('save-custom-field');
  const findUpdateCustomFieldButton = () => wrapper.findComponentByTestId('update-custom-field');

  const mockCreateFieldResponse = {
    data: {
      customFieldCreate: {
        customField: {
          id: 'gid://gitlab/Issuables::CustomField/13',
        },
        errors: [],
      },
    },
  };

  const mockUpdateFieldResponse = {
    data: {
      customFieldUpdate: {
        customField: {
          id: 'gid://gitlab/Issuables::CustomField/13',
          name: 'Updated Field',
        },
        errors: [],
      },
    },
  };

  const mockExistingField = {
    id: 'gid://gitlab/Issuables::CustomField/13',
    name: 'Existing Field',
    fieldType: 'SINGLE_SELECT',
    active: true,
    updatedAt: '2023-01-01T00:00:00Z',
    createdAt: '2023-01-01T00:00:00Z',
    selectOptions: [
      { id: '1', value: 'Option 1' },
      { id: '2', value: 'Option 2' },
    ],
    workItemTypes: [mockWorkItemTypes[0]],
  };

  const namespaceWorkItemTypesResponse = {
    data: { namespace: { id: '1', workItemTypes: { nodes: mockWorkItemTypes } } },
  };

  const fullPath = 'group/subgroup';

  const createComponent = ({
    props = {},
    createFieldResponse = {},
    updateFieldResponse = {},
    existingFieldResponse = {},
    createFieldHandler = jest.fn().mockResolvedValue(createFieldResponse),
    updateFieldHandler = jest.fn().mockResolvedValue(updateFieldResponse),
    existingFieldHandler = jest.fn().mockResolvedValue(existingFieldResponse),
    workItemTypesHandler = jest.fn().mockResolvedValue(namespaceWorkItemTypesResponse),
  } = {}) => {
    wrapper = shallowMountExtended(CustomFieldForm, {
      propsData: {
        fullPath,
        ...props,
      },
      apolloProvider: createMockApollo([
        [createCustomFieldMutation, createFieldHandler],
        [updateCustomFieldMutation, updateFieldHandler],
        [groupCustomFieldQuery, existingFieldHandler],
        [namespaceWorkItemTypesQuery, workItemTypesHandler],
      ]),
      stubs: {
        GlModal,
      },
    });
  };

  ignoreConsoleMessages([/Duplicate keys detected/]);

  describe('initial rendering', () => {
    it('renders create field button when not editing', () => {
      createComponent();
      expect(findToggleModalButton().text()).toBe('Create field');
    });

    it('renders edit button when editing', () => {
      createComponent({ props: { customFieldId: '13' } });
      expect(findEditButton().exists()).toBe(true);
    });

    it('modal is hidden by default', () => {
      createComponent();
      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('modal visibility', () => {
    it('shows modal when create button is clicked', async () => {
      createComponent();
      await findToggleModalButton().vm.$emit('click');
      expect(findModal().props('visible')).toBe(true);
    });

    it('shows modal when edit button is clicked', async () => {
      createComponent({ props: { customFieldId: '13' } });
      await findEditButton().vm.$emit('click');
      expect(findModal().props('visible')).toBe(true);
    });

    it('hides modal when hide event is emitted', async () => {
      createComponent();
      await findToggleModalButton().vm.$emit('click');
      await findModal().vm.$emit('hide');
      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('form behavior', () => {
    beforeEach(() => {
      createComponent();
      findToggleModalButton().vm.$emit('click');
    });

    it('has autocomplete disabled on the name field', () => {
      expect(findFieldNameInput().attributes('autocomplete')).toBe('off');
    });

    it.each(['SINGLE_SELECT', 'MULTI_SELECT'])(
      `shows select options section when field type is %s`,
      async (type) => {
        await findFieldTypeSelect().vm.$emit('input', type);
        await nextTick();

        expect(findAddSelectOptionButton().exists()).toBe(true);
        expect(findAddSelectInputAt(0).exists()).toBe(true);
      },
    );

    it.each(['NUMBER', 'TEXT'])(
      `hides select options section when field type is %s`,
      async (type) => {
        await findFieldTypeSelect().vm.$emit('input', type);
        await nextTick();

        expect(findAddSelectOptionButton().exists()).toBe(false);
        expect(findAddSelectInputAt(0).exists()).toBe(false);
      },
    );

    it('displays "Select types" when no types are selected', () => {
      expect(findWorkItemTypeListbox().props('toggleText')).toBe('Select types');
    });

    it('displays only the currently supported work item types', async () => {
      await waitForPromises();

      expect(findWorkItemTypeListbox().props('items')).toStrictEqual([
        { value: 'gid://gitlab/WorkItems::Type/1', name: 'Issue', text: 'Issue' },
        { value: 'gid://gitlab/WorkItems::Type/3', name: 'Task', text: 'Task' },
        { value: 'gid://gitlab/WorkItems::Type/8', name: 'Epic', text: 'Epic' },
        { value: 'gid://gitlab/WorkItems::Type/9', name: 'Custom Type', text: 'Custom Type' },
      ]);
    });

    it('displays selected type names when types are selected', async () => {
      await findWorkItemTypeListbox().vm.$emit('select', [mockWorkItemTypes[0].id]);
      await nextTick();

      expect(findWorkItemTypeListbox().props('toggleText')).toBe('Issue');
    });

    describe('add select options', () => {
      beforeEach(async () => {
        await findFieldTypeSelect().vm.$emit('input', 'SINGLE_SELECT');
        await nextTick();
      });

      it('adds select option when add button is clicked', async () => {
        expect(findAddSelectOptionButton().exists()).toBe(true);
        expect(findAddSelectInputAt(1).exists()).toBe(false);

        findAddSelectOptionButton().vm.$emit('click');
        await nextTick();

        expect(findAddSelectInputAt(1).exists()).toBe(true);
      });

      it('adds select option when Enter key is pressed', async () => {
        expect(findAddSelectInputAt(1).exists()).toBe(false);

        findAddSelectInputAt(0).vm.$emit('keyup', new KeyboardEvent('keyup', { key: ENTER_KEY }));
        await nextTick();
        expect(findAddSelectInputAt(1).exists()).toBe(true);
      });
    });

    it('remove button removes select option', async () => {
      await findFieldTypeSelect().vm.$emit('input', 'SINGLE_SELECT');
      await nextTick();

      // No remove button unless >1 option
      expect(findRemoveSelectButtonAt(0).exists()).toBe(false);

      findAddSelectOptionButton().vm.$emit('click');
      await nextTick();
      findAddSelectInputAt(0).vm.$emit('input', 'Option 1');
      await nextTick();

      // Both options have remove buttons now
      expect(findRemoveSelectButtonAt(0).exists()).toBe(true);
      findRemoveSelectButtonAt(1).vm.$emit('click');
      await nextTick();

      expect(findAddSelectInputAt(1).exists()).toBe(false);
    });

    describe('paste behavior for select options', () => {
      beforeEach(async () => {
        createComponent();
        findToggleModalButton().vm.$emit('click');
        findFieldTypeSelect().vm.$emit('input', 'SINGLE_SELECT');
        await nextTick();
      });

      it('handles single line paste normally', async () => {
        findAddSelectInputAt(0).vm.$emit('input', 'Initial ');
        await nextTick();

        // Create clipboard event with single line of text
        const clipboardData = {
          getData: jest.fn().mockReturnValue('pasted text'),
        };
        const event = {
          clipboardData,
          preventDefault: jest.fn(),
          target: {
            dataset: { optionIndex: '0' },
            selectionStart: 8,
            selectionEnd: 8,
          },
        };

        findAddSelectInputAt(0).vm.$emit('paste', event);
        await nextTick();

        // For single line, use default paste behavior
        expect(event.preventDefault).not.toHaveBeenCalled();
        expect(findAllAddSelectInputs()).toHaveLength(1);
      });

      it('splits multi-line paste into separate options', async () => {
        findAddSelectInputAt(0).vm.$emit('input', '');
        await nextTick();

        const clipboardData = {
          getData: jest.fn().mockReturnValue('Option 1\nOption 2\nOption 3'),
        };
        const event = {
          clipboardData,
          preventDefault: jest.fn(),
          target: {
            dataset: { optionIndex: '0' },
            selectionStart: 0,
            selectionEnd: 0,
          },
        };

        findAddSelectInputAt(0).vm.$emit('paste', event);
        await nextTick();

        // Use multiline paste behavior
        expect(event.preventDefault).toHaveBeenCalled();
        expect(findAllAddSelectInputs()).toHaveLength(3);
        expect(findAddSelectInputAt(0).attributes('value')).toBe('Option 1');
        expect(findAddSelectInputAt(1).attributes('value')).toBe('Option 2');
        expect(findAddSelectInputAt(2).attributes('value')).toBe('Option 3');
      });

      it('handles paste in the middle of text correctly', async () => {
        findAddSelectInputAt(0).vm.$emit('input', 'Start End');

        // Add a second option to verify new lines insert in between
        findAddSelectOptionButton().vm.$emit('click');
        await nextTick();
        findAddSelectInputAt(1).vm.$emit('input', 'Last option');
        await nextTick();

        const clipboardData = {
          getData: jest.fn().mockReturnValue('Middle\nNew Line 1\nNew Line 2'),
        };
        const event = {
          clipboardData,
          preventDefault: jest.fn(),
          target: {
            dataset: { optionIndex: '0' },
            selectionStart: 6, // After "Start "
            selectionEnd: 6,
          },
        };

        findAddSelectInputAt(0).vm.$emit('paste', event);
        await nextTick();

        expect(event.preventDefault).toHaveBeenCalled();

        // Should insert first line at cursor position
        expect(findAddSelectInputAt(0).attributes('value')).toBe('Start MiddleEnd');

        // Should add additional options for subsequent lines ahead of original last option
        expect(findAddSelectInputAt(1).attributes('value')).toBe('New Line 1');
        expect(findAddSelectInputAt(2).attributes('value')).toBe('New Line 2');
        expect(findAddSelectInputAt(3).attributes('value')).toBe('Last option');
        expect(findAllAddSelectInputs()).toHaveLength(4);
      });

      it('ignores empty lines when pasting', async () => {
        findAddSelectInputAt(0).vm.$emit('input', '');
        await nextTick();

        const clipboardData = {
          getData: jest.fn().mockReturnValue('Line 1\n\n\nLine 2\n\nLine 3'),
        };
        const event = {
          clipboardData,
          preventDefault: jest.fn(),
          target: {
            dataset: { optionIndex: '0' },
            selectionStart: 0,
            selectionEnd: 0,
          },
        };

        findAddSelectInputAt(0).vm.$emit('paste', event);
        await nextTick();

        expect(findAllAddSelectInputs()).toHaveLength(3);
        expect(findAddSelectInputAt(0).attributes('value')).toBe('Line 1');
        expect(findAddSelectInputAt(1).attributes('value')).toBe('Line 2');
        expect(findAddSelectInputAt(2).attributes('value')).toBe('Line 3');
      });
    });
  });

  describe('drag to reorder select options', () => {
    beforeEach(async () => {
      createComponent();
      await findToggleModalButton().vm.$emit('click');
      await findFieldTypeSelect().vm.$emit('input', 'SINGLE_SELECT');
      await nextTick();
    });

    it('shows drag handles only when there are multiple options', async () => {
      // Initially there's only one option, so there should be no drag handles
      expect(findDragHandles().exists()).toBe(false);

      findAddSelectOptionButton().vm.$emit('click');
      await nextTick();

      // After adding a second option there should be drag handles
      expect(findDragHandles()).toHaveLength(2);
    });

    it('reorders options when dragged', async () => {
      findAddSelectInputAt(0).vm.$emit('input', 'First Option');
      findAddSelectOptionButton().vm.$emit('click');
      await nextTick();

      findAddSelectInputAt(1).vm.$emit('input', 'Second Option');
      await nextTick();

      expect(findAddSelectInputAt(0).attributes('value')).toBe('First Option');
      expect(findAddSelectInputAt(1).attributes('value')).toBe('Second Option');

      // Simulate a drag and drop reorder
      const draggable = findDraggableComponent();
      const currentOptions = [...wrapper.vm.formData.selectOptions];
      const reorderedOptions = [currentOptions[1], currentOptions[0]];

      draggable.vm.$emit('input', reorderedOptions);
      await nextTick();

      expect(findAddSelectInputAt(0).attributes('value')).toBe('Second Option');
      expect(findAddSelectInputAt(1).attributes('value')).toBe('First Option');
    });
  });

  describe('saveCustomField', () => {
    it('calls create mutation with correct variables when creating', async () => {
      const createFieldHandler = jest.fn().mockResolvedValue(mockCreateFieldResponse);
      createComponent({ createFieldHandler });

      await findToggleModalButton().vm.$emit('click');

      findFieldTypeSelect().vm.$emit('input', 'TEXT');
      findFieldNameInput().vm.$emit('input', 'Test Field');
      findWorkItemTypeListbox().vm.$emit('select', [mockWorkItemTypes[2].id]);

      await nextTick();

      findSaveCustomFieldButton().vm.$emit('click');

      await waitForPromises();

      expect(Sentry.captureException).not.toHaveBeenCalled();

      expect(createFieldHandler).toHaveBeenCalledWith({
        groupPath: fullPath,
        name: 'Test Field',
        fieldType: 'TEXT',
        selectOptions: undefined,
        workItemTypeIds: [mockWorkItemTypes[2].id],
      });
    });

    it('calls update mutation with correct variables when editing', async () => {
      const updateFieldHandler = jest.fn().mockResolvedValue(mockUpdateFieldResponse);
      const existingFieldHandler = jest
        .fn()
        .mockResolvedValue({ data: { group: { id: '1', customField: mockExistingField } } });
      createComponent({
        props: { customFieldId: 'gid://gitlab/Issuables::CustomField/13' },
        updateFieldHandler,
        existingFieldHandler,
      });

      await findEditButton().vm.$emit('click');
      await waitForPromises();

      await findFieldNameInput().vm.$emit('input', 'Updated Field');

      await findWorkItemTypeListbox().vm.$emit('select', [mockWorkItemTypes[1].id]);

      await nextTick();

      // Simulate reordering options via dragging
      const draggable = findDraggableComponent();
      const currentOptions = [...wrapper.vm.formData.selectOptions];
      const reorderedOptions = [currentOptions[1], currentOptions[0]];

      draggable.vm.$emit('input', reorderedOptions);
      await nextTick();

      findUpdateCustomFieldButton().vm.$emit('click');

      await waitForPromises();

      expect(Sentry.captureException).not.toHaveBeenCalled();

      expect(updateFieldHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/Issuables::CustomField/13',
        name: 'Updated Field',
        selectOptions: [
          { id: '2', value: 'Option 2' },
          { id: '1', value: 'Option 1' },
        ],
        workItemTypeIds: [mockWorkItemTypes[1].id],
      });
    });

    it('emits `created` after the create mutation succeeds', async () => {
      createComponent({ createFieldResponse: mockCreateFieldResponse });

      await findToggleModalButton().vm.$emit('click');

      findFieldTypeSelect().vm.$emit('input', 'TEXT');
      findFieldNameInput().vm.$emit('input', 'Test Field');

      await nextTick();

      findSaveCustomFieldButton().vm.$emit('click');

      await waitForPromises();

      expect(wrapper.emitted('created')).toHaveLength(1);
    });

    it('emits `updated` after the update mutation succeeds', async () => {
      createComponent({
        props: { customFieldId: 'gid://gitlab/Issuables::CustomField/13' },
        updateFieldResponse: mockUpdateFieldResponse,
        existingFieldResponse: { data: { group: { id: '1', customField: mockExistingField } } },
      });

      await findEditButton().vm.$emit('click');
      await waitForPromises();

      findUpdateCustomFieldButton().vm.$emit('click');

      await waitForPromises();

      expect(wrapper.emitted('updated')).toHaveLength(1);
    });

    it('shows validation error if field name is empty', async () => {
      createComponent({ createFieldResponse: mockCreateFieldResponse });
      await findToggleModalButton().vm.$emit('click');

      await nextTick();

      expect(findFieldNameFormGroup().attributes('invalid-feedback')).toBe('Name is required.');
    });

    it('shows validation error if no select options added', async () => {
      createComponent({ createFieldResponse: mockCreateFieldResponse });
      await findToggleModalButton().vm.$emit('click');

      await findFieldTypeSelect().vm.$emit('input', 'SINGLE_SELECT');

      await nextTick();

      expect(findCustomFieldOptionsFormGroup().attributes('invalid-feedback')).toBe(
        'At least one option is required.',
      );
    });

    it('handles mutation errors', async () => {
      const errorMessage = 'Error creating custom field';
      const errorResponse = {
        data: {
          customFieldCreate: {
            customField: null,
            errors: [errorMessage],
          },
        },
      };
      createComponent({ createFieldResponse: errorResponse });
      await findToggleModalButton().vm.$emit('click');

      await findFieldTypeSelect().vm.$emit('input', 'TEXT');
      await findFieldNameInput().vm.$emit('input', 'Test Field');

      findSaveCustomFieldButton().vm.$emit('click');

      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalled();
    });

    it('resets form after successful creation', async () => {
      const createFieldHandler = jest.fn().mockResolvedValue(mockCreateFieldResponse);
      createComponent({ createFieldHandler });

      await findToggleModalButton().vm.$emit('click');

      findFieldTypeSelect().vm.$emit('input', 'TEXT');
      findFieldNameInput().vm.$emit('input', 'Test Field');
      findWorkItemTypeListbox().vm.$emit('select', [mockWorkItemTypes[2].id]);

      await nextTick();

      findSaveCustomFieldButton().vm.$emit('click');
      await waitForPromises();

      await findToggleModalButton().vm.$emit('click');
      await waitForPromises();

      expect(findFieldTypeSelect().attributes('value')).toBe('SINGLE_SELECT');
      expect(findFieldNameInput().props('value')).toBe('');
      expect(findWorkItemTypeListbox().props('selected')).toEqual([]);
      expect(findWorkItemTypeListbox().props('toggleText')).toBe('Select types');
    });
  });

  describe('edit mode', () => {
    it('loads existing field data when editing', async () => {
      const existingFieldHandler = jest
        .fn()
        .mockResolvedValue({ data: { group: { id: '1', customField: mockExistingField } } });
      createComponent({
        props: { customFieldId: 'gid://gitlab/Issuables::CustomField/13' },
        existingFieldHandler,
      });

      await findEditButton().vm.$emit('click');
      await waitForPromises();

      expect(Sentry.captureException).not.toHaveBeenCalled();

      expect(findFieldNameInput().attributes().value).toBe('Existing Field');
      expect(findFieldTypeSelect().exists()).toBe(false);
      expect(findAddSelectInputAt(0).attributes().value).toBe('Option 1');
      expect(findAddSelectInputAt(1).attributes().value).toBe('Option 2');
    });

    it('hides field type select when editing', async () => {
      const existingFieldHandler = jest
        .fn()
        .mockResolvedValue({ data: { group: { id: '1', customField: mockExistingField } } });
      createComponent({
        props: { customFieldId: 'gid://gitlab/Issuables::CustomField/13' },
        existingFieldHandler,
      });

      await findEditButton().vm.$emit('click');
      await waitForPromises();

      expect(findFieldTypeSelect().exists()).toBe(false);
    });
  });
});
