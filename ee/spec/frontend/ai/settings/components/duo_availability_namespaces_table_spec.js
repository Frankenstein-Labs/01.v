import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlCollapsibleListbox,
  GlEmptyState,
  GlKeysetPagination,
  GlLoadingIcon,
  GlModal,
  GlTableLite,
} from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import DuoAvailabilityNamespacesTable from 'ee/ai/settings/components/duo_availability_namespaces_table.vue';
import getDuoAvailabilityNamespacesQuery from 'ee/ai/settings/graphql/queries/get_duo_availability_namespaces.query.graphql';
import duoSetNamespaceAvailabilityMutation from 'ee/ai/settings/graphql/mutations/duo_set_namespace_availability.mutation.graphql';
import duoClearNamespaceAvailabilityMutation from 'ee/ai/settings/graphql/mutations/duo_clear_namespace_availability.mutation.graphql';

Vue.use(VueApollo);
jest.mock('~/alert');

const GROUP_LOCKED = {
  __typename: 'AdminDuoAvailabilityNamespace',
  id: 'gid://gitlab/Group/1',
  name: 'Locked Group',
  fullPath: 'parent/locked-group',
  duoAvailability: 'ALWAYS_ON',
  inheritedValue: 'ALWAYS_ON',
  adminLocked: false,
  lockedByAncestor: {
    __typename: 'AdminDuoAvailabilityLockedAncestor',
    id: 'gid://gitlab/Group/0',
    fullPath: 'parent',
  },
};

const GROUP_OVERRIDE = {
  __typename: 'AdminDuoAvailabilityNamespace',
  id: 'gid://gitlab/Group/2',
  name: 'Override Group',
  fullPath: 'override-group',
  duoAvailability: 'DEFAULT_OFF',
  inheritedValue: 'DEFAULT_ON',
  adminLocked: false,
  lockedByAncestor: null,
};

const GROUP_INHERITING = {
  __typename: 'AdminDuoAvailabilityNamespace',
  id: 'gid://gitlab/Group/3',
  name: 'Inheriting Group',
  fullPath: 'inheriting-group',
  duoAvailability: 'DEFAULT_ON',
  inheritedValue: 'DEFAULT_ON',
  adminLocked: false,
  lockedByAncestor: null,
};

const GROUP_ADMIN_LOCKED = {
  __typename: 'AdminDuoAvailabilityNamespace',
  id: 'gid://gitlab/Group/4',
  name: 'Admin Locked Group',
  fullPath: 'admin-locked-group',
  duoAvailability: 'NEVER_ON',
  inheritedValue: 'DEFAULT_ON',
  adminLocked: true,
  lockedByAncestor: null,
};

const buildGroupsResponse = (nodes, pageInfo = {}) => ({
  data: {
    adminDuoAvailabilityNamespaces: {
      __typename: 'AdminDuoAvailabilityNamespaceConnection',
      nodes,
      pageInfo: {
        __typename: 'PageInfo',
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: null,
        ...pageInfo,
      },
    },
  },
});

const setMutationSuccess = (overrides = {}) => ({
  data: {
    adminSetDuoAvailability: {
      availability: 'ALWAYS_ON',
      adminLocked: true,
      conflictingAncestor: null,
      affectedAdminLockedDescendants: { nodes: [] },
      errors: [],
      ...overrides,
    },
  },
});

const clearMutationSuccess = (overrides = {}) => ({
  data: {
    adminClearDuoAvailability: {
      availability: 'DEFAULT_ON',
      adminLocked: false,
      errors: [],
      ...overrides,
    },
  },
});

