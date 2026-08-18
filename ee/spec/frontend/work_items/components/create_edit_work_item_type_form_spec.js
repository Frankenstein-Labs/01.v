import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlFormRadio, GlFormRadioGroup, GlAlert } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import CreateEditWorkItemTypeForm from 'ee/work_items/components/create_edit_work_item_type_form.vue';
import workItemTypeUpdateMutation from 'ee/work_items/graphql/update_work_item_type.mutation.graphql';
import workItemTypeCreateMutation from 'ee/work_items/graphql/create_work_item_type.mutation.graphql';
import workItemTypesConfigurationQuery from '~/work_items/graphql/work_item_types_configuration.query.graphql';
import organizationWorkItemTypesQuery from 'ee/work_items/graphql/organization_work_item_types.query.graphql';
import namespaceWorkItemSettingsQuery from 'ee/work_items/graphql/namespace_work_item_settings.query.graphql';
import orgWorkItemSettingsQuery from 'ee/work_items/graphql/organization_work_item_settings.query.graphql';
import { mockWorkItemTypeIcons } from 'ee_jest/work_items/mock_data';

Vue.use(VueApollo);

describe('CreateEditWorkItemTypeForm', () => {
  let wrapper;

  const successUpdateWorkItemTypeMutationHandler = jest.fn().mockResolvedValue({
    data: {
      workItemTypeUpdate: {
        workItemType: {
          id: 'gid://gitlab/WorkItems::Type/1',
          name: 'Updated Name',
          iconName: 'work-item-task',
          __typename: 'WorkItemType',
        },
        errors: [],
        __typename: 'WorkItemTypeUpdatePayload',
      },
    },
  });

  const mockWorkItemType = {
    __typename: 'WorkItemType',
    id: 'gid://gitlab/WorkItems::Type/1',
    name: 'New type',
    iconName: 'work-item-task',
    archived: false,
    enabled: true,
    canPromoteToObjective: false,
    canUserCreateItems: true,
    isConfigurable: true,
    isFilterableBoardView: false,
    isFilterableListView: false,
    isGroupWorkItemType: false,
    isIncidentManagement: false,
    isServiceDesk: false,
    showProjectSelector: false,
    supportsMoveAction: false,
    supportsRoadmapView: false,
    useIssueView: false,
    visibleInSettings: true,
    widgetDefinitions: [],
  };

  const successCreateWorkItemTypeMutationHandler = jest.fn().mockResolvedValue({
    data: {
      workItemTypeCreate: {
        workItemType: mockWorkItemType,
        errors: [],
        __typename: 'WorkItemTypeCreatePayload',
      },
    },
  });

  let apolloProvider;

  const createComponent = ({
    isVisible = true,
    isEditMode = false,
    workItemType = null,
    isLoading = false,
    fullPath = '',
    mutationHandler = successUpdateWorkItemTypeMutationHandler,
    createMutationHandler = successCreateWorkItemTypeMutationHandler,
    workItemTypesConfigurationHandler = jest.fn().mockResolvedValue({ data: {} }),
    organizationWorkItemTypesHandler = jest.fn().mockResolvedValue({ data: {} }),
    namespaceWorkItemSettingsHandler = jest.fn().mockResolvedValue({
      data: {
        namespace: {
          __typename: 'Namespace',
          id: 'gid://gitlab/Group/1',
          workItemSettings: {
            __typename: 'WorkItemSettings',
            customizableTypeVisibility: true,
          },
        },
      },
    }),
    orgWorkItemSettingsHandler = jest.fn().mockResolvedValue({
      data: {
        organization: {
          __typename: 'Organization',
          id: 'gid://gitlab/Organizations::Organization/1',
          workItemSettings: {
            __typename: 'WorkItemSettings',
            customizableTypeVisibility: true,
          },
        },
      },
    }),
  } = {}) => {
    apolloProvider = createMockApollo([
      [workItemTypeUpdateMutation, mutationHandler],
      [workItemTypeCreateMutation, createMutationHandler],
      [workItemTypesConfigurationQuery, workItemTypesConfigurationHandler],
      [organizationWorkItemTypesQuery, organizationWorkItemTypesHandler],
      [namespaceWorkItemSettingsQuery, namespaceWorkItemSettingsHandler],
      [orgWorkItemSettingsQuery, orgWorkItemSettingsHandler],
    ]);

    wrapper = shallowMountExtended(CreateEditWorkItemTypeForm, {
      propsData: {
        isVisible,
        isEditMode,
        workItemType,
        isLoading,
        fullPath,
        workItemTypeIcons: mockWorkItemTypeIcons,
      },
      apolloProvider,
      stubs: {
        GlModal: stubComponent(GlModal, {
          template:
            '<div><slot name="modal-title"></slot><slot></slot><slot name="modal-footer"></slot></div>',
        }),
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findNameInput = () => wrapper.findComponentByTestId('work-item-type-name-input');
  const findSubmitButton = () => wrapper.findComponentByTestId('work-item-type-submit-button');
  const findCancelButton = () => wrapper.findByTestId('work-item-type-cancel-button');
  const findIconLabels = () => wrapper.findAll('label[role="radio"]');
  const findIconRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEnabledCheckbox = () =>
    wrapper.findComponentByTestId('work-item-type-enabled-checkbox');

  describe('Default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the form with name input and icon selection with all icons', () => {
      expect(findNameInput().exists()).toBe(true);
      expect(findIconRadioGroup().exists()).toBe(true);
      expect(findIconLabels()).toHaveLength(mockWorkItemTypeIcons.length);
    });

    it('renders submit and cancel buttons', () => {
      expect(findSubmitButton().exists()).toBe(true);
      expect(findCancelButton().exists()).toBe(true);
    });
  });

  describe('enabled checkbox', () => {
    it('renders the enabled checkbox', async () => {
      createComponent();
      await waitForPromises();

      expect(findEnabledCheckbox().exists()).toBe(true);
    });

    it('is checked when workItemType.enabled is true', async () => {
      createComponent({ isEditMode: true, workItemType: { ...mockWorkItemType, enabled: true } });
      await waitForPromises();

      expect(findEnabledCheckbox().props('checked')).toBe(true);
    });

    it('is unchecked when workItemType.enabled is false', async () => {
      createComponent({ isEditMode: true, workItemType: { ...mockWorkItemType, enabled: false } });
      await waitForPromises();

      expect(findEnabledCheckbox().props('checked')).toBe(false);
    });
  });

  describe('modal title', () => {
    it('shows "New type" title in create mode', () => {
      createComponent();

      expect(findModal().props('title')).toBe('New type');
    });

    it('shows "Edit type name and icon" title in edit mode', () => {
      createComponent({ isEditMode: true });

      expect(findModal().props('title')).toBe('Edit type name and icon');
    });
  });

  describe('submit button text', () => {
    it('shows "Save" button text in create mode', () => {
      createComponent();

      expect(findSubmitButton().text()).toBe('Save');
    });

    it('shows "Save" button text in edit mode', () => {
      createComponent({ isEditMode: true });

      expect(findSubmitButton().text()).toBe('Save');
    });
  });

  describe('form initialization', () => {
    it('initializes form with empty values in create mode', () => {
      createComponent();

      expect(findNameInput().attributes('value')).toBe('');
    });

    it('initializes form with work item type data in edit mode', () => {
      const workItemType = {
        name: 'Custom Type',
        iconName: 'work-item-task',
      };

      createComponent({ isEditMode: true, workItemType });

      expect(findNameInput().attributes('value')).toBe('Custom Type');
    });
  });

  it('enforces maxlength of 48 characters on name input', () => {
    createComponent();

    expect(findNameInput().attributes('maxlength')).toBe('48');
  });

  describe('icon selection', () => {
    it('renders all icon options with correct attributes', () => {
      createComponent();

      const labels = findIconLabels();
      expect(labels).toHaveLength(mockWorkItemTypeIcons.length);

      labels.wrappers.forEach((label, index) => {
        expect(label.attributes('aria-label')).toBe(mockWorkItemTypeIcons[index].label);
        expect(label.attributes('role')).toBe('radio');
      });
    });

    it('updates icon when clicking on an icon option', async () => {
      createComponent();

      const secondIconLabel = findIconLabels().at(1);
      secondIconLabel.trigger('click');
      await nextTick();

      const selectedLabel = findIconLabels().wrappers.find(
        (label) => label.attributes('aria-checked') === 'true',
      );

      expect(selectedLabel.attributes('aria-label')).toContain('Stack');
    });

    it('sets correct tabindex for icon options', async () => {
      createComponent();

      const secondIconLabel = findIconLabels().at(1);
      await secondIconLabel.trigger('click');
      await nextTick();

      const labels = findIconLabels();
      labels.wrappers.forEach((label) => {
        const isSelected = label.attributes('aria-checked') === 'true';
        const expectedTabindex = isSelected ? '0' : '-1';
        expect(label.attributes('tabindex')).toBe(expectedTabindex);
      });
    });
  });

  describe('keyboard navigation', () => {
    it('has icon selection group', () => {
      createComponent();
      expect(findIconRadioGroup().exists()).toBe(true);
    });

    it('supports icon selection with click', async () => {
      createComponent();

      const firstIcon = findIconLabels().at(0);
      await firstIcon.trigger('click');
      await nextTick();

      expect(firstIcon.attributes('aria-checked')).toBe('true');
    });

    it('updates tabindex when icon selection changes', async () => {
      createComponent();

      const firstIcon = findIconLabels().at(0);
      const secondIcon = findIconLabels().at(1);

      await secondIcon.trigger('click');
      await nextTick();

      expect(firstIcon.attributes('tabindex')).toBe('-1');
      expect(secondIcon.attributes('tabindex')).toBe('0');
    });
  });

  describe('accessibility', () => {
    beforeEach(() => {
      createComponent();
    });

    it('has radio role for each icon option', () => {
      findIconLabels().wrappers.forEach((label) => {
        expect(label.attributes('role')).toBe('radio');
      });
    });

    it('has hidden radio inputs for each icon option', () => {
      const radioInputs = wrapper.findAllComponents(GlFormRadio);
      expect(radioInputs).toHaveLength(mockWorkItemTypeIcons.length);

      radioInputs.wrappers.forEach((input) => {
        expect(input.classes()).toContain('gl-sr-only');
      });
    });

    it('displays screen reader text for selected icon', async () => {
      const secondIcon = findIconLabels().at(1);
      await secondIcon.trigger('click');

      const srText = wrapper.find('[aria-live="polite"]');
      expect(srText.exists()).toBe(true);
      expect(srText.text()).toBe(mockWorkItemTypeIcons[1].label);
    });
  });

  describe('edit mode with existing work item type', () => {
    it('preserves work item type data when editing', async () => {
      const workItemType = {
        name: 'Issue',
        iconName: 'work-item-issue',
      };

      createComponent({ isEditMode: true, workItemType });
      await nextTick();

      expect(findNameInput().attributes('value')).toBe('Issue');
    });

    it('displays correct icon in edit mode', async () => {
      const workItemType = {
        name: 'Task',
        iconName: 'work-item-task',
      };

      createComponent({ isEditMode: true, workItemType });
      await nextTick();

      const selectedIcon = findIconLabels().wrappers.find(
        (label) => label.attributes('aria-checked') === 'true',
      );
      expect(selectedIcon.attributes('aria-label')).toContain('Check');
    });

    it('allows changing icon in edit mode', async () => {
      const workItemType = {
        name: 'Type Name',
        iconName: 'work-item-task',
      };

      createComponent({ isEditMode: true, workItemType });
      await nextTick();

      const epicIcon = findIconLabels().at(1);
      await epicIcon.trigger('click');
      await nextTick();

      expect(epicIcon.attributes('aria-checked')).toBe('true');
    });
  });

  describe('form submission in create mode', () => {
    it('calls create mutation with correct variables when form is valid', async () => {
      createComponent({ isEditMode: false });

      await findNameInput().vm.$emit('input', 'New Type');
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(successCreateWorkItemTypeMutationHandler).toHaveBeenCalledWith({
        input: {
          name: 'New Type',
          iconName: mockWorkItemTypeIcons[0].name,
          enabledByDefaultForNewNamespaces: true,
        },
      });
    });

    it('calls create mutation with fullPath when provided', async () => {
      createComponent({ isEditMode: false, fullPath: 'my-group' });

      await findNameInput().vm.$emit('input', 'New Type');
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(successCreateWorkItemTypeMutationHandler).toHaveBeenCalledWith({
        input: {
          name: 'New Type',
          iconName: mockWorkItemTypeIcons[0].name,
          fullPath: 'my-group',
          enabledByDefaultForNewNamespaces: true,
        },
      });
    });

    it('calls create mutation without fullPath in organization mode', async () => {
      createComponent({ isEditMode: false, fullPath: '' });

      await findNameInput().vm.$emit('input', 'New Type');
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(successCreateWorkItemTypeMutationHandler).toHaveBeenCalledWith({
        input: {
          name: 'New Type',
          iconName: mockWorkItemTypeIcons[0].name,
          enabledByDefaultForNewNamespaces: true,
        },
      });
    });

    it('sends enabledByDefaultForNewNamespaces as false when checkbox is unchecked', async () => {
      createComponent({ isEditMode: false });
      await waitForPromises();

      await findNameInput().vm.$emit('input', 'New Type');
      await findEnabledCheckbox().vm.$emit('input', false);
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(successCreateWorkItemTypeMutationHandler).toHaveBeenCalledWith({
        input: {
          name: 'New Type',
          iconName: mockWorkItemTypeIcons[0].name,
          enabledByDefaultForNewNamespaces: false,
        },
      });
    });

    it('sends enabledByDefaultForNewNamespaces as true when checkbox is checked', async () => {
      createComponent({ isEditMode: false });
      await waitForPromises();

      await findNameInput().vm.$emit('input', 'New Type');
      await findEnabledCheckbox().vm.$emit('input', true);
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(successCreateWorkItemTypeMutationHandler).toHaveBeenCalledWith({
        input: {
          name: 'New Type',
          iconName: mockWorkItemTypeIcons[0].name,
          enabledByDefaultForNewNamespaces: true,
        },
      });
    });

    it('emits success event with correct message on successful create', async () => {
      createComponent({ isEditMode: false });

      await findNameInput().vm.$emit('input', 'New Type');
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('success')[0][0]).toEqual({
        workItemType: mockWorkItemType,
      });
    });

    it('shows error alert when create mutation returns errors', async () => {
      const createMutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemTypeCreate: {
            workItemType: null,
            errors: ['Name already exists'],
          },
        },
      });

      createComponent({ isEditMode: false, createMutationHandler });

      await findNameInput().vm.$emit('input', 'New Type');
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toContain('Name already exists');
    });
  });

  describe('form submission in edit mode', () => {
    const editWorkItemType = {
      __typename: 'WorkItemType',
      id: 'gid://gitlab/WorkItems::Type/1',
      name: 'Original Name',
      iconName: 'work-item-issue',
      archived: false,
      enabled: true,
      canPromoteToObjective: false,
      canUserCreateItems: true,
      isConfigurable: true,
      isFilterableBoardView: false,
      isFilterableListView: false,
      isGroupWorkItemType: false,
      isIncidentManagement: false,
      isServiceDesk: false,
      showProjectSelector: false,
      supportsMoveAction: false,
      supportsRoadmapView: false,
      useIssueView: false,
      visibleInSettings: true,
      widgetDefinitions: [],
    };

    it('calls mutation with correct variables when form is valid', async () => {
      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemTypeUpdate: {
            workItemType: { ...editWorkItemType, name: 'Updated Name' },
            errors: [],
            __typename: 'WorkItemTypeUpdatePayload',
          },
        },
      });

      createComponent({ isEditMode: true, workItemType: editWorkItemType, mutationHandler });

      await findNameInput().vm.$emit('input', 'Updated Name');
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          id: editWorkItemType.id,
          name: 'Updated Name',
          iconName: editWorkItemType.iconName,
          enabledByDefaultForNewNamespaces: true,
        },
      });
    });

    it('calls mutation with fullPath when provided in namespace mode', async () => {
      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemTypeUpdate: {
            workItemType: { ...editWorkItemType, name: 'Updated Name' },
            errors: [],
            __typename: 'WorkItemTypeUpdatePayload',
          },
        },
      });

      createComponent({
        isEditMode: true,
        workItemType: editWorkItemType,
        mutationHandler,
        fullPath: 'my-group',
      });

      await findNameInput().vm.$emit('input', 'Updated Name');
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          id: editWorkItemType.id,
          name: 'Updated Name',
          iconName: editWorkItemType.iconName,
          fullPath: 'my-group',
          enabledByDefaultForNewNamespaces: true,
        },
      });
    });

    it('calls mutation without fullPath in organization mode', async () => {
      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemTypeUpdate: {
            workItemType: { ...editWorkItemType, name: 'Updated Name' },
            errors: [],
            __typename: 'WorkItemTypeUpdatePayload',
          },
        },
      });

      createComponent({
        isEditMode: true,
        workItemType: editWorkItemType,
        mutationHandler,
        fullPath: '',
      });

      await findNameInput().vm.$emit('input', 'Updated Name');
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          id: editWorkItemType.id,
          name: 'Updated Name',
          iconName: editWorkItemType.iconName,
          enabledByDefaultForNewNamespaces: true,
        },
      });
    });

    it('sends enabledByDefaultForNewNamespaces based on checkbox value', async () => {
      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemTypeUpdate: {
            workItemType: { ...editWorkItemType, name: 'Updated Name' },
            errors: [],
            __typename: 'WorkItemTypeUpdatePayload',
          },
        },
      });

      createComponent({ isEditMode: true, workItemType: editWorkItemType, mutationHandler });
      await waitForPromises();

      await findNameInput().vm.$emit('input', 'Updated Name');
      await findEnabledCheckbox().vm.$emit('input', false);
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          id: editWorkItemType.id,
          name: 'Updated Name',
          iconName: editWorkItemType.iconName,
          enabledByDefaultForNewNamespaces: false,
        },
      });
    });

    it('emits success event on successful mutation', async () => {
      const updatedType = { ...editWorkItemType, name: 'Updated Name', iconName: 'work-item-task' };

      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemTypeUpdate: {
            workItemType: updatedType,
            errors: [],
            __typename: 'WorkItemTypeUpdatePayload',
          },
        },
      });

      createComponent({ isEditMode: true, workItemType: editWorkItemType, mutationHandler });

      await findNameInput().vm.$emit('input', 'Updated Name');
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('success')[0][0]).toEqual({
        workItemType: updatedType,
      });
    });

    it('emits close event after successful mutation', async () => {
      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemTypeUpdate: {
            workItemType: { ...editWorkItemType, name: 'Updated Name' },
            errors: [],
            __typename: 'WorkItemTypeUpdatePayload',
          },
        },
      });

      createComponent({ isEditMode: true, workItemType: editWorkItemType, mutationHandler });

      await findNameInput().vm.$emit('input', 'Updated Name');
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('shows error alert when mutation returns errors', async () => {
      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemTypeUpdate: {
            workItemType: null,
            errors: ['Name already exists', 'Invalid icon'],
          },
        },
      });

      createComponent({ isEditMode: true, workItemType: editWorkItemType, mutationHandler });

      await findNameInput().vm.$emit('input', 'Updated Name');
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toContain('Name already exists, Invalid icon');
    });

    it('does not emit close event when mutation returns errors', async () => {
      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemTypeUpdate: {
            workItemType: null,
            errors: ['Error occurred'],
          },
        },
      });

      createComponent({ isEditMode: true, workItemType: editWorkItemType, mutationHandler });

      await findNameInput().vm.$emit('input', 'Updated Name');
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('close')).toBeUndefined();
    });

    it('disables submit button while submitting', async () => {
      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemTypeUpdate: {
            workItemType: { ...editWorkItemType, name: 'Updated Name' },
            errors: [],
          },
        },
      });

      createComponent({ isEditMode: true, workItemType: editWorkItemType, mutationHandler });

      await findNameInput().vm.$emit('input', 'Updated Name');
      await findSubmitButton().vm.$emit('click');

      expect(findSubmitButton().props('loading')).toBe(true);
    });

    describe('optimistic response', () => {
      it('uses the new iconName from the form over the existing one', async () => {
        const mutationHandler = jest.fn().mockResolvedValue({
          data: {
            workItemTypeUpdate: {
              workItemType: { ...editWorkItemType, iconName: mockWorkItemTypeIcons[1].name },
              errors: [],
              __typename: 'WorkItemTypeUpdatePayload',
            },
          },
        });

        createComponent({ isEditMode: true, workItemType: editWorkItemType, mutationHandler });

        const epicIconLabel = findIconLabels().at(1);
        await epicIconLabel.trigger('click');
        await findSubmitButton().vm.$emit('click');
        await waitForPromises();

        expect(wrapper.emitted('success')[0][0].workItemType.iconName).toBe(
          mockWorkItemTypeIcons[1].name,
        );
      });

      it('spreads all existing workItemType fields into the optimistic response', async () => {
        const mutationHandler = jest.fn().mockResolvedValue({
          data: {
            workItemTypeUpdate: {
              workItemType: { ...editWorkItemType, name: 'Updated Name' },
              errors: [],
              __typename: 'WorkItemTypeUpdatePayload',
            },
          },
        });

        createComponent({ isEditMode: true, workItemType: editWorkItemType, mutationHandler });

        await findNameInput().vm.$emit('input', 'Updated Name');
        await findSubmitButton().vm.$emit('click');
        await waitForPromises();

        expect(wrapper.emitted('success')[0][0].workItemType).toMatchObject({
          id: editWorkItemType.id,
          name: 'Updated Name',
          archived: editWorkItemType.archived,
          enabled: editWorkItemType.enabled,
          isConfigurable: editWorkItemType.isConfigurable,
        });
      });
    });

    describe('rollback on GraphQL errors', () => {
      it('emits error and does not emit close when mutation returns GraphQL errors', async () => {
        const mutationHandler = jest.fn().mockResolvedValue({
          data: {
            workItemTypeUpdate: {
              workItemType: null,
              errors: ['Name already exists'],
            },
          },
        });

        createComponent({ isEditMode: true, workItemType: editWorkItemType, mutationHandler });

        await findNameInput().vm.$emit('input', 'Updated Name');
        await findSubmitButton().vm.$emit('click');
        await waitForPromises();

        expect(findAlert().exists()).toBe(true);
        expect(findAlert().text()).toContain('Name already exists');
        expect(wrapper.emitted('close')).toBeUndefined();
      });
    });
  });

  describe('error alert', () => {
    it('displays error alert when form error exists', async () => {
      const workItemType = {
        __typename: 'WorkItemType',
        id: 'gid://gitlab/WorkItems::Type/1',
        name: 'Original Name',
        iconName: 'work-item-issue',
        archived: false,
        enabled: true,
        canPromoteToObjective: false,
        canUserCreateItems: true,
        isConfigurable: true,
        isFilterableBoardView: false,
        isFilterableListView: false,
        isGroupWorkItemType: false,
        isIncidentManagement: false,
        isServiceDesk: false,
        showProjectSelector: false,
        supportsMoveAction: false,
        supportsRoadmapView: false,
        useIssueView: false,
        visibleInSettings: true,
        widgetDefinitions: [],
      };

      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemTypeUpdate: {
            workItemType: null,
            errors: ['Error message'],
          },
        },
      });

      createComponent({ isEditMode: true, workItemType, mutationHandler });

      await findNameInput().vm.$emit('input', 'Updated Name');
      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toBe('Error message');
    });
  });

  describe('cache update on create', () => {
    const workItemTypeBase = {
      __typename: 'WorkItemType',
      archived: false,
      enabled: true,
      canPromoteToObjective: false,
      canUserCreateItems: true,
      isConfigurable: true,
      isFilterableBoardView: false,
      isFilterableListView: false,
      isGroupWorkItemType: false,
      isIncidentManagement: false,
      isServiceDesk: false,
      showProjectSelector: false,
      supportsMoveAction: false,
      supportsRoadmapView: false,
      useIssueView: false,
      visibleInSettings: true,
      widgetDefinitions: [],
    };

    const newType = {
      ...workItemTypeBase,
      id: 'gid://gitlab/WorkItems::Type/99',
      name: 'New type',
      iconName: 'work-item-task',
    };

    const existingType = {
      ...workItemTypeBase,
      id: 'gid://gitlab/WorkItems::Type/1',
      name: 'Issue',
      iconName: 'work-item-issue',
    };

    const createMutationHandler = jest.fn().mockResolvedValue({
      data: {
        workItemTypeCreate: {
          workItemType: newType,
          errors: [],
          __typename: 'WorkItemTypeCreatePayload',
        },
      },
    });

    const namespaceCacheData = {
      namespace: {
        id: 'gid://gitlab/Group/1',
        __typename: 'Namespace',
        workItemTypes: {
          __typename: 'WorkItemTypeConnection',
          nodes: [existingType],
        },
      },
    };

    const organizationCacheData = {
      organization: {
        id: 'gid://gitlab/Organizations::Organization/1',
        __typename: 'Organization',
        workItemTypes: {
          __typename: 'WorkItemTypeConnection',
          nodes: [existingType],
        },
      },
    };

    describe('with fullPath (group/project context)', () => {
      beforeEach(() => {
        createComponent({ isEditMode: false, fullPath: 'my-group', createMutationHandler });

        apolloProvider.clients.defaultClient.cache.writeQuery({
          query: workItemTypesConfigurationQuery,
          variables: { fullPath: 'my-group' },
          data: namespaceCacheData,
        });
      });

      it('adds the new type to the namespace cache', async () => {
        await findNameInput().vm.$emit('input', 'New type');
        await findSubmitButton().vm.$emit('click');
        await waitForPromises();

        const { namespace } = apolloProvider.clients.defaultClient.cache.readQuery({
          query: workItemTypesConfigurationQuery,
          variables: { fullPath: 'my-group' },
        });

        expect(namespace.workItemTypes.nodes).toHaveLength(2);
        expect(namespace.workItemTypes.nodes[1]).toMatchObject({
          id: newType.id,
          name: newType.name,
        });
      });

      it('does not update cache if mutation returns errors', async () => {
        const errorMutationHandler = jest.fn().mockResolvedValue({
          data: {
            workItemTypeCreate: {
              workItemType: null,
              errors: ['Name already taken'],
              __typename: 'WorkItemTypeCreatePayload',
            },
          },
        });

        createComponent({
          isEditMode: false,
          fullPath: 'my-group',
          createMutationHandler: errorMutationHandler,
        });

        apolloProvider.clients.defaultClient.cache.writeQuery({
          query: workItemTypesConfigurationQuery,
          variables: { fullPath: 'my-group' },
          data: namespaceCacheData,
        });

        await findNameInput().vm.$emit('input', 'New type');
        await findSubmitButton().vm.$emit('click');
        await waitForPromises();

        const { namespace } = apolloProvider.clients.defaultClient.cache.readQuery({
          query: workItemTypesConfigurationQuery,
          variables: { fullPath: 'my-group' },
        });

        expect(namespace.workItemTypes.nodes).toHaveLength(1);
      });
    });

    describe('without fullPath (organization context)', () => {
      beforeEach(() => {
        createComponent({ isEditMode: false, fullPath: '', createMutationHandler });

        apolloProvider.clients.defaultClient.cache.writeQuery({
          query: organizationWorkItemTypesQuery,
          data: organizationCacheData,
        });
      });

      it('adds the new type to the organization cache', async () => {
        await findNameInput().vm.$emit('input', 'New type');
        await findSubmitButton().vm.$emit('click');
        await waitForPromises();

        const { organization } = apolloProvider.clients.defaultClient.cache.readQuery({
          query: organizationWorkItemTypesQuery,
        });

        expect(organization.workItemTypes.nodes).toHaveLength(2);
        expect(organization.workItemTypes.nodes[1]).toMatchObject({
          id: newType.id,
          name: newType.name,
        });
      });

      it('does not call the namespace query when fullPath is absent', async () => {
        const workItemTypesConfigurationHandler = jest.fn().mockResolvedValue({ data: {} });

        createComponent({
          isEditMode: false,
          fullPath: '',
          createMutationHandler,
          workItemTypesConfigurationHandler,
        });

        apolloProvider.clients.defaultClient.cache.writeQuery({
          query: organizationWorkItemTypesQuery,
          data: organizationCacheData,
        });

        await findNameInput().vm.$emit('input', 'New type');
        await findSubmitButton().vm.$emit('click');
        await waitForPromises();

        expect(workItemTypesConfigurationHandler).not.toHaveBeenCalled();
      });
    });
  });
});
