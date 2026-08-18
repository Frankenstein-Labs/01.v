import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { mount } from '@vue/test-utils';
import { GlBadge } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import TimeagoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import CustomFieldForm from 'ee/groups/settings/work_items/custom_fields/custom_field_form.vue';
import CustomFieldsTable from 'ee/groups/settings/work_items/custom_fields/custom_fields_list.vue';
import groupCustomFieldsQuery from 'ee/groups/settings/work_items/custom_fields/group_custom_fields.query.graphql';
import customFieldArchiveMutation from 'ee/groups/settings/work_items/custom_fields/custom_field_archive.mutation.graphql';

Vue.use(VueApollo);

describe('CustomFieldsTable', () => {
  let wrapper;
  let apolloProvider;

  const selectField = {
    id: '1',
    name: 'Test Select Field',
    fieldType: 'SELECT',
    active: true,
    workItemTypes: [{ id: '1', name: 'Issue' }],
    selectOptions: [
      {
        id: 'select-1',
        value: 'value 1',
      },
      {
        id: 'select-2',
        value: 'value 2',
      },
    ],
    updatedAt: '2023-01-01T00:00:00Z',
    createdAt: '2023-01-01T00:00:00Z',
  };

  const stringField = {
    id: '1',
    name: 'Test Text Field',
    fieldType: 'STRING',
    active: true,
    workItemTypes: [
      { id: '1', name: 'Issue' },
      { id: '2', name: 'Task' },
    ],
    selectOptions: [],
    updatedAt: '2023-01-01T00:00:00Z',
    createdAt: '2023-01-01T00:00:00Z',
  };

  const createQueryResponse = (fields = [stringField]) => ({
    data: {
      group: {
        id: '123',
        customFields: {
          nodes: fields,
          count: fields.length,
        },
      },
    },
  });

  const findHelpLink = () => wrapper.findComponent(HelpPageLink);
  const findTableItems = () => wrapper.findAll('tbody tr');
  const findEditButton = () => wrapper.find('[data-testid="editButton"]');
  const findArchiveButton = () => wrapper.findComponent('[data-testid="archiveButton"]');
  const findDetailsButton = () => wrapper.findComponent('[data-testid="toggleDetailsButton"');
  const findAlert = () => wrapper.findComponent('[data-testid="alert"]');
  const findActiveFilterButton = () => wrapper.findComponent('[data-testid="activeFilterButton"]');
  const findArchivedFilterButton = () =>
    wrapper.findComponent('[data-testid="archivedFilterButton"]');
  const findTitle = () => wrapper.find('[data-testid="table-title"]');
  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);

  const createComponent = ({
    fields = [selectField],
    props = {},
    customFieldsResponse = jest.fn().mockResolvedValue({
      data: {
        group: {
          id: '123',
          customFields: {
            nodes: fields,
            count: fields.length,
          },
        },
      },
    }),
    archiveMutationResponse = jest.fn().mockResolvedValue({
      data: {
        customFieldArchive: {
          customField: {
            id: '1',
            name: 'Test Field',
            fieldType: 'STRING',
          },
          errors: [],
        },
      },
    }),
  } = {}) => {
    apolloProvider = createMockApollo([
      [groupCustomFieldsQuery, customFieldsResponse],
      [customFieldArchiveMutation, archiveMutationResponse],
    ]);
    wrapper = mount(CustomFieldsTable, {
      propsData: {
        fullPath: 'group/path',
        id: 'js-custom-fields-settings',
        expanded: false,
        ...props,
      },
      apolloProvider,
      stubs: { GlIntersperse: true, SettingsBlock },
    });
  };

  it('renders a settings block with correct props', () => {
    createComponent();

    expect(findSettingsBlock().props()).toMatchObject({
      id: 'js-custom-fields-settings',
      title: 'Custom fields',
      expanded: false,
    });
  });

  it('renders settings block with expanded prop when provided', () => {
    createComponent({ props: { expanded: true } });

    expect(findSettingsBlock().props('expanded')).toBe(true);
  });

  it('emits toggle-expand event when settings block is toggled', async () => {
    createComponent();

    findSettingsBlock().vm.$emit('toggle-expand', true);
    await nextTick();

    expect(wrapper.emitted('toggle-expand')).toEqual([[true]]);
  });

  it('passes custom id prop to settings block', () => {
    createComponent({ props: { id: 'custom-id' } });

    expect(findSettingsBlock().props('id')).toBe('custom-id');
  });

  it('renders title and help link', () => {
    createComponent();

    expect(wrapper.find('h2').text()).toBe('Custom fields');
    expect(findHelpLink().props('href')).toBe('user/work_items/custom_fields');
    expect(findHelpLink().text()).toBe('How do I use custom fields?');
  });

  describe('fields loaded', () => {
    beforeEach(() => {
      createComponent();
      return waitForPromises();
    });

    it('displays correct count in badge', () => {
      const badge = wrapper.findComponent(GlBadge);
      expect(badge.text()).toBe('1/50');
    });

    it('renders filter buttons', () => {
      expect(findActiveFilterButton().exists()).toBe(true);
      expect(findArchivedFilterButton().exists()).toBe(true);
    });

    it('sets active filter button as selected by default', () => {
      expect(findActiveFilterButton().props('selected')).toBe(true);
      expect(findArchivedFilterButton().props('selected')).toBe(false);
    });

    it('toggles button selected states when clicked', async () => {
      findArchivedFilterButton().vm.$emit('click');

      await nextTick();

      expect(findActiveFilterButton().props('selected')).toBe(false);
      expect(findArchivedFilterButton().props('selected')).toBe(true);
    });

    it('detailsToggleIcon returns correct icon based on visibility', async () => {
      expect(findDetailsButton().props().icon).toBe('chevron-right');

      findDetailsButton().vm.$emit('click');
      await nextTick();

      expect(findDetailsButton().props().icon).toBe('chevron-down');
    });

    it('humanizes field type', () => {
      expect(wrapper.text()).toContain('Select');
    });

    it('selectOptionsText returns correct text based on options length', () => {
      expect(wrapper.text()).toContain('2 options');
    });

    it('lists work item types', () => {
      // Override default component creation for this test
      createComponent({ fields: [stringField] });
      return waitForPromises().then(() => {
        expect(wrapper.text()).toContain('Issue');
        expect(wrapper.text()).toContain('Task');
      });
    });

    it('toggles details when detail button is clicked', async () => {
      expect(wrapper.text()).not.toContain('Last updated');
      findDetailsButton().vm.$emit('click');
      await nextTick();

      expect(wrapper.text()).toContain('Last updated');
    });

    it('renders TimeagoTooltip components with correct timestamps', () => {
      const timeagoComponents = wrapper.findAllComponents(TimeagoTooltip);
      expect(timeagoComponents.exists()).toBe(true);
      expect(timeagoComponents.at(0).props('time')).toBe(selectField.updatedAt);
    });

    it('shows archive icon and edit button for active fields', () => {
      expect(findArchiveButton().props('icon')).toBe('archive');
      expect(findEditButton().exists()).toBe(true);
    });

    it('shows redo icon and no edit button for archived fields', async () => {
      await findArchivedFilterButton().vm.$emit('click');
      await waitForPromises();

      expect(findArchiveButton().props('icon')).toBe('redo');
      expect(findEditButton().exists()).toBe(false);
    });
  });

  it('refetches list after create-custom-field emits created', async () => {
    const customFieldsResponse = jest.fn().mockResolvedValue({
      data: {
        group: {
          id: '123',
          customFields: {
            nodes: [],
            count: 0,
          },
        },
      },
    });

    createComponent({
      customFieldsResponse,
    });
    await waitForPromises();

    expect(customFieldsResponse).toHaveBeenCalledTimes(1);

    wrapper.findComponent(CustomFieldForm).vm.$emit('created');

    expect(customFieldsResponse).toHaveBeenCalledTimes(2);
  });

  it('shows dismissable alert when query fails', async () => {
    createComponent({
      customFieldsResponse: jest.fn().mockRejectedValue(new Error('error')),
    });
    await waitForPromises();
    expect(findAlert().exists()).toBe(true);

    findAlert().vm.$emit('dismiss');
    await nextTick();
    expect(findAlert().exists()).toBe(false);
  });

  it('optimistically removes field when archive button is clicked', async () => {
    const fields = [stringField, { ...stringField, id: '2', name: 'Second Field' }];
    const archiveMutationResponse = jest.fn().mockImplementation(() => new Promise(() => {})); // Never resolves

    createComponent({ fields, archiveMutationResponse });
    await waitForPromises();

    expect(findTableItems()).toHaveLength(2);

    findArchiveButton().vm.$emit('click');
    await nextTick();

    expect(findTableItems()).toHaveLength(1);
  });

  it('updates apollo cache after successful archive', async () => {
    const initialResponse = createQueryResponse([stringField]);
    const customFieldsHandler = jest
      .fn()
      .mockResolvedValueOnce(initialResponse)
      .mockResolvedValueOnce({
        data: {
          group: {
            ...initialResponse.data.group,
            customFields: {
              nodes: [],
              count: 0,
            },
          },
        },
      });

    createComponent({ customFieldsHandler });
    await waitForPromises();

    findArchiveButton().vm.$emit('click');
    await waitForPromises();

    const result = await apolloProvider.clients.defaultClient.query({
      query: groupCustomFieldsQuery,
      variables: { fullPath: 'group/path', active: true },
    });

    expect(result.data.group.customFields.nodes).toHaveLength(0);
  });

  it('shows alert on mutation error', async () => {
    const archiveMutationResponse = jest.fn().mockRejectedValue(new Error('Network error'));

    createComponent({
      archiveMutationResponse,
    });
    await waitForPromises();

    expect(findAlert().exists()).toBe(false);

    findArchiveButton().vm.$emit('click');
    await waitForPromises();

    expect(findAlert().exists()).toBe(true);
    expect(findAlert().text()).toContain(`Failed to archive custom field ${selectField.name}.`);
  });

  it('updates title text when filter changes', async () => {
    createComponent();

    expect(findTitle().text()).toContain('Active custom fields');

    findArchivedFilterButton().vm.$emit('click');
    await nextTick();

    expect(findTitle().text()).toContain('Archived custom fields');
  });

  it('updates query variables when switching to archived view', async () => {
    const customFieldsResponse = jest.fn().mockResolvedValue({
      data: {
        group: {
          id: '123',
          customFields: {
            nodes: [],
            count: 0,
          },
        },
      },
    });

    createComponent({ customFieldsResponse });
    await waitForPromises();

    // First call should be for active fields
    expect(customFieldsResponse).toHaveBeenCalledWith({
      fullPath: 'group/path',
      active: true,
    });

    findArchivedFilterButton().vm.$emit('click');
    await waitForPromises();

    // Second call should be for archived fields
    expect(customFieldsResponse).toHaveBeenCalledWith({
      fullPath: 'group/path',
      active: false,
    });
  });

  it('does not show create button in archived view', async () => {
    createComponent();

    findArchivedFilterButton().vm.$emit('click');
    await nextTick();

    expect(wrapper.findComponent(CustomFieldForm).exists()).toBe(false);
  });

  describe('empty state', () => {
    it('shows empty state message when there are no active fields', async () => {
      const customFieldsResponse = jest.fn().mockResolvedValue({
        data: {
          group: {
            id: '123',
            customFields: {
              nodes: [],
              count: 0,
            },
          },
        },
      });

      createComponent({ customFieldsResponse });
      await waitForPromises();

      expect(findTableItems().at(0).findAll('th')).toHaveLength(0);
      expect(findTableItems().at(0).text()).toContain(
        'This group has no active custom fields. Create a custom field to track data that matters to your team.',
      );
    });

    it('shows empty state message when there are no archived fields', async () => {
      const customFieldsResponse = jest.fn().mockResolvedValue({
        data: {
          group: {
            id: '123',
            customFields: {
              nodes: [],
              count: 0,
            },
          },
        },
      });

      createComponent({ customFieldsResponse });
      await waitForPromises();

      // Switch to archived view
      findArchivedFilterButton().vm.$emit('click');
      await waitForPromises();

      expect(findTableItems().at(0).findAll('th')).toHaveLength(0);
      expect(findTableItems().at(0).text()).toContain(
        'No custom fields have been archived. Archive custom fields to remove them from active work items while preserving their data.',
      );
    });
  });
});
