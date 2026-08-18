import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlDisclosureDropdown, GlLoadingIcon, GlAlert, GlBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemTypesListEnabledDisabledView from 'ee/work_items/components/work_item_types_list_enabled_disabled_view.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import WorkItemTypeIcon from '~/work_items/components/work_item_type_icon.vue';
import workItemTypesConfigurationQuery from '~/work_items/graphql/work_item_types_configuration.query.graphql';
import { mockWorkItemTypesConfigurationResponse } from 'ee_else_ce_jest/work_items/mock_data';
import namespaceWorkItemSettingsQuery from 'ee/work_items/graphql/namespace_work_item_settings.query.graphql';
import orgWorkItemSettingsQuery from 'ee/work_items/graphql/organization_work_item_settings.query.graphql';
import workItemTypeAvailabilityToggleMutation from 'ee/work_items/graphql/work_item_type_availability_toggle.graphql';

Vue.use(VueApollo);

describe('WorkItemTypesListEnabledDisabledView', () => {
  let wrapper;

  const baseTypes = mockWorkItemTypesConfigurationResponse.data.namespace.workItemTypes.nodes;
  const fullPath = 'test-group';

  const mockToast = { show: jest.fn() };

  const createMockResponse = (types) => ({
    data: {
      namespace: {
        ...mockWorkItemTypesConfigurationResponse.data.namespace,
        workItemTypes: {
          nodes: types,
          __typename: 'WorkItemTypeConnection',
        },
      },
    },
  });

  const successAvailabilityToggleMutationHandler = jest.fn().mockResolvedValue({
    data: {
      workItemAvailabilityToggle: {
        workItemType: mockWorkItemTypesConfigurationResponse.data.namespace.workItemTypes.nodes[0],
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

  const defaultHandler = jest.fn().mockResolvedValue(createMockResponse(baseTypes));

  const namespaceWorkItemSettingsHandler = jest
    .fn()
    .mockResolvedValue(mockWorkItemSettingsResponse());

  const orgWorkItemSettingsHandler = jest.fn().mockResolvedValue(mockOrgWorkItemSettingsResponse());

  const createWrapper = ({
    queryHandler = defaultHandler,
    workItemSettingsHandler = namespaceWorkItemSettingsHandler,
    workItemOrgSettingsHandler = orgWorkItemSettingsHandler,
    availabilityToggleHandler = successAvailabilityToggleMutationHandler,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemTypesListEnabledDisabledView, {
      apolloProvider: createMockApollo([
        [workItemTypesConfigurationQuery, queryHandler],
        [namespaceWorkItemSettingsQuery, workItemSettingsHandler],
        [orgWorkItemSettingsQuery, workItemOrgSettingsHandler],
        [workItemTypeAvailabilityToggleMutation, availabilityToggleHandler],
      ]),
      propsData: {
        config: { enabledWorkItemTypeSettingsPermissions: ['disable', 'enable'] },
        fullPath,
      },
      mocks: {
        $toast: mockToast,
      },
    });
  };

  const findDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findAllCrudComponents = () => wrapper.findAllComponents(CrudComponent);
  const findEnabledCrudComponent = () => findAllCrudComponents().at(0);
  const findDisabledCrudComponent = () => findAllCrudComponents().at(1);
  const findEnabledTypesTable = () => wrapper.findByTestId('enabled-work-item-types-table');
  const findEnabledTypeRows = () => {
    const table = findEnabledTypesTable();
    return table.exists() ? table.findAll('[data-testid^="work-item-type-row"]') : [];
  };
  const findDisabledTypesToggleButton = () =>
    wrapper.findComponentByTestId('disabled-types-toggle-button');
  const findLockedIconById = (id) => wrapper.findByTestId(`locked-icon-${id}`);
  const findAllBadges = () => wrapper.findAllComponents(GlBadge);
  const findEnableAction = (id) => wrapper.findComponentByTestId(`enable-action-${id}`);
  const findDisableAction = (id) => wrapper.findComponentByTestId(`disable-action-${id}`);

  describe('loading state', () => {
    it('shows loading icon while query is in flight', () => {
      createWrapper();

      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('hides content while loading', () => {
      createWrapper();

      expect(findEnabledTypesTable().exists()).toBe(false);
    });
  });

  describe('after query resolves', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('calls the query with correct variables', () => {
      expect(defaultHandler).toHaveBeenCalledWith({ fullPath, includeFilterableFlags: true });
    });

    it('hides loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders enabled types section with correct title', () => {
      expect(findEnabledCrudComponent().exists()).toBe(true);
      expect(findEnabledCrudComponent().props('title')).toBe('Enabled types');
    });

    it('renders enabled work item types table', () => {
      expect(findEnabledTypesTable().exists()).toBe(true);
    });

    it('does not show error alert', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('with mixed enabled/disabled types', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('renders only enabled types in the enabled section', () => {
      const enabledTypes = baseTypes.filter((t) => t.enabled !== false);
      expect(findEnabledTypeRows()).toHaveLength(enabledTypes.length);
    });

    it('renders correct enabled type name', () => {
      const icons = findEnabledTypesTable().findAllComponents(WorkItemTypeIcon);
      expect(icons.at(0).props('workItemType')).toBe(baseTypes[0].name);
    });

    it('shows the disabled types toggle button', () => {
      expect(findDisabledTypesToggleButton().exists()).toBe(true);
    });

    it('displays correct disabled types count label', () => {
      expect(findDisabledTypesToggleButton().text()).toContain('1 disabled type');
    });

    it('does not render disabled crud component by default', () => {
      expect(findAllCrudComponents()).toHaveLength(1);
    });

    it('renders disabled crud component when toggle button is clicked', async () => {
      findDisabledTypesToggleButton().vm.$emit('click');
      await nextTick();

      expect(findDisabledCrudComponent().exists()).toBe(true);
      expect(findDisabledCrudComponent().props('title')).toBe('Disabled types');
    });

    it('renders correct disabled type names after toggle', async () => {
      findDisabledTypesToggleButton().vm.$emit('click');
      await nextTick();

      const icons = findDisabledCrudComponent().findAllComponents(WorkItemTypeIcon);
      expect(icons).toHaveLength(1);
      expect(icons.at(0).props('workItemType')).toBe(baseTypes[1].name);
    });

    it('hides disabled crud component when toggled again', async () => {
      findDisabledTypesToggleButton().vm.$emit('click');
      await nextTick();
      findDisabledTypesToggleButton().vm.$emit('click');
      await nextTick();

      expect(findAllCrudComponents()).toHaveLength(1);
    });
  });

  describe('when all types are enabled', () => {
    beforeEach(async () => {
      const allEnabled = baseTypes.map((t) => ({ ...t, enabled: true }));
      const handler = jest.fn().mockResolvedValue(createMockResponse(allEnabled));
      createWrapper({ queryHandler: handler });
      await waitForPromises();
    });

    it('does not render disabled types toggle button', () => {
      expect(findDisabledTypesToggleButton().exists()).toBe(false);
    });

    it('renders all types in enabled section', () => {
      expect(findEnabledTypeRows()).toHaveLength(baseTypes.length);
    });

    it('calls availability toggle mutation with DISABLE action when disable option is clicked', async () => {
      await findDisableAction(baseTypes[0].id).vm.$emit('action');
      await waitForPromises();

      expect(successAvailabilityToggleMutationHandler).toHaveBeenCalledWith({
        input: {
          workItemTypeId: baseTypes[0].id,
          action: 'DISABLE',
          scope: 'THIS',
          fullPath: 'test-group',
        },
      });
      expect(mockToast.show).toHaveBeenCalledWith('Issue disabled.');
    });
  });

  describe('when all types are disabled', () => {
    beforeEach(async () => {
      const allDisabled = baseTypes.map((t) => ({ ...t, enabled: false }));
      const handler = jest.fn().mockResolvedValue(createMockResponse(allDisabled));
      createWrapper({ queryHandler: handler });
      await waitForPromises();
    });

    it('renders enabled types table with no rows', () => {
      expect(findEnabledTypesTable().exists()).toBe(true);
      expect(findEnabledTypeRows()).toHaveLength(0);
    });

    it('shows disabled types toggle button', () => {
      expect(findDisabledTypesToggleButton().exists()).toBe(true);
    });

    it('displays correct plural label for multiple disabled types', () => {
      expect(findDisabledTypesToggleButton().text()).toContain(
        `${baseTypes.length} disabled types`,
      );
    });

    it('calls availability toggle mutation with ENABLE action when enable option is clicked', async () => {
      await findDisabledTypesToggleButton().vm.$emit('click');
      await findEnableAction(baseTypes[0].id).vm.$emit('action');
      await waitForPromises();

      expect(successAvailabilityToggleMutationHandler).toHaveBeenCalledWith({
        input: {
          workItemTypeId: baseTypes[0].id,
          action: 'ENABLE',
          scope: 'THIS',
          fullPath: 'test-group',
        },
      });
      expect(mockToast.show).toHaveBeenCalledWith('Issue enabled.');
    });
  });

  describe('when customizableTypeVisibility is false', () => {
    it('hides disabled options', async () => {
      const allEnabled = baseTypes.map((t) => ({ ...t, enabled: true }));
      createWrapper({
        queryHandler: jest.fn().mockResolvedValue(createMockResponse(allEnabled)),
        workItemSettingsHandler: jest.fn().mockResolvedValue(mockWorkItemSettingsResponse(false)),
      });
      await waitForPromises();

      expect(findDisclosureDropdown().exists()).toBe(false);
    });

    it('hides enabled options', async () => {
      const allDisabled = baseTypes.map((t) => ({ ...t, enabled: false }));
      createWrapper({
        queryHandler: jest.fn().mockResolvedValue(createMockResponse(allDisabled)),
        workItemSettingsHandler: jest.fn().mockResolvedValue(mockWorkItemSettingsResponse(false)),
      });
      await waitForPromises();

      await findDisabledTypesToggleButton().vm.$emit('click');

      expect(findDisclosureDropdown().exists()).toBe(false);
    });
  });

  describe('when query returns empty nodes', () => {
    beforeEach(async () => {
      const handler = jest.fn().mockResolvedValue(createMockResponse([]));
      createWrapper({ queryHandler: handler });
      await waitForPromises();
    });

    it('renders enabled types section with no rows', () => {
      expect(findEnabledCrudComponent().exists()).toBe(true);
      expect(findEnabledTypeRows()).toHaveLength(0);
    });

    it('does not render disabled types toggle', () => {
      expect(findDisabledTypesToggleButton().exists()).toBe(false);
    });
  });

  describe('error handling', () => {
    it('shows error alert with correct message', async () => {
      const handler = jest.fn().mockRejectedValue(new Error('GraphQL error'));
      createWrapper({ queryHandler: handler });
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toBe('Failed to fetch work item types.');
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('shows error alert when disable mutation fails', async () => {
      createWrapper({
        availabilityToggleHandler: errorAvailabilityToggleMutationHandler,
      });
      await waitForPromises();

      await findDisableAction(baseTypes[0].id).vm.$emit('action');
      await waitForPromises();

      expect(findAlert().text()).toBe('Something went wrong');
    });

    it('allows dismissing error alert', async () => {
      createWrapper({ queryHandler: jest.fn().mockRejectedValue('Network error') });
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);

      await findAlert().vm.$emit('dismiss');

      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('lock badge for non-configurable types', () => {
    const baseMessage = 'This is a system type that cannot be renamed, disabled, or deleted.';

    const createNonConfigurableItem = (overrides = {}) => ({
      ...baseTypes[0],
      isConfigurable: false,
      isServiceDesk: false,
      isGroupWorkItemType: false,
      isIncidentManagement: false,
      ...overrides,
    });

    const mountWithItem = async (item) => {
      const handler = jest.fn().mockResolvedValue(createMockResponse([item]));
      createWrapper({ queryHandler: handler });
      await waitForPromises();
    };

    it('does not show lock badge for configurable items', async () => {
      createWrapper();
      await waitForPromises();

      expect(findAllBadges()).toHaveLength(0);
    });

    it('shows lock badge for non-configurable item in enabled section', async () => {
      const item = createNonConfigurableItem();
      await mountWithItem(item);

      expect(findLockedIconById(item.id).exists()).toBe(true);
    });

    it('does not show lock badge for configurable item in enabled section', async () => {
      const item = { ...baseTypes[0], isConfigurable: true };
      const handler = jest.fn().mockResolvedValue(createMockResponse([item]));
      createWrapper({ queryHandler: handler });
      await waitForPromises();

      expect(findLockedIconById(item.id).exists()).toBe(false);
    });

    it('shows lock badge for non-configurable item in disabled section', async () => {
      const disabledItem = {
        ...createNonConfigurableItem(),
        ...baseTypes[1],
        isConfigurable: false,
      };
      const handler = jest.fn().mockResolvedValue(createMockResponse([baseTypes[0], disabledItem]));
      createWrapper({ queryHandler: handler });
      await waitForPromises();

      findDisabledTypesToggleButton().vm.$emit('click');
      await nextTick();

      expect(findLockedIconById(disabledItem.id).exists()).toBe(true);
    });

    it('does not show lock badge for configurable item in disabled section', async () => {
      const disabledItem = { ...baseTypes[1], isConfigurable: true };
      const handler = jest.fn().mockResolvedValue(createMockResponse([baseTypes[0], disabledItem]));
      createWrapper({ queryHandler: handler });
      await waitForPromises();

      findDisabledTypesToggleButton().vm.$emit('click');
      await nextTick();

      expect(findLockedIconById(disabledItem.id).exists()).toBe(false);
    });

    it('shows only the base message as tooltip when no special flags are set', async () => {
      const item = createNonConfigurableItem();
      await mountWithItem(item);

      const badge = findLockedIconById(item.id);
      expect(badge.attributes('title')).toBe(baseMessage);
      expect(badge.attributes('aria-label')).toBe(baseMessage);
    });

    it.each`
      flag                      | overrides                         | suffix
      ${'isServiceDesk'}        | ${{ isServiceDesk: true }}        | ${'Usage is controlled by the Service Desk feature.'}
      ${'isGroupWorkItemType'}  | ${{ isGroupWorkItemType: true }}  | ${'Usage is limited to groups.'}
      ${'isIncidentManagement'} | ${{ isIncidentManagement: true }} | ${'Usage is controlled by the Monitor feature.'}
    `('appends $flag text to tooltip', async ({ overrides, suffix }) => {
      const item = createNonConfigurableItem(overrides);
      await mountWithItem(item);

      const badge = findLockedIconById(item.id);
      const expectedText = `${baseMessage} ${suffix}`;
      expect(badge.attributes('title')).toBe(expectedText);
      expect(badge.attributes('aria-label')).toBe(expectedText);
    });

    it('isServiceDesk takes precedence over isGroupWorkItemType in tooltip', async () => {
      const item = createNonConfigurableItem({ isServiceDesk: true, isGroupWorkItemType: true });
      await mountWithItem(item);

      const badge = findLockedIconById(item.id);
      expect(badge.attributes('title')).toContain('Service Desk');
      expect(badge.attributes('title')).not.toContain('groups');
    });
  });
});
