import Vue from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlAlert,
  GlButton,
  GlDisclosureDropdown,
  GlLoadingIcon,
  GlDisclosureDropdownItem,
  GlButtonGroup,
  GlIcon,
} from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemTypesList from 'ee/work_items/components/work_item_types_list.vue';
import CreateEditWorkItemTypeForm from 'ee/work_items/components/create_edit_work_item_type_form.vue';
import ArchiveWorkItemTypeModal from 'ee/work_items/components/archive_work_item_type_modal.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import WorkItemTypeIcon from '~/work_items/components/work_item_type_icon.vue';
import organizationWorkItemTypesQuery from 'ee/work_items/graphql/organization_work_item_types.query.graphql';
import workItemTypeIconDefinitionsQuery from 'ee/work_items/graphql/work_item_type_icon_definitions.query.graphql';
import {
  organizationWorkItemTypesQueryResponse,
  mockWorkItemTypesConfigurationResponse,
  mockWorkItemTypeIconDefinitionsResponse,
  mockWorkItemTypeIcons,
} from 'ee_else_ce_jest/work_items/mock_data';
import { getSettingsConfig, ACTIVE_TYPES_LIMIT, WARNING_THRESHOLD } from 'ee/work_items/constants';
import workItemTypesConfigurationQuery from '~/work_items/graphql/work_item_types_configuration.query.graphql';
import workItemTypeUpdateMutation from 'ee/work_items/graphql/update_work_item_type.mutation.graphql';
import workItemTypeAvailabilityToggleMutation from 'ee/work_items/graphql/work_item_type_availability_toggle.graphql';
import namespaceWorkItemSettingsQuery from 'ee/work_items/graphql/namespace_work_item_settings.query.graphql';
import orgWorkItemSettingsQuery from 'ee/work_items/graphql/organization_work_item_settings.query.graphql';

Vue.use(VueApollo);