describe('DuoAvailabilityNamespacesTable', () => {
  let wrapper;

  const createComponent = ({
    props = {},
    queryHandler = jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
    setMutationHandler = jest.fn().mockResolvedValue(setMutationSuccess()),
    clearMutationHandler = jest.fn().mockResolvedValue(clearMutationSuccess()),
  } = {}) => {
    wrapper = mountExtended(DuoAvailabilityNamespacesTable, {
      apolloProvider: createMockApollo([
        [getDuoAvailabilityNamespacesQuery, queryHandler],
        [duoSetNamespaceAvailabilityMutation, setMutationHandler],
        [duoClearNamespaceAvailabilityMutation, clearMutationHandler],
      ]),
      propsData: { enabled: true, ...props },
      stubs: { GlModal: stubComponent(GlModal) },
      directives: { GlTooltip: createMockDirective('gl-tooltip') },
    });

    return { queryHandler, setMutationHandler, clearMutationHandler };
  };

  const findLoading = () => wrapper.findComponent(GlLoadingIcon);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findRowGroup = () => wrapper.findByTestId('duo-availability-namespaces-table-row-group');
  const findLockedValue = () =>
    wrapper.findByTestId('duo-availability-namespaces-table-row-locked-value');
  const findListbox = (id) =>
    wrapper.findComponentByTestId(`duo-availability-namespaces-table-row-listbox-${id}`);
  const findAllListboxes = () => wrapper.findAllComponents(GlCollapsibleListbox);
  const findStatusLocked = () =>
    wrapper.findByTestId('duo-availability-namespaces-table-row-status-locked');
  const findStatusOverride = () =>
    wrapper.findByTestId('duo-availability-namespaces-table-row-status-override');
  const findStatusInheriting = () =>
    wrapper.findByTestId('duo-availability-namespaces-table-row-status-inheriting');
  const findResetButton = () =>
    wrapper.findComponentByTestId('duo-availability-namespaces-table-row-remove-override');
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findResetModal = () =>
    wrapper.findComponentByTestId('duo-availability-namespaces-reset-modal');
  const findCascadeModal = () =>
    wrapper.findComponentByTestId('duo-availability-namespaces-cascade-modal');
  const findCascadeList = () =>
    wrapper.findByTestId('duo-availability-namespaces-cascade-modal-list');

  afterEach(() => {
    createAlert.mockClear();
  });

  describe('loading state', () => {
    it('shows the loading icon while the query is in-flight', () => {
      createComponent();

      expect(findLoading().exists()).toBe(true);
    });

    it('hides the loading icon once the query resolves', async () => {
      createComponent();
      await waitForPromises();

      expect(findLoading().exists()).toBe(false);
    });
  });

  describe('empty state', () => {
    it('renders the empty state when there are no groups', async () => {
      createComponent({ queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([])) });
      await waitForPromises();

      expect(findEmptyState().exists()).toBe(true);
      expect(findTable().exists()).toBe(false);
    });
  });

  describe('when enabled is false', () => {
    it('skips the query', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE]));
      createComponent({ props: { enabled: false }, queryHandler });
      await waitForPromises();

      expect(queryHandler).not.toHaveBeenCalled();
    });
  });

  describe('query error', () => {
    it('shows an alert when the query fails', async () => {
      createComponent({ queryHandler: jest.fn().mockRejectedValue(new Error('nope')) });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'An error occurred while loading the group list.',
        }),
      );
    });
  });

  describe('rendering rows', () => {
    describe('a group locked by an ancestor', () => {
      beforeEach(async () => {
        createComponent({
          queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_LOCKED])),
        });
        await waitForPromises();
      });

      it('renders the group name and path', () => {
        expect(findRowGroup().text()).toContain('Locked Group');
        expect(findRowGroup().text()).toContain('parent/locked-group');
      });

      it('renders the locked availability value instead of a dropdown', () => {
        expect(findLockedValue().exists()).toBe(true);
        expect(findAllListboxes()).toHaveLength(0);
      });

      it('renders the locked status as a single combined sentence with the ancestor path', () => {
        expect(findStatusLocked().text()).toContain('Locked by parent — subgroups cannot opt out.');
      });

      it('does not render the reset button', () => {
        expect(findResetButton().exists()).toBe(false);
      });
    });

    describe('a group with its own override', () => {
      beforeEach(async () => {
        createComponent({
          queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        });
        await waitForPromises();
      });

      it('renders an availability dropdown', () => {
        expect(findListbox(GROUP_OVERRIDE.id).exists()).toBe(true);
      });

      it('renders the override status as a single combined sentence', () => {
        expect(findStatusOverride().text()).toContain(
          'Cascading — subgroups default to off but can opt in individually.',
        );
        expect(findStatusOverride().text()).toContain('Overrides "Default on"');
      });

      it('renders the reset button', () => {
        expect(findResetButton().exists()).toBe(true);
      });

      it('labels the action button', () => {
        expect(findResetButton().text()).toBe('Reset override');
      });

      it('names the group in the action button tooltip and aria-label', () => {
        const button = findResetButton();
        const expectedLabel = 'Reset override for Override Group';

        expect(getBinding(button.element, 'gl-tooltip').value).toBe(expectedLabel);
        expect(button.attributes('aria-label')).toBe(expectedLabel);
      });
    });

    describe('an admin-locked group (the introducer of the lock)', () => {
      beforeEach(async () => {
        createComponent({
          queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_ADMIN_LOCKED])),
        });
        await waitForPromises();
      });

      it('renders the availability value as plain text instead of a dropdown', () => {
        expect(findLockedValue().exists()).toBe(true);
        expect(findAllListboxes()).toHaveLength(0);
      });

      it('renders the availability text correctly', () => {
        expect(findLockedValue().text()).toBe('Always off');
      });

      it('renders the override status cell for the admin-locked group', () => {
        expect(findStatusOverride().exists()).toBe(true);
        expect(findStatusLocked().exists()).toBe(false);
        expect(findStatusInheriting().exists()).toBe(false);
      });

      it('renders the reset button so the admin lock can be removed', () => {
        expect(findResetButton().exists()).toBe(true);
      });

      it('renders a tooltip on the locked value span', () => {
        const tooltip = getBinding(findLockedValue().element, 'gl-tooltip');
        expect(tooltip.value).toBe(
          "This group has an admin lock. Click 'Reset override' to change this value.",
        );
      });
    });

    describe('a group inheriting its value', () => {
      beforeEach(async () => {
        createComponent({
          queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_INHERITING])),
        });
        await waitForPromises();
      });

      it('renders the inheriting status as a single combined sentence', () => {
        expect(findStatusInheriting().text()).toContain(
          'Inheriting — subgroups default to on but can opt out individually.',
        );
      });

      it('does not render the reset button', () => {
        expect(findResetButton().exists()).toBe(false);
      });
    });
  });

  describe('column alignment', () => {
    beforeEach(async () => {
      createComponent({
        queryHandler: jest
          .fn()
          .mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE, GROUP_ADMIN_LOCKED])),
      });
      await waitForPromises();
    });

    it('left-aligns the locked availability value with the column header', () => {
      expect(findLockedValue().classes()).not.toContain('gl-px-3');
    });

    it('right-aligns the actions header to match the right-aligned cell content', () => {
      const actionsHeader = wrapper.findAll('thead th').at(3);

      expect(actionsHeader.text()).toBe('Actions');
      expect(actionsHeader.classes()).toContain('gl-text-right');
    });
  });

  describe('pagination', () => {
    it('does not render pagination when there is only one page', async () => {
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
      });
      await waitForPromises();

      expect(findPagination().exists()).toBe(false);
    });

    it('renders pagination when there is a next page', async () => {
      createComponent({
        queryHandler: jest
          .fn()
          .mockResolvedValue(
            buildGroupsResponse([GROUP_OVERRIDE], { hasNextPage: true, endCursor: 'CURSOR20' }),
          ),
      });
      await waitForPromises();

      expect(findPagination().exists()).toBe(true);
    });

    it('re-queries with the next cursor on @next', async () => {
      const queryHandler = jest
        .fn()
        .mockResolvedValue(
          buildGroupsResponse([GROUP_OVERRIDE], { hasNextPage: true, endCursor: 'CURSOR20' }),
        );
      createComponent({ queryHandler });
      await waitForPromises();

      findPagination().vm.$emit('next');
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ first: 20, after: 'CURSOR20' }),
      );
    });

    it('re-queries with the previous cursor on @prev', async () => {
      const queryHandler = jest.fn().mockResolvedValue(
        buildGroupsResponse([GROUP_OVERRIDE], {
          hasPreviousPage: true,
          startCursor: 'CURSOR1',
        }),
      );
      createComponent({ queryHandler });
      await waitForPromises();

      findPagination().vm.$emit('prev');
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ last: 20, before: 'CURSOR1' }),
      );
    });
  });

  describe('filter prop', () => {
    it('resets the cursor and re-queries when the filter changes', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE]));
      createComponent({ queryHandler, props: { filter: { search: 'foo' } } });
      await waitForPromises();

      await wrapper.setProps({ filter: { search: 'bar' } });
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ search: 'bar', first: 20 }),
      );
      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.not.objectContaining({ after: expect.anything() }),
      );
    });

    it('re-queries the network when switching back to a previously-viewed filter', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE]));
      createComponent({ queryHandler, props: { filter: { adminLocked: true } } });
      await waitForPromises();

      await wrapper.setProps({ filter: { adminLocked: false } });
      await waitForPromises();

      await wrapper.setProps({ filter: { adminLocked: true } });
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledTimes(3);
    });
  });

  describe('runSetMutation', () => {
    it('calls the mutation with the selected availability', async () => {
      const setMutationHandler = jest.fn().mockResolvedValue(setMutationSuccess());
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        setMutationHandler,
      });
      await waitForPromises();

      findListbox(GROUP_OVERRIDE.id).vm.$emit('select', 'ALWAYS_ON');
      await waitForPromises();

      expect(setMutationHandler).toHaveBeenCalledWith({
        groupId: GROUP_OVERRIDE.id,
        availability: 'ALWAYS_ON',
        clearDescendants: false,
      });
    });

    it('does not call the mutation when selecting the currently active value', async () => {
      const setMutationHandler = jest.fn().mockResolvedValue(setMutationSuccess());
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        setMutationHandler,
      });
      await waitForPromises();

      findListbox(GROUP_OVERRIDE.id).vm.$emit('select', GROUP_OVERRIDE.duoAvailability);
      await waitForPromises();

      expect(setMutationHandler).not.toHaveBeenCalled();
    });

    it('refetches groups and clears the row spinner on success', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE]));
      createComponent({
        queryHandler,
        setMutationHandler: jest.fn().mockResolvedValue(setMutationSuccess()),
      });
      await waitForPromises();

      findListbox(GROUP_OVERRIDE.id).vm.$emit('select', 'ALWAYS_ON');
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledTimes(2);
      expect(findListbox(GROUP_OVERRIDE.id).props('loading')).toBe(false);
    });

    it('shows the row spinner while the mutation is in-flight', async () => {
      let resolveMutation;
      const pendingMutation = new Promise((resolve) => {
        resolveMutation = resolve;
      });
      const setMutationHandler = jest.fn().mockReturnValue(pendingMutation);
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        setMutationHandler,
      });
      await waitForPromises();

      findListbox(GROUP_OVERRIDE.id).vm.$emit('select', 'ALWAYS_ON');
      await nextTick();

      expect(findListbox(GROUP_OVERRIDE.id).props('loading')).toBe(true);

      resolveMutation(setMutationSuccess());
      await waitForPromises();
    });

    it('shows an alert with the ancestor path on conflictingAncestor', async () => {
      const setMutationHandler = jest.fn().mockResolvedValue(
        setMutationSuccess({
          availability: null,
          adminLocked: null,
          conflictingAncestor: { id: 'gid://gitlab/Group/9', fullPath: 'parent-group' },
          affectedAdminLockedDescendants: null,
          errors: ['Ancestor group is admin-locked'],
        }),
      );
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        setMutationHandler,
      });
      await waitForPromises();

      findListbox(GROUP_OVERRIDE.id).vm.$emit('select', 'ALWAYS_ON');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message:
          'Cannot update: parent-group is admin-locked. Clear the lock on the ancestor first.',
      });
      expect(findCascadeModal().props('visible')).toBe(false);
    });

    it('opens the cascade modal on affectedAdminLockedDescendants without clearing descendants', async () => {
      const setMutationHandler = jest.fn().mockResolvedValue(
        setMutationSuccess({
          availability: null,
          adminLocked: null,
          conflictingAncestor: null,
          affectedAdminLockedDescendants: {
            nodes: [{ id: 'gid://gitlab/Group/5', fullPath: 'override-group/sub' }],
          },
          errors: ['A subgroup already has an admin-locked GitLab Duo availability override.'],
        }),
      );
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        setMutationHandler,
      });
      await waitForPromises();

      findListbox(GROUP_OVERRIDE.id).vm.$emit('select', 'ALWAYS_ON');
      await waitForPromises();

      expect(createAlert).not.toHaveBeenCalled();
      expect(findCascadeModal().props('visible')).toBe(true);
      expect(findCascadeList().text()).toContain('override-group/sub');
    });

    it('re-runs the mutation with clearDescendants=true when the cascade modal is confirmed', async () => {
      const setMutationHandler = jest
        .fn()
        .mockResolvedValueOnce(
          setMutationSuccess({
            availability: null,
            adminLocked: null,
            conflictingAncestor: null,
            affectedAdminLockedDescendants: {
              nodes: [{ id: 'gid://gitlab/Group/5', fullPath: 'override-group/sub' }],
            },
            errors: ['A subgroup already has an admin-locked GitLab Duo availability override.'],
          }),
        )
        .mockResolvedValueOnce(setMutationSuccess());
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        setMutationHandler,
      });
      await waitForPromises();

      findListbox(GROUP_OVERRIDE.id).vm.$emit('select', 'ALWAYS_ON');
      await waitForPromises();

      findCascadeModal().vm.$emit('primary');
      await waitForPromises();

      expect(setMutationHandler).toHaveBeenLastCalledWith({
        groupId: GROUP_OVERRIDE.id,
        availability: 'ALWAYS_ON',
        clearDescendants: true,
      });
      expect(findCascadeModal().props('visible')).toBe(false);
    });

    it('clears the row spinner when the cascade modal is canceled', async () => {
      const setMutationHandler = jest.fn().mockResolvedValue(
        setMutationSuccess({
          availability: null,
          adminLocked: null,
          conflictingAncestor: null,
          affectedAdminLockedDescendants: {
            nodes: [{ id: 'gid://gitlab/Group/5', fullPath: 'override-group/sub' }],
          },
          errors: ['A subgroup already has an admin-locked GitLab Duo availability override.'],
        }),
      );
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        setMutationHandler,
      });
      await waitForPromises();

      findListbox(GROUP_OVERRIDE.id).vm.$emit('select', 'ALWAYS_ON');
      await waitForPromises();

      findCascadeModal().vm.$emit('canceled');
      await nextTick();

      expect(findCascadeModal().props('visible')).toBe(false);
      expect(findListbox(GROUP_OVERRIDE.id).props('loading')).toBe(false);
    });

    it('shows a generic alert for untyped mutation errors', async () => {
      const setMutationHandler = jest.fn().mockResolvedValue(
        setMutationSuccess({
          availability: null,
          adminLocked: null,
          conflictingAncestor: null,
          affectedAdminLockedDescendants: { nodes: [] },
          errors: ['Something went wrong'],
        }),
      );
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        setMutationHandler,
      });
      await waitForPromises();

      findListbox(GROUP_OVERRIDE.id).vm.$emit('select', 'ALWAYS_ON');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong',
        captureError: true,
      });
    });

    it('shows an alert when the mutation rejects', async () => {
      const setMutationHandler = jest.fn().mockRejectedValue(new Error('network error'));
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        setMutationHandler,
      });
      await waitForPromises();

      findListbox(GROUP_OVERRIDE.id).vm.$emit('select', 'ALWAYS_ON');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'An error occurred while updating the availability.',
        }),
      );
    });
  });

  describe('reset flow', () => {
    it('opens the reset modal when the reset button is clicked', async () => {
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
      });
      await waitForPromises();

      findResetButton().vm.$emit('click');
      await nextTick();

      expect(findResetModal().props('visible')).toBe(true);
      expect(findResetModal().props('title')).toBe('Reset Override Group to inherited value?');
    });

    it('calls the clear mutation when the reset modal is confirmed', async () => {
      const clearMutationHandler = jest.fn().mockResolvedValue(clearMutationSuccess());
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        clearMutationHandler,
      });
      await waitForPromises();

      findResetButton().vm.$emit('click');
      await nextTick();
      findResetModal().vm.$emit('primary');
      await waitForPromises();

      expect(clearMutationHandler).toHaveBeenCalledWith({ groupId: GROUP_OVERRIDE.id });
      expect(findResetModal().props('visible')).toBe(false);
    });

    it('does not call the clear mutation when the reset modal is canceled', async () => {
      const clearMutationHandler = jest.fn().mockResolvedValue(clearMutationSuccess());
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        clearMutationHandler,
      });
      await waitForPromises();

      findResetButton().vm.$emit('click');
      await nextTick();
      findResetModal().vm.$emit('canceled');
      await nextTick();

      expect(clearMutationHandler).not.toHaveBeenCalled();
      expect(findResetModal().props('visible')).toBe(false);
    });

    it('refetches groups on successful reset', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE]));
      createComponent({
        queryHandler,
        clearMutationHandler: jest.fn().mockResolvedValue(clearMutationSuccess()),
      });
      await waitForPromises();

      findResetButton().vm.$emit('click');
      await nextTick();
      findResetModal().vm.$emit('primary');
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledTimes(2);
    });

    it('shows an alert on clear mutation errors', async () => {
      const clearMutationHandler = jest
        .fn()
        .mockResolvedValue(clearMutationSuccess({ errors: ['Cannot reset this group'] }));
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        clearMutationHandler,
      });
      await waitForPromises();

      findResetButton().vm.$emit('click');
      await nextTick();
      findResetModal().vm.$emit('primary');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Cannot reset this group',
        captureError: true,
      });
    });

    it('shows an alert when the clear mutation rejects', async () => {
      const clearMutationHandler = jest.fn().mockRejectedValue(new Error('network error'));
      createComponent({
        queryHandler: jest.fn().mockResolvedValue(buildGroupsResponse([GROUP_OVERRIDE])),
        clearMutationHandler,
      });
      await waitForPromises();

      findResetButton().vm.$emit('click');
      await nextTick();
      findResetModal().vm.$emit('primary');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'An error occurred while resetting the availability.',
        }),
      );
    });
  });
});
