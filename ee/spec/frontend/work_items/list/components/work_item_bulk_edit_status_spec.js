import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { intersectionBy } from 'lodash-es';
import { GlFormGroup, GlCollapsibleListbox, GlIcon } from '@gitlab/ui';

import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { createAlert } from '~/alert';
import { WIDGET_TYPE_STATUS } from '~/work_items/constants';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import { namespaceWorkItemTypesQueryResponse } from 'jest/work_items/mock_data';

import WorkItemBulkEditStatus from 'ee/work_items/list/components/work_item_bulk_edit_status.vue';

jest.mock('~/alert');

describe('WorkItemBulkEditStatus', () => {
  Vue.use(VueApollo);

  let wrapper;

  const mockCheckedItemsWithAllowedTypes = [
    { workItemType: { id: 'gid://gitlab/WorkItems::Type/1' } }, // Issue
    { workItemType: { id: 'gid://gitlab/WorkItems::Type/5' } }, // Task
  ];
  const statusPerType = [];
  const namespaceQueryHandler = jest.fn().mockResolvedValue(namespaceWorkItemTypesQueryResponse);
  namespaceWorkItemTypesQueryResponse.data.namespace?.workItemTypes?.nodes?.forEach((type) => {
    const statusWidget = type.widgetDefinitions.find(
      (widget) => widget.type === WIDGET_TYPE_STATUS,
    );
    if (statusWidget) {
      statusPerType.push(statusWidget.allowedStatuses);
    }
  });
  const allowedStatuses = intersectionBy(...statusPerType, 'id');

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findDropdownWidget = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDropdownItems = () => wrapper.findAllByTestId('status-list-item');
  const openDropdown = () => {
    findDropdownWidget().vm.$emit('shown');
  };

  const createComponent = ({
    mountFn = shallowMountExtended,
    fullPath = 'gitlab-org/gitlab-test',
    checkedItems = [],
    value = '',
    queryHandler = namespaceQueryHandler,
  } = {}) => {
    wrapper = mountFn(WorkItemBulkEditStatus, {
      apolloProvider: createMockApollo([[namespaceWorkItemTypesQuery, queryHandler]]),
      propsData: {
        fullPath,
        checkedItems,
        value,
      },
    });
  };

  it('renders status widget', async () => {
    createComponent();
    await waitForPromises();

    expect(findFormGroup().exists()).toBe(true);
    expect(findFormGroup().attributes('label')).toBe('Status');

    expect(findDropdownWidget().exists()).toBe(true);
    expect(findDropdownWidget().props('headerText')).toBe('Select status');
    expect(findDropdownWidget().props('toggleText')).toBe('Select status');
  });

  it('shows list of statuses in the dropdown when checkedItems include only supported work item types', async () => {
    createComponent({
      mountFn: mountExtended,
      checkedItems: mockCheckedItemsWithAllowedTypes,
    });

    openDropdown();

    await waitForPromises();

    expect(namespaceQueryHandler).toHaveBeenCalledWith({
      fullPath: 'gitlab-org/gitlab-test',
    });

    const dropdownItems = findDropdownItems();
    expect(dropdownItems).toHaveLength(allowedStatuses.length);

    const dropdownItemIcon = dropdownItems.at(0).findComponent(GlIcon);
    expect(dropdownItemIcon.exists()).toBe(true);
    expect(dropdownItemIcon.props('name')).toBe(allowedStatuses[0].iconName);
    expect(dropdownItemIcon.attributes('style')).toBe('color: rgb(115, 114, 120);');
  });

  it('shows alert when query fails to fetch statuses', async () => {
    createComponent({
      queryHandler: jest.fn().mockRejectedValue({}),
      checkedItems: mockCheckedItemsWithAllowedTypes,
    });

    openDropdown();

    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith({
      captureError: true,
      error: expect.any(Object),
      message: 'Something went wrong while fetching statuses. Please try again.',
    });
  });

  it('shows empty state with appropriate noResultsText when checkedItemsInclude any unsupported work item type', async () => {
    createComponent({
      mountFn: mountExtended,
      checkedItems: [
        ...mockCheckedItemsWithAllowedTypes,
        { workItemType: { id: 'gid://gitlab/WorkItems::Type/2' } }, // Incident
      ],
    });

    openDropdown();

    await waitForPromises();

    expect(findDropdownWidget().props('noResultsText')).toBe(
      'No available status for all selected items.',
    );
    expect(findDropdownItems()).toHaveLength(0);
  });

  it('emits input event when a status is selected', async () => {
    createComponent({
      mountFn: mountExtended,
      checkedItems: mockCheckedItemsWithAllowedTypes,
    });

    openDropdown();

    await waitForPromises();

    findDropdownWidget().vm.$emit('select', allowedStatuses[0]);

    expect(wrapper.emitted('input')).toEqual([[allowedStatuses[0]]]);
  });
});