describe('WorkItemTypesList', () => {
  let wrapper;
  let mockApollo;
  const WARNING_LIMIT = ACTIVE_TYPES_LIMIT * WARNING_THRESHOLD;

  const buildNamespaceResponse = (nodes) => ({
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        workItemTypes: {
          nodes,
          __typename: 'WorkItemTypeConnection',
        },
        __typename: 'Namespace',
      },
    },
  });

  const mockEmptyResponse = buildNamespaceResponse([]);

  const getMockWorkItemTypes = () =>
    mockWorkItemTypesConfigurationResponse.data.namespace.workItemTypes.nodes;
  const getMockOrganisationWorkItemTypes = () =>
    organizationWorkItemTypesQueryResponse.data.organization.workItemTypes.nodes;
  const mockOrganisationWorkItemTypes = getMockOrganisationWorkItemTypes();
  const mockWorkItemTypes = getMockWorkItemTypes();
  const namespaceQueryHandler = jest.fn().mockResolvedValue(mockWorkItemTypesConfigurationResponse);
  const organizationWorkItemTypesQueryHandler = jest
    .fn()
    .mockResolvedValue(organizationWorkItemTypesQueryResponse);
  const mockEmptyResponseHandler = jest.fn().mockResolvedValue(mockEmptyResponse);
  const successMutationHandler = jest.fn().mockResolvedValue({
    data: {
      workItemTypeUpdate: {
        workItemType: {
          id: 'gid://gitlab/WorkItemType/1',
          name: 'Bug',
          iconName: 'issue-type-issue',
          archived: false,
          __typename: 'WorkItemType',
        },
        errors: [],
        __typename: 'WorkItemTypeUpdatePayload',
      },
    },
  });
  const errorMutationHandler = jest.fn().mockResolvedValue({
    data: {
      workItemTypeUpdate: {
        workItemType: null,
        errors: ['Something went wrong'],
        __typename: 'WorkItemTypeUpdatePayload',
      },
    },
  });
  const workItemTypeIconDefinitionsHandler = jest
    .fn()
    .mockResolvedValue(mockWorkItemTypeIconDefinitionsResponse);

  const successAvailabilityToggleMutationHandler = jest.fn().mockResolvedValue({
    data: {
      workItemAvailabilityToggle: {
        workItemType: {
          id: 'gid://gitlab/WorkItemType/1',
          name: 'Bug',
          iconName: 'issue-type-issue',
          archived: false,
          __typename: 'WorkItemType',
        },
        errors: [],
        __typename: 'WorkItemAvailabilityTogglePayload',
      },
    },
  });

  const errorAvailabilityToggleMutationHandler = jest.fn().mockResolvedValue({
    data: {
      workItemAvailabilityToggle: {
        workItemType: null,
        errors: ['Something went wrong'],
        __typename: 'WorkItemAvailabilityTogglePayload',
      },
    },
  });

  const atLimitActivetTypes = Array.from({ length: ACTIVE_TYPES_LIMIT }, (_, i) => ({
    ...mockWorkItemTypes[0],
    id: `gid://gitlab/WorkItemType/${i}`,
    archived: false,
  }));

  const warningThresholdActiveTypes = Array.from({ length: WARNING_LIMIT }, (_, i) => ({
    ...mockWorkItemTypes[0],
    id: `gid://gitlab/WorkItemType/${i}`,
    archived: false,
  }));

  const mockWorkItemSettingsResponse = (customizableTypeVisibility = true) => ({
    data: {
      namespace: {
        __typename: 'Group',
        id: 'gid://gitlab/Group/1',
        workItemSettings: {
          __typename: 'WorkItemSettings',
          customizableTypeVisibility,
        },
      },
    },
  });

  const mockOrgWorkItemSettingsResponse = (customizableTypeVisibility = true) => ({
    data: {
      organization: {
        __typename: 'Organization',
        id: 'gid://gitlab/Organization/1',
        workItemSettings: {
          __typename: 'WorkItemSettings',
          customizableTypeVisibility,
        },
      },
    },
  });

  const namespaceWorkItemSettingsHandler = jest
    .fn()
    .mockResolvedValue(mockWorkItemSettingsResponse());

  const orgWorkItemSettingsHandler = jest.fn().mockResolvedValue(mockOrgWorkItemSettingsResponse());

  const createWrapper = ({
    queryHandler = namespaceQueryHandler,
    orgWorkItemTypesHandler = organizationWorkItemTypesQueryHandler,
    mutationHandler = successMutationHandler,
    availabilityToggleHandler = successAvailabilityToggleMutationHandler,
    iconDefinitionsHandler = workItemTypeIconDefinitionsHandler,
    workItemSettingsHandler = namespaceWorkItemSettingsHandler,
    workItemOrgSettingsHandler = orgWorkItemSettingsHandler,
    props = {},
    mountFn = mountExtended,
  } = {}) => {
    const defaultProps = {
      config: {
        ...getSettingsConfig(),
      },
    };

    mockApollo = createMockApollo([
      [workItemTypesConfigurationQuery, queryHandler],
      [organizationWorkItemTypesQuery, orgWorkItemTypesHandler],
      [workItemTypeUpdateMutation, mutationHandler],
      [workItemTypeAvailabilityToggleMutation, availabilityToggleHandler],
      [workItemTypeIconDefinitionsQuery, iconDefinitionsHandler],
      [namespaceWorkItemSettingsQuery, workItemSettingsHandler],
      [orgWorkItemSettingsQuery, workItemOrgSettingsHandler],
    ]);

    wrapper = mountFn(WorkItemTypesList, {
      apolloProvider: mockApollo,
      propsData: {
        fullPath: 'test-group',
        ...defaultProps,
        ...props,
      },
      mocks: {
        $toast: { show: jest.fn().mockReturnValue({ hide: jest.fn() }) },
      },
      stubs: {
        CrudComponent,
        GlButton,
      },
    });
  };

  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findWorkItemTypesTable = () => wrapper.findByTestId('work-item-types-table');
  const findWorkItemTypeRows = () => wrapper.findAll('[data-testid^="work-item-type-row"]');
  const findWorkItemTypeRow = (id) => wrapper.findByTestId(`work-item-type-row-${id}`);
  const findLockedIconByRow = (id) => wrapper.findByTestId(`locked-icon-${id}`);
  const findNewTypeButton = () => wrapper.findComponentByTestId('new-type-button');
  const findDropdownForType = (id) => findWorkItemTypeRow(id).findComponent(GlDisclosureDropdown);
  const findErrorAlert = () => wrapper.findComponent(GlAlert);
  const findCreateEditForm = () => wrapper.findComponent(CreateEditWorkItemTypeForm);
  const findButtonGroup = () => wrapper.findComponent(GlButtonGroup);
  const findArchiveButtons = () => findButtonGroup().findAllComponents(GlButton);
  const findActiveButton = () => findArchiveButtons().at(0);
  const findArchivedButton = () => findArchiveButtons().at(1);
  const findLimitBadge = () => wrapper.findComponentByTestId('active-types-limit-badge');
  const findAtLimitMessage = () => wrapper.findByTestId('at-limit-message');
  const findArchiveModal = () => wrapper.findComponent(ArchiveWorkItemTypeModal);
  const findEnableForAllProjectsAction = (id) =>
    wrapper.findComponentByTestId(`enable-for-all-projects-action-${id}`);
  const findDisableForAllProjectsAction = (id) =>
    wrapper.findComponentByTestId(`disable-for-all-projects-action-${id}`);

  const findLockIconTooltip = (typeId) => {
    const icon = findLockedIconByRow(typeId);
    return icon.attributes('title');
  };

  describe('default rendering', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('renders the component with CrudComponent', () => {
      expect(findCrudComponent().exists()).toBe(true);
      expect(findCrudComponent().props('title')).toBe('Active types');
    });

    it('renders the work item types table', () => {
      expect(findWorkItemTypesTable().exists()).toBe(true);
    });

    it('renders WorkItemTypeIcon for each type', () => {
      const icons = wrapper.findAllComponents(WorkItemTypeIcon);

      expect(icons).toHaveLength(mockWorkItemTypes.length);
      icons.wrappers.forEach((icon, index) => {
        expect(icon.props()).toMatchObject({
          workItemType: mockWorkItemTypes[index].name,
        });
      });
    });

    it('renders New type button', () => {
      expect(findNewTypeButton().exists()).toBe(true);
      expect(findNewTypeButton().text()).toContain('New type');
    });

    it('renders dropdown for each work item type', () => {
      const dropdowns = wrapper.findAllComponents(GlDisclosureDropdown);

      expect(dropdowns).toHaveLength(mockWorkItemTypes.length);
    });

    it('renders dropdowns with correct items', () => {
      mockWorkItemTypes.forEach((mockWorkItemType) => {
        const dropdown = findDropdownForType(mockWorkItemType.id);
        expect(dropdown.findAllComponents(GlDisclosureDropdownItem)).toHaveLength(4);
        expect(dropdown.findAllComponents(GlDisclosureDropdownItem).at(0).text()).toContain(
          'Edit name and icon',
        );
        expect(dropdown.findAllComponents(GlDisclosureDropdownItem).at(1).text()).toContain(
          'Enable for all projects',
        );
        expect(dropdown.findAllComponents(GlDisclosureDropdownItem).at(2).text()).toContain(
          'Disable for all projects',
        );
        expect(dropdown.findAllComponents(GlDisclosureDropdownItem).at(3).text()).toContain(
          'Archive',
        );
      });
    });

    it('renders dropdown items with correct icons', () => {
      mockWorkItemTypes.forEach((mockWorkItemType) => {
        const dropdown = findDropdownForType(mockWorkItemType.id);
        const dropdownItems = dropdown.findAllComponents(GlDisclosureDropdownItem);

        // Edit item should have pencil icon
        const editItem = dropdownItems.at(0);
        const editItemIcon = editItem.findComponent(GlIcon);
        expect(editItemIcon.props('name')).toBe('pencil');

        // Archive item should have archive icon
        const archiveItem = dropdownItems.at(3);
        const archiveItemIcon = archiveItem.findComponent(GlIcon);
        expect(archiveItemIcon.props('name')).toBe('archive');
      });
    });

    it('renders dropdown with correct toggle attributes', () => {
      const dropdown = findDropdownForType(mockWorkItemTypes[0].id);

      expect(dropdown.props('toggleId')).toBe(`work-item-type-actions-${mockWorkItemTypes[0].id}`);
      expect(dropdown.props('icon')).toBe('ellipsis_v');
      expect(dropdown.props('noCaret')).toBe(true);
    });
  });

  describe('Edit name and icon option', () => {
    const activeType = { ...getMockWorkItemTypes()[0], archived: false };
    const archivedType = {
      ...getMockWorkItemTypes()[0],
      id: 'gid://gitlab/WorkItems::Type/99',
      archived: true,
    };

    it('shows edit option for active types', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      createWrapper({ queryHandler });
      await waitForPromises();

      const items = findDropdownForType(activeType.id).findAllComponents(GlDisclosureDropdownItem);
      expect(items.at(0).text()).toContain('Edit name and icon');
    });

    it('hides edit option for archived types', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([archivedType]));
      createWrapper({ queryHandler });
      await waitForPromises();

      await findArchivedButton().vm.$emit('click');

      const items = findDropdownForType(archivedType.id).findAllComponents(
        GlDisclosureDropdownItem,
      );
      expect(items).toHaveLength(1);
      expect(items.at(0).text()).not.toContain('Edit name and icon');
    });

    it('hides edit option for active types when user cannot edit', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      createWrapper({
        queryHandler,
        props: { config: { workItemTypeSettingsPermissions: ['archive'] } },
      });
      await waitForPromises();

      const items = findDropdownForType(activeType.id).findAllComponents(GlDisclosureDropdownItem);
      expect(items).toHaveLength(1);
      expect(items.at(0).text()).not.toContain('Edit name and icon');
    });
  });

  describe('Enable for all projects option', () => {
    const activeType = { ...getMockWorkItemTypes()[0], archived: false };
    const archivedType = {
      ...getMockWorkItemTypes()[0],
      id: 'gid://gitlab/WorkItems::Type/99',
      archived: true,
    };

    it('shows enable option for active types when user has enable permission', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      createWrapper({
        queryHandler,
        props: { config: { workItemTypeSettingsPermissions: ['enable'] } },
      });
      await waitForPromises();

      expect(findEnableForAllProjectsAction(activeType.id).exists()).toBe(true);
      expect(findEnableForAllProjectsAction(activeType.id).text()).toContain(
        'Enable for all projects',
      );
    });

    it('hides enable option for archived types', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([archivedType]));
      createWrapper({
        queryHandler,
        props: { config: { workItemTypeSettingsPermissions: ['enable'] } },
      });
      await waitForPromises();

      await findArchivedButton().vm.$emit('click');

      expect(findEnableForAllProjectsAction(archivedType.id).exists()).toBe(false);
    });

    it('hides enable option when user does not have enable permission', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      createWrapper({
        queryHandler,
        props: { config: { workItemTypeSettingsPermissions: ['edit', 'archive'] } },
      });
      await waitForPromises();

      expect(findEnableForAllProjectsAction(activeType.id).exists()).toBe(false);
    });

    it('calls availability toggle mutation with ENABLE action when enable option is clicked', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      createWrapper({
        queryHandler,
        props: { config: { workItemTypeSettingsPermissions: ['enable'] } },
      });
      await waitForPromises();

      await findEnableForAllProjectsAction(activeType.id).vm.$emit('action');
      await waitForPromises();

      expect(successAvailabilityToggleMutationHandler).toHaveBeenCalledWith({
        input: {
          workItemTypeId: activeType.id,
          action: 'ENABLE',
          scope: 'ALL_CHILDREN',
          fullPath: 'test-group',
        },
      });
    });

    it('shows success toast after enabling for all projects', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      createWrapper({
        queryHandler,
        props: { config: { workItemTypeSettingsPermissions: ['enable'] } },
      });
      await waitForPromises();

      await findEnableForAllProjectsAction(activeType.id).vm.$emit('action');
      await waitForPromises();

      expect(successAvailabilityToggleMutationHandler).toHaveBeenCalledWith({
        input: {
          workItemTypeId: activeType.id,
          action: 'ENABLE',
          scope: 'ALL_CHILDREN',
          fullPath: 'test-group',
        },
      });
    });

    it('shows error alert when enable mutation fails', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      createWrapper({
        queryHandler,
        availabilityToggleHandler: errorAvailabilityToggleMutationHandler,
        props: { config: { workItemTypeSettingsPermissions: ['enable'] } },
      });
      await waitForPromises();

      await findEnableForAllProjectsAction(activeType.id).vm.$emit('action');
      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().text()).toContain('Something went wrong');
    });
  });

  describe('Disable for all projects option', () => {
    const activeType = { ...getMockWorkItemTypes()[0], archived: false };
    const archivedType = {
      ...getMockWorkItemTypes()[0],
      id: 'gid://gitlab/WorkItems::Type/99',
      archived: true,
    };

    it('shows disable option for active types when user has disable permission', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      createWrapper({
        queryHandler,
        props: { config: { workItemTypeSettingsPermissions: ['disable'] } },
      });
      await waitForPromises();

      expect(findDisableForAllProjectsAction(activeType.id).exists()).toBe(true);
      expect(findDisableForAllProjectsAction(activeType.id).text()).toContain(
        'Disable for all projects',
      );
    });

    it('hides disable option for archived types', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([archivedType]));
      createWrapper({
        queryHandler,
        props: { config: { workItemTypeSettingsPermissions: ['disable'] } },
      });
      await waitForPromises();

      await findArchivedButton().vm.$emit('click');

      expect(findDisableForAllProjectsAction(archivedType.id).exists()).toBe(false);
    });

    it('hides disable option when user does not have disable permission', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      createWrapper({
        queryHandler,
        props: { config: { workItemTypeSettingsPermissions: ['edit', 'archive'] } },
      });
      await waitForPromises();

      expect(findDisableForAllProjectsAction(activeType.id).exists()).toBe(false);
    });

    it('calls availability toggle mutation with DISABLE action when disable option is clicked', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      createWrapper({
        queryHandler,
        props: { config: { workItemTypeSettingsPermissions: ['disable'] } },
      });
      await waitForPromises();

      await findDisableForAllProjectsAction(activeType.id).vm.$emit('action');
      await waitForPromises();

      expect(successAvailabilityToggleMutationHandler).toHaveBeenCalledWith({
        input: {
          workItemTypeId: activeType.id,
          action: 'DISABLE',
          scope: 'ALL_CHILDREN',
          fullPath: 'test-group',
        },
      });
    });

    it('shows success toast after disabling for all projects', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      createWrapper({
        queryHandler,
        props: { config: { workItemTypeSettingsPermissions: ['disable'] } },
      });
      await waitForPromises();

      await findDisableForAllProjectsAction(activeType.id).vm.$emit('action');
      await waitForPromises();

      expect(successAvailabilityToggleMutationHandler).toHaveBeenCalledWith({
        input: {
          workItemTypeId: activeType.id,
          action: 'DISABLE',
          scope: 'ALL_CHILDREN',
          fullPath: 'test-group',
        },
      });
    });

    it('shows error alert when disable mutation fails', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      createWrapper({
        queryHandler,
        availabilityToggleHandler: errorAvailabilityToggleMutationHandler,
        props: { config: { workItemTypeSettingsPermissions: ['disable'] } },
      });
      await waitForPromises();

      await findDisableForAllProjectsAction(activeType.id).vm.$emit('action');
      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().text()).toContain('Something went wrong');
    });
  });

  describe('customizableTypeVisibility gating', () => {
    const activeType = { ...getMockWorkItemTypes()[0], archived: false };

    it('hides enable and disable options when customizableTypeVisibility is false', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      const settingsHandler = jest.fn().mockResolvedValue(mockWorkItemSettingsResponse(false));
      createWrapper({
        queryHandler,
        workItemSettingsHandler: settingsHandler,
        props: { config: { workItemTypeSettingsPermissions: ['enable', 'disable'] } },
      });
      await waitForPromises();

      expect(findEnableForAllProjectsAction(activeType.id).exists()).toBe(false);
      expect(findDisableForAllProjectsAction(activeType.id).exists()).toBe(false);
    });

    it('shows enable and disable options when customizableTypeVisibility is true', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      const settingsHandler = jest.fn().mockResolvedValue(mockWorkItemSettingsResponse(true));
      createWrapper({
        queryHandler,
        workItemSettingsHandler: settingsHandler,
        props: { config: { workItemTypeSettingsPermissions: ['enable', 'disable'] } },
      });
      await waitForPromises();

      expect(findEnableForAllProjectsAction(activeType.id).exists()).toBe(true);
      expect(findDisableForAllProjectsAction(activeType.id).exists()).toBe(true);
    });

    it('uses org settings query when fullPath is not provided', async () => {
      const orgSettingsHandler = jest.fn().mockResolvedValue(mockOrgWorkItemSettingsResponse(true));
      createWrapper({
        orgWorkItemTypesHandler: organizationWorkItemTypesQueryHandler,
        workItemOrgSettingsHandler: orgSettingsHandler,
        props: { fullPath: '', config: { workItemTypeSettingsPermissions: ['enable', 'disable'] } },
      });
      await waitForPromises();

      expect(orgSettingsHandler).toHaveBeenCalled();
    });
  });

  describe('actions disclosure dropdown visibility', () => {
    const activeType = { ...getMockWorkItemTypes()[0], archived: false };
    const archivedType = {
      ...getMockWorkItemTypes()[0],
      id: 'gid://gitlab/WorkItems::Type/99',
      archived: true,
    };

    it('hides the disclosure dropdown when user has none of edit, enable, disable, or archive permissions', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      createWrapper({
        queryHandler,
        props: { config: { workItemTypeSettingsPermissions: [] } },
      });
      await waitForPromises();

      expect(findDropdownForType(activeType.id).exists()).toBe(false);
    });

    it.each`
      permission   | label
      ${'edit'}    | ${'edit'}
      ${'enable'}  | ${'enable'}
      ${'disable'} | ${'disable'}
      ${'archive'} | ${'archive'}
    `(
      'shows the disclosure dropdown when user only has $label permission',
      async ({ permission }) => {
        const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
        createWrapper({
          queryHandler,
          props: { config: { workItemTypeSettingsPermissions: [permission] } },
        });
        await waitForPromises();

        expect(findDropdownForType(activeType.id).exists()).toBe(true);
      },
    );

    it('hides the disclosure dropdown for archived types when user only has edit/enable/disable permissions', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([archivedType]));
      createWrapper({
        queryHandler,
        props: { config: { workItemTypeSettingsPermissions: ['edit', 'enable', 'disable'] } },
      });
      await waitForPromises();

      await findArchivedButton().vm.$emit('click');

      expect(findDropdownForType(archivedType.id).exists()).toBe(false);
    });

    it('hides the disclosure dropdown when enable/disable are the only permissions but customizableTypeVisibility is false', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([activeType]));
      const settingsHandler = jest.fn().mockResolvedValue(mockWorkItemSettingsResponse(false));
      createWrapper({
        queryHandler,
        workItemSettingsHandler: settingsHandler,
        props: { config: { workItemTypeSettingsPermissions: ['enable', 'disable'] } },
      });
      await waitForPromises();

      expect(findDropdownForType(activeType.id).exists()).toBe(false);
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows loading state when query is loading', () => {
      expect(findLoadingIcon().exists()).toBe(true);
      expect(findWorkItemTypesTable().exists()).toBe(false);
    });

    it('hides loading state after query resolves', async () => {
      expect(findLoadingIcon().exists()).toBe(true);

      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
      expect(findWorkItemTypesTable().exists()).toBe(true);
    });

    it('does not show loading icon during refetch when types are already loaded', async () => {
      createWrapper();
      await waitForPromises();

      await wrapper.vm.$apollo.queries.workItemTypes.refetch();

      expect(findLoadingIcon().exists()).toBe(false);
      expect(findWorkItemTypesTable().exists()).toBe(true);
    });
  });

  describe('empty state', () => {
    beforeEach(async () => {
      createWrapper({ queryHandler: mockEmptyResponseHandler });
      await waitForPromises();
    });

    it('renders table even when no work item types exist', () => {
      expect(findWorkItemTypesTable().exists()).toBe(true);
    });

    it('does not render any work item type rows', () => {
      expect(findWorkItemTypeRows()).toHaveLength(0);
    });

    it('still renders New type button', () => {
      expect(findNewTypeButton().exists()).toBe(true);
    });
  });

  describe('namespace work item types query', () => {
    it('passes correct fullPath to query', async () => {
      createWrapper({ props: { fullPath: 'my-group/sub-group' } });

      await waitForPromises();

      expect(namespaceQueryHandler).toHaveBeenCalledWith({
        fullPath: 'my-group/sub-group',
        includeFilterableFlags: true,
      });
    });

    it('error handling', async () => {
      const errorQueryHandler = jest.fn().mockRejectedValue('Network error');
      createWrapper({ queryHandler: errorQueryHandler });

      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().text()).toContain('Failed to fetch work item types');
    });
  });

  describe('CreateEditWorkItemTypeForm integration', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: shallowMountExtended });
      await waitForPromises();
    });

    it('form is hidden by default', () => {
      expect(findCreateEditForm().props('isVisible')).toBe(false);
    });

    it('passes workItemTypeIcons to the form', () => {
      expect(findCreateEditForm().props('workItemTypeIcons')).toEqual(mockWorkItemTypeIcons);
    });

    it('opens form when New type button is clicked', async () => {
      await findNewTypeButton().vm.$emit('click');

      expect(findCreateEditForm().props('isVisible')).toBe(true);
      expect(findCreateEditForm().props('isEditMode')).toBe(false);
      expect(findCreateEditForm().props('workItemType')).toBe(null);
    });

    it('opens form in edit mode when Edit action is clicked', async () => {
      const firstType = mockWorkItemTypes[0];
      const dropdown = findDropdownForType(firstType.id);
      const editItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(0);

      await editItem.vm.$emit('action');

      expect(findCreateEditForm().props('isVisible')).toBe(true);
      expect(findCreateEditForm().props('isEditMode')).toBe(true);
      expect(findCreateEditForm().props('workItemType')).toEqual(
        expect.objectContaining({ id: firstType.id }),
      );
    });

    it('closes form when close event is emitted', async () => {
      await findNewTypeButton().vm.$emit('click');
      expect(findCreateEditForm().props('isVisible')).toBe(true);

      await findCreateEditForm().vm.$emit('close');

      expect(findCreateEditForm().props('isVisible')).toBe(false);
      expect(findCreateEditForm().props('workItemType')).toBe(null);
    });

    it('clears selected work item type when form closes', async () => {
      const firstType = mockWorkItemTypes[0];
      const dropdown = findDropdownForType(firstType.id);
      const editItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(0);

      await editItem.vm.$emit('action');
      expect(findCreateEditForm().props('workItemType')).toEqual(
        expect.objectContaining({ id: firstType.id }),
      );

      await findCreateEditForm().vm.$emit('close');

      expect(findCreateEditForm().props('workItemType')).toBe(null);
    });

    it.each`
      scenario    | refetchTypes                                                                                                                   | expectedLength
      ${'create'} | ${[...getMockWorkItemTypes(), { ...getMockWorkItemTypes()[0], id: 'gid://gitlab/WorkItemType/new', name: 'New Custom Type' }]} | ${getMockWorkItemTypes().length + 1}
      ${'update'} | ${getMockWorkItemTypes().map((t, i) => (i === 0 ? { ...t, name: 'Updated Task', iconName: 'issue-type-task' } : t))}           | ${getMockWorkItemTypes().length}
    `(
      'refetches work item types on create/edit form success after $scenario',
      async ({ refetchTypes, expectedLength }) => {
        const refetchResponse = buildNamespaceResponse(refetchTypes);
        const queryHandler = jest
          .fn()
          .mockResolvedValueOnce(mockWorkItemTypesConfigurationResponse)
          .mockResolvedValueOnce(refetchResponse);

        createWrapper({ queryHandler, mountFn: shallowMountExtended });
        await waitForPromises();

        expect(findWorkItemTypeRows()).toHaveLength(mockWorkItemTypes.length);

        await findCreateEditForm().vm.$emit('success');
        await waitForPromises();

        expect(findWorkItemTypeRows()).toHaveLength(expectedLength);

        const icons = wrapper.findAllComponents(WorkItemTypeIcon);
        refetchTypes
          .filter((t) => !t.archived)
          .forEach((type, index) => {
            expect(findWorkItemTypeRow(type.id).exists()).toBe(true);
            expect(icons.at(index).props('workItemType')).toBe(type.name);
          });
      },
    );

    it('opens form in create mode after closing edit mode', async () => {
      const firstType = mockWorkItemTypes[0];
      const dropdown = findDropdownForType(firstType.id);
      const editItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(0);

      // Open in edit mode
      await editItem.vm.$emit('action');
      expect(findCreateEditForm().props('isEditMode')).toBe(true);

      // Close form
      await findCreateEditForm().vm.$emit('close');

      // Open in create mode
      await findNewTypeButton().vm.$emit('click');
      expect(findCreateEditForm().props('isEditMode')).toBe(false);
      expect(findCreateEditForm().props('workItemType')).toBe(null);
    });
  });

  describe('organisation query', () => {
    beforeEach(async () => {
      createWrapper({ props: { fullPath: '' } });
      await waitForPromises();
    });

    it('calls organisation work item types query handler', () => {
      expect(organizationWorkItemTypesQueryHandler).toHaveBeenCalledWith({});
    });

    it('does not call namespace query handler', () => {
      expect(namespaceQueryHandler).not.toHaveBeenCalled();
    });

    it('renders work item types from organisation query', () => {
      expect(findWorkItemTypeRows()).toHaveLength(mockOrganisationWorkItemTypes.length);

      mockOrganisationWorkItemTypes.forEach((type) => {
        expect(findWorkItemTypeRow(type.id).exists()).toBe(true);
      });
    });

    it('renders WorkItemTypeIcon for each organisation work item type', () => {
      const icons = wrapper.findAllComponents(WorkItemTypeIcon);

      expect(icons).toHaveLength(mockOrganisationWorkItemTypes.length);
      icons.wrappers.forEach((icon, index) => {
        expect(icon.props()).toMatchObject({
          workItemType: mockOrganisationWorkItemTypes[index].name,
        });
      });
    });

    it('renders dropdowns for organisation work item types', () => {
      const dropdowns = wrapper.findAllComponents(GlDisclosureDropdown);

      expect(dropdowns).toHaveLength(mockOrganisationWorkItemTypes.length);
    });

    it('renders dropdowns with correct items for organisation types', () => {
      mockOrganisationWorkItemTypes.forEach((mockWorkItemType) => {
        const dropdown = findDropdownForType(mockWorkItemType.id);
        const dropdownItems = dropdown.findAllComponents(GlDisclosureDropdownItem);
        expect(dropdownItems).toHaveLength(4);
        expect(dropdownItems.at(0).text()).toContain('Edit name and icon');
        expect(dropdownItems.at(1).text()).toContain('Enable for all projects');
        expect(dropdownItems.at(2).text()).toContain('Disable for all projects');
        expect(dropdownItems.at(3).text()).toContain('Archive');
      });
    });

    it('handles organisation query error', async () => {
      const errorOrgQueryHandler = jest.fn().mockRejectedValue('Network error');
      createWrapper({
        orgWorkItemTypesHandler: errorOrgQueryHandler,
        props: { fullPath: '' },
      });

      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().text()).toContain('Failed to fetch work item types');
    });
  });

  describe('error handling', () => {
    it('handles namespace query error', async () => {
      const errorQueryHandler = jest.fn().mockRejectedValue('Network error');
      createWrapper({ queryHandler: errorQueryHandler });

      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().text()).toContain('Failed to fetch work item types');
    });

    it('handles icon definitions query error', async () => {
      const errorIconDefinitionsHandler = jest.fn().mockRejectedValue('Network error');
      createWrapper({ iconDefinitionsHandler: errorIconDefinitionsHandler });

      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().text()).toContain('Failed to fetch work item type icons.');
    });

    it('allows dismissing error alert', async () => {
      const errorQueryHandler = jest.fn().mockRejectedValue('Network error');
      createWrapper({ queryHandler: errorQueryHandler });

      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);

      await findErrorAlert().vm.$emit('dismiss');

      expect(findErrorAlert().exists()).toBe(false);
    });
  });

  describe('query selection based on fullPath', () => {
    it('does not call namespace query when fullPath is empty', async () => {
      createWrapper({ props: { fullPath: '' } });
      await waitForPromises();

      expect(namespaceQueryHandler).not.toHaveBeenCalled();
    });

    it('calls namespace query when fullPath is provided', async () => {
      createWrapper({ props: { fullPath: 'test-group' } });
      await waitForPromises();

      expect(namespaceQueryHandler).toHaveBeenCalled();
    });
  });

  describe('locked configuration tooltip', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('does not render locked icons configurable work item types', () => {
      const firstType = mockWorkItemTypes[0];
      const lockIcon = findLockedIconByRow(firstType.id);

      expect(lockIcon.exists()).toBe(false);
    });

    it('includes service desk message when isServiceDesk is true', async () => {
      const serviceDeskType = {
        ...mockWorkItemTypes[0],
        isServiceDesk: true,
        isConfigurable: false,
      };

      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([serviceDeskType]));

      createWrapper({ queryHandler });
      await waitForPromises();

      const tooltipText = findLockIconTooltip(serviceDeskType.id);
      expect(tooltipText).toContain('Usage is controlled by the Service Desk feature.');
    });

    it('includes group limitation message when isGroupWorkItemType is true', async () => {
      const groupType = {
        ...mockWorkItemTypes[0],
        isGroupWorkItemType: true,
        isConfigurable: false,
      };

      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([groupType]));

      createWrapper({ queryHandler });
      await waitForPromises();

      const tooltipText = findLockIconTooltip(groupType.id);
      expect(tooltipText).toContain('Usage is limited to groups.');
    });

    it('includes incident message when isIncidentManagement is true', async () => {
      const incidentType = {
        ...mockWorkItemTypes[0],
        isIncidentManagement: true,
        isConfigurable: false,
      };

      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([incidentType]));

      createWrapper({ queryHandler });
      await waitForPromises();

      const tooltipText = findLockIconTooltip(incidentType.id);
      expect(tooltipText).toContain('Usage is controlled by the Monitor feature.');
    });

    it('does not render lock icon for configurable types', async () => {
      const nonConfigurableType = {
        ...mockWorkItemTypes[0],
        isConfigurable: true,
      };

      const queryHandler = jest
        .fn()
        .mockResolvedValue(buildNamespaceResponse([nonConfigurableType]));

      createWrapper({ queryHandler });
      await waitForPromises();

      const lockIcon = findLockedIconByRow(nonConfigurableType.id);
      expect(lockIcon.exists()).toBe(false);
    });
  });

  describe('archive/unarchive button group', () => {
    describe('visibility', () => {
      it('does not render button group when no archived types exist', async () => {
        createWrapper();
        await waitForPromises();

        expect(findButtonGroup().exists()).toBe(false);
      });

      it('renders button group when archived types exist', async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findButtonGroup().exists()).toBe(true);
      });
    });

    describe('button labels and state', () => {
      beforeEach(async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();
      });

      it('renders Active and Archived buttons and Active button is selected by default', () => {
        expect(findActiveButton().text()).toContain('Active');
        expect(findArchivedButton().text()).toContain('Archived');

        expect(findActiveButton().props('selected')).toBe(true);
        expect(findArchivedButton().props('selected')).toBe(false);
      });
    });

    describe('filtering functionality', () => {
      beforeEach(async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          id: 'gid://gitlab/WorkItemType/1',
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          id: 'gid://gitlab/WorkItemType/2',
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();
      });

      it('displays only active types when Active button is selected', () => {
        expect(findWorkItemTypeRows()).toHaveLength(1);
        expect(findWorkItemTypeRow('gid://gitlab/WorkItemType/2').exists()).toBe(true);
      });

      it('displays only archived types when Archived button is clicked', async () => {
        await findArchivedButton().vm.$emit('click');

        expect(findWorkItemTypeRows()).toHaveLength(1);
        expect(findWorkItemTypeRow('gid://gitlab/WorkItemType/1').exists()).toBe(true);
      });

      it('toggles between active and archived types', async () => {
        // Initially showing active types
        expect(findWorkItemTypeRows()).toHaveLength(1);
        expect(findWorkItemTypeRow('gid://gitlab/WorkItemType/2').exists()).toBe(true);

        // Click Archived button
        await findArchivedButton().vm.$emit('click');
        expect(findWorkItemTypeRows()).toHaveLength(1);
        expect(findWorkItemTypeRow('gid://gitlab/WorkItemType/1').exists()).toBe(true);

        // Click Active button again
        await findActiveButton().vm.$emit('click');
        expect(findWorkItemTypeRows()).toHaveLength(1);
        expect(findWorkItemTypeRow('gid://gitlab/WorkItemType/2').exists()).toBe(true);
      });
    });

    describe('title and description changes', () => {
      beforeEach(async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();
      });

      it('displays "Types" title when showing active types', () => {
        expect(findCrudComponent().props('title')).toBe('Active types');
      });

      it('displays "Archived types" title when showing archived types', async () => {
        await findArchivedButton().vm.$emit('click');

        expect(findCrudComponent().props('title')).toBe('Archived types');
      });

      it('displays description only when showing archived types', async () => {
        expect(findCrudComponent().props('description')).toBe('');

        await findArchivedButton().vm.$emit('click');

        expect(findCrudComponent().props('description')).toContain(
          'Disabled in all groups and projects',
        );
      });

      it('clears description when switching back to active types', async () => {
        await findArchivedButton().vm.$emit('click');
        expect(findCrudComponent().props('description')).not.toBe('');

        await findActiveButton().vm.$emit('click');
        expect(findCrudComponent().props('description')).toBe('');
      });
    });

    describe('button selection state', () => {
      beforeEach(async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();
      });

      it('updates selected state when Active button is clicked', async () => {
        await findArchivedButton().vm.$emit('click');
        expect(findActiveButton().props('selected')).toBe(false);
        expect(findArchivedButton().props('selected')).toBe(true);

        await findActiveButton().vm.$emit('click');
        expect(findActiveButton().props('selected')).toBe(true);
        expect(findArchivedButton().props('selected')).toBe(false);
      });

      it('updates selected state when Archived button is clicked', async () => {
        expect(findActiveButton().props('selected')).toBe(true);
        expect(findArchivedButton().props('selected')).toBe(false);

        await findArchivedButton().vm.$emit('click');
        expect(findActiveButton().props('selected')).toBe(false);
        expect(findArchivedButton().props('selected')).toBe(true);
      });
    });

    describe('New type button visibility', () => {
      beforeEach(async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();
      });

      it('shows New type button when viewing active types', () => {
        expect(findNewTypeButton().exists()).toBe(true);
      });

      it('hides New type button when viewing archived types', async () => {
        await findArchivedButton().trigger('click');

        expect(findNewTypeButton().exists()).toBe(false);
      });

      it('shows New type button again when switching back to active types', async () => {
        await findArchivedButton().trigger('click');
        expect(findNewTypeButton().exists()).toBe(false);

        await findActiveButton().vm.$emit('click');
        expect(findNewTypeButton().exists()).toBe(true);
      });
    });
  });

  describe('limit and count badge', () => {
    describe('badge visibility', () => {
      it('displays badge when showing active types', async () => {
        createWrapper();
        await waitForPromises();

        expect(findLimitBadge().exists()).toBe(true);
      });

      it('hides badge when showing archived types', async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();

        await findArchivedButton().vm.$emit('click');

        expect(findLimitBadge().exists()).toBe(false);
      });
    });

    describe('badge count display', () => {
      it('displays correct count format "current/limit"', async () => {
        createWrapper();
        await waitForPromises();

        expect(findLimitBadge().text()).toBe(`${mockWorkItemTypes.length}/${ACTIVE_TYPES_LIMIT}`);
      });

      it('displays zero count when no active types exist', async () => {
        const queryHandler = jest.fn().mockResolvedValue(mockEmptyResponse);
        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findLimitBadge().text()).toBe(`0/${ACTIVE_TYPES_LIMIT}`);
      });

      it('updates count when switching between active and archived tabs', async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          id: 'gid://gitlab/WorkItemType/1',
          archived: true,
        };
        const activeType1 = {
          ...mockWorkItemTypes[1],
          id: 'gid://gitlab/WorkItemType/2',
          archived: false,
        };
        const activeType2 = {
          ...mockWorkItemTypes[2],
          id: 'gid://gitlab/WorkItemType/3',
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType1, activeType2]));

        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findLimitBadge().text()).toBe(`2/${ACTIVE_TYPES_LIMIT}`);

        await findArchivedButton().vm.$emit('click');
        // Badge should be hidden when viewing archived types
        expect(findLimitBadge().exists()).toBe(false);

        await findActiveButton().vm.$emit('click');
        expect(findLimitBadge().text()).toBe(`2/${ACTIVE_TYPES_LIMIT}`);
      });
    });

    describe('badge variant based on limit status', () => {
      it('displays neutral variant when below warning threshold', async () => {
        createWrapper();
        await waitForPromises();

        expect(findLimitBadge().props('variant')).toBe('neutral');
      });

      it('displays warning variant when at or above warning threshold but below limit', async () => {
        // Create 32 active types (at warning threshold)
        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse(warningThresholdActiveTypes));
        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findLimitBadge().props('variant')).toBe('warning');
      });

      it('displays danger variant when at limit', async () => {
        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse(atLimitActivetTypes));
        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findLimitBadge().props('variant')).toBe('danger');
      });

      it('transitions from neutral to warning when approaching limit', async () => {
        // Start with 31 types (below warning threshold)
        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse(warningThresholdActiveTypes.slice(1)));
        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findLimitBadge().props('variant')).toBe('neutral');
      });
    });

    describe('badge tooltip', () => {
      it('displays tooltip even when below warning threshold', async () => {
        createWrapper();
        await waitForPromises();

        const tooltip = findLimitBadge().attributes('title');
        expect(tooltip).toContain(`Active types are limited to ${ACTIVE_TYPES_LIMIT}`);
      });

      it('displays warning tooltip when at or above warning threshold but below limit', async () => {
        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse(warningThresholdActiveTypes.slice(1)));
        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findLimitBadge().attributes('title')).toBe('Active types are limited to 40.');
      });

      it('displays limit reached tooltip when at limit with no tooltip', async () => {
        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse(atLimitActivetTypes));
        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findLimitBadge().attributes('title')).toBe('');
      });
    });

    describe('limit text display', () => {
      it('does not display limit text when below limit', async () => {
        createWrapper();
        await waitForPromises();

        expect(findAtLimitMessage().exists()).toBe(false);
      });

      it('displays limit text with count when at limit', async () => {
        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse(atLimitActivetTypes));
        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findAtLimitMessage().text()).toBe(
          'Active types are limited to 40. Archive one or more types to add active types.',
        );
      });
    });

    describe('New type button visibility based on limit', () => {
      it('shows New type button when below limit', async () => {
        createWrapper();
        await waitForPromises();

        expect(findNewTypeButton().exists()).toBe(true);
      });

      it('hides New type button when at limit', async () => {
        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse(atLimitActivetTypes));
        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findNewTypeButton().exists()).toBe(false);
      });

      it('shows New type button when below limit but near warning threshold', async () => {
        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse(warningThresholdActiveTypes));
        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findNewTypeButton().exists()).toBe(true);
      });

      it('hides New type button when viewing archived types regardless of limit', async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();

        await findArchivedButton().vm.$emit('click');

        expect(findNewTypeButton().exists()).toBe(false);
      });
    });

    describe('badge with different type counts', () => {
      it('displays correct count with 1 active type', async () => {
        const types = [
          {
            ...mockWorkItemTypes[0],
            id: 'gid://gitlab/WorkItemType/1',
            archived: false,
          },
        ];

        const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse(types));
        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findLimitBadge().text()).toBe(`1/${ACTIVE_TYPES_LIMIT}`);
      });

      it('displays correct count with maximum active types', async () => {
        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse(atLimitActivetTypes));
        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findLimitBadge().text()).toBe(`${ACTIVE_TYPES_LIMIT}/${ACTIVE_TYPES_LIMIT}`);
      });

      it('displays correct count with mixed active and archived types', async () => {
        const types = Array.from({ length: 50 }, (_, i) => ({
          ...mockWorkItemTypes[0],
          id: `gid://gitlab/WorkItemType/${i}`,
          archived: i < 10, // First 10 are archived
        }));

        const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse(types));
        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findLimitBadge().text()).toBe(`40/${ACTIVE_TYPES_LIMIT}`);
      });
    });
  });

  describe('Archive work item type', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: shallowMountExtended });
      await waitForPromises();
    });

    it('renders archive modal with null workItemType by default', () => {
      expect(findArchiveModal().exists()).toBe(true);
      expect(findArchiveModal().props('workItemType')).toBe(null);
    });

    it('passes fullPath to archive modal', () => {
      expect(findArchiveModal().props('fullPath')).toBe('test-group');
    });

    it('passes work item type to archive modal when archive action is clicked on active type', async () => {
      const firstType = mockWorkItemTypes[0];
      const dropdown = findDropdownForType(firstType.id);
      const archiveItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(3);

      await archiveItem.vm.$emit('action');

      expect(findArchiveModal().props('workItemType')).toEqual(
        expect.objectContaining({ id: firstType.id }),
      );
    });

    it('clears work item type when archive modal emits close', async () => {
      const firstType = mockWorkItemTypes[0];
      const dropdown = findDropdownForType(firstType.id);
      const archiveItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(3);

      await archiveItem.vm.$emit('action');
      expect(findArchiveModal().props('workItemType')).not.toBe(null);

      await findArchiveModal().vm.$emit('close');

      expect(findArchiveModal().props('workItemType')).toBe(null);
    });

    it('shows toast with undo when archive modal emits success', async () => {
      const workItemType = mockWorkItemTypes[0];

      await findArchiveModal().vm.$emit('success', { archived: true, workItemType });

      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith('Type archived.', {
        action: {
          text: 'Undo',
          onClick: expect.any(Function),
        },
      });
    });

    it('shows error alert when archive modal emits error', async () => {
      expect(findErrorAlert().exists()).toBe(false);

      await findArchiveModal().vm.$emit('error', { message: 'Something went wrong' });

      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().text()).toContain('Something went wrong');
    });
  });

  describe('direct unarchive (no modal)', () => {
    const archivedType = {
      ...getMockWorkItemTypes()[0],
      id: 'gid://gitlab/WorkItemType/1',
      archived: true,
    };
    const activeType = {
      ...getMockWorkItemTypes()[1],
      id: 'gid://gitlab/WorkItemType/2',
      archived: false,
    };

    it('calls mutation directly without showing modal for archived types', async () => {
      const queryHandler = jest
        .fn()
        .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

      createWrapper({ queryHandler, mountFn: shallowMountExtended });
      await waitForPromises();

      await findArchivedButton().vm.$emit('click');

      const dropdown = findDropdownForType(archivedType.id);
      const unarchiveItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(0);

      await unarchiveItem.vm.$emit('action');
      await waitForPromises();

      expect(findArchiveModal().props('workItemType')).toBe(null);
      expect(successMutationHandler).toHaveBeenCalledWith({
        input: {
          id: archivedType.id,
          archive: false,
          fullPath: 'test-group',
        },
      });
    });

    it('shows toast on successful unarchive', async () => {
      const queryHandler = jest
        .fn()
        .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

      createWrapper({ queryHandler, mountFn: shallowMountExtended });
      await waitForPromises();

      await findArchivedButton().vm.$emit('click');

      const dropdown = findDropdownForType(archivedType.id);
      const unarchiveItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(0);

      await unarchiveItem.vm.$emit('action');
      await waitForPromises();

      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith('Type unarchived.', expect.any(Object));
    });

    it('shows error alert on failed unarchive', async () => {
      const queryHandler = jest
        .fn()
        .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

      createWrapper({
        queryHandler,
        mutationHandler: errorMutationHandler,
        mountFn: shallowMountExtended,
      });
      await waitForPromises();

      await findArchivedButton().vm.$emit('click');

      const dropdown = findDropdownForType(archivedType.id);
      const unarchiveItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(0);

      await unarchiveItem.vm.$emit('action');
      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().text()).toContain('Something went wrong');
    });

    describe('when at active types limit', () => {
      const archivedTypeAtLimit = {
        ...getMockWorkItemTypes()[0],
        id: 'gid://gitlab/WorkItemType/at-limit-archived',
        archived: true,
      };

      const atLimitWithArchivedTypes = [...atLimitActivetTypes, archivedTypeAtLimit];

      it('does not call mutation when trying to unarchive at limit', async () => {
        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse(atLimitWithArchivedTypes));

        createWrapper({ queryHandler, mountFn: shallowMountExtended });
        await waitForPromises();

        await findArchivedButton().vm.$emit('click');

        const dropdown = findDropdownForType(archivedTypeAtLimit.id);
        const unarchiveItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(0);

        await unarchiveItem.vm.$emit('action');
        await waitForPromises();

        expect(successMutationHandler).not.toHaveBeenCalled();
      });

      it('shows limit error message when trying to unarchive at limit', async () => {
        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse(atLimitWithArchivedTypes));

        createWrapper({ queryHandler, mountFn: shallowMountExtended });
        await waitForPromises();

        await findArchivedButton().vm.$emit('click');

        const dropdown = findDropdownForType(archivedTypeAtLimit.id);
        const unarchiveItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(0);

        await unarchiveItem.vm.$emit('action');
        await waitForPromises();

        expect(findErrorAlert().exists()).toBe(true);
        expect(findErrorAlert().text()).toContain(
          `Cannot unarchive type. You've reached the limit of ${ACTIVE_TYPES_LIMIT} active work item types.`,
        );
      });
    });

    describe('when archiving types', () => {
      it('switches to active tab when last archived type is unarchived', async () => {
        const refetchResponse = buildNamespaceResponse([
          { ...archivedType, archived: false },
          activeType,
        ]);
        const queryHandler = jest
          .fn()
          .mockResolvedValueOnce(buildNamespaceResponse([archivedType, activeType]))
          .mockResolvedValueOnce(refetchResponse);

        createWrapper({ queryHandler, mountFn: shallowMountExtended });
        await waitForPromises();

        await findArchivedButton().vm.$emit('click');

        const dropdown = findDropdownForType(archivedType.id);
        const unarchiveItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(0);
        await unarchiveItem.vm.$emit('action');
        await waitForPromises();

        expect(findCrudComponent().props('title')).toBe('Active types');
        expect(findButtonGroup().exists()).toBe(false);
      });

      it('stays on archived tab when other archived types still exist', async () => {
        const secondArchivedType = {
          ...archivedType,
          id: 'gid://gitlab/WorkItemType/3',
        };
        const refetchResponse = buildNamespaceResponse([
          { ...archivedType, archived: false },
          secondArchivedType,
          activeType,
        ]);
        const queryHandler = jest
          .fn()
          .mockResolvedValueOnce(
            buildNamespaceResponse([archivedType, secondArchivedType, activeType]),
          )
          .mockResolvedValueOnce(refetchResponse);

        createWrapper({ queryHandler, mountFn: shallowMountExtended });
        await waitForPromises();

        await findArchivedButton().vm.$emit('click');

        const dropdown = findDropdownForType(archivedType.id);
        const unarchiveItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(0);
        await unarchiveItem.vm.$emit('action');
        await waitForPromises();

        expect(findCrudComponent().props('title')).toBe('Archived types');
        expect(findArchivedButton().props('selected')).toBe(true);
      });
    });
  });
});
