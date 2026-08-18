import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlCollapsibleListbox,
  GlFormInput,
  GlDatepicker,
  GlFormCheckbox,
  GlModal,
} from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { ALERT_CONTAINER_SELECTOR } from 'ee/pages/projects/shared/permissions/secrets_manager/constants';
import PermissionsModal from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_modal.vue';
import createSecretsPermissionMutation from 'ee/pages/projects/shared/permissions/secrets_manager/graphql/create_secrets_permission.mutation.graphql';
import createGroupSecretsPermissionMutation from 'ee/pages/projects/shared/permissions/secrets_manager/graphql/create_group_secrets_permission.mutation.graphql';
import searchProjectMembersQuery from '~/graphql_shared/queries/project_user_members_search.query.graphql';
import groupUsersSearchQuery from '~/graphql_shared/queries/group_users_search.query.graphql';
import { SECRETS_MANAGER_PERMISSIONS_CONTEXT_CONFIG } from 'ee/pages/projects/shared/permissions/secrets_manager/context_config';
import { ENTITY_PROJECT, ENTITY_GROUP } from 'ee/ci/secrets/constants';
import {
  mockCreatePermissionResponse,
  mockCreatePermissionErrorResponse,
  mockCreateGroupPermissionResponse,
  mockCreateGroupPermissionErrorResponse,
  mockGroupMembersQueryResponse,
  mockProjectMembersQueryResponse,
} from '../mock_data';

jest.mock('~/alert');

const mockToastShow = jest.fn();
Vue.use(VueApollo);

describe('SecretsManagerPermissionsModal', () => {
  let wrapper;
  let mockApollo;
  let mockCreatePermission;
  let mockMemberSearchQuery;

  const contextConfigs = [
    {
      context: 'project',
      fullPath: '/path/to/project',
      mutation: createSecretsPermissionMutation,
      memberSearchQuery: searchProjectMembersQuery,
      mockSuccessResponse: mockCreatePermissionResponse,
      mockErrorResponse: mockCreatePermissionErrorResponse,
      mockMemberSearchQueryResponse: mockProjectMembersQueryResponse,
      relations: SECRETS_MANAGER_PERMISSIONS_CONTEXT_CONFIG[ENTITY_PROJECT].searchMembers.relations,
    },
    {
      context: 'group',
      fullPath: '/path/to/group',
      mutation: createGroupSecretsPermissionMutation,
      memberSearchQuery: groupUsersSearchQuery,
      mockSuccessResponse: mockCreateGroupPermissionResponse,
      mockErrorResponse: mockCreateGroupPermissionErrorResponse,
      mockMemberSearchQueryResponse: mockGroupMembersQueryResponse,
      relations: SECRETS_MANAGER_PERMISSIONS_CONTEXT_CONFIG[ENTITY_GROUP].searchMembers.relations,
    },
  ];

  const createComponent = ({ permissionCategory = null, context = 'project' } = {}) => {
    const config = contextConfigs.find((c) => c.context === context);

    mockApollo = createMockApollo([
      [config.mutation, mockCreatePermission],
      [config.memberSearchQuery, mockMemberSearchQuery],
    ]);

    wrapper = shallowMountExtended(PermissionsModal, {
      apolloProvider: mockApollo,
      propsData: {
        permissionCategory,
        fullPath: config.fullPath,
        projectId: 123,
        context,
      },
      provide: {
        groupPathRegex: /^[\w.-]+(?:\/[\w.-]+)*$/,
      },
      mocks: {
        $toast: { show: mockToastShow },
      },
    });
  };

  const findDatepicker = () => wrapper.findComponent(GlDatepicker);
  const findCheckbox = (index) => wrapper.findAllComponents(GlFormCheckbox).at(index);
  const findModal = () => wrapper.findComponent(GlModal);
  const findPrincipalField = () => wrapper.findComponent(GlCollapsibleListbox);
  const findGroupPathInput = () => wrapper.findComponent(GlFormInput);
  const findGroupPathFormGroup = () => wrapper.findByTestId('secret-permissions-group-path');

  const inputRequiredFields = async (selectedItem = 'MAINTAINER', isGroup = false) => {
    // expiredAt is optional
    findCheckbox(0).vm.$emit('input', true);
    findCheckbox(1).vm.$emit('input', true);
    findCheckbox(2).vm.$emit('input', true);

    if (isGroup) {
      findGroupPathInput().vm.$emit('input', 'my-org/sub-group');
    } else {
      findPrincipalField().vm.$emit('select', selectedItem);
    }

    await nextTick();
  };

  const submitPermission = async ({
    includeOptionalFields = false,
    selectedItem = 'MAINTAINER',
    isGroup = false,
  } = {}) => {
    if (includeOptionalFields) {
      findDatepicker().vm.$emit('input', new Date('2055-08-12'));
    }

    await inputRequiredFields(selectedItem, isGroup);
    findModal().vm.$emit('primary', { preventDefault: jest.fn() });
    await waitForPromises();
  };

  const waitForDebounce = () => {
    jest.runOnlyPendingTimers();
    return waitForPromises();
  };

  beforeEach(() => {
    mockCreatePermission = jest.fn().mockResolvedValue(mockCreatePermissionResponse);
    mockMemberSearchQuery = jest.fn().mockResolvedValue(mockProjectMembersQueryResponse);
  });

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('hides modal when permission category is not provided', () => {
      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('modal behavior', () => {
    beforeEach(() => {
      createComponent({ permissionCategory: 'ROLE' });
    });

    it('disables all checkboxes except the first', () => {
      expect(findCheckbox(0).attributes('disabled')).toBeUndefined();
      expect(findCheckbox(1).attributes('disabled')).toBeDefined();
      expect(findCheckbox(2).attributes('disabled')).toBeDefined();
    });

    it('enables all checkboxes when the first checkbox is selected', async () => {
      findCheckbox(0).vm.$emit('input', true);
      await nextTick();

      expect(findCheckbox(1).attributes('disabled')).toBeUndefined();
      expect(findCheckbox(2).attributes('disabled')).toBeUndefined();
    });

    it.each`
      modalEvent     | emittedEvent
      ${'canceled'}  | ${'hide'}
      ${'hidden'}    | ${'hide'}
      ${'secondary'} | ${'hide'}
    `(
      'emits the $emittedEvent event when $modalEvent event is triggered',
      ({ modalEvent, emittedEvent }) => {
        expect(wrapper.emitted(emittedEvent)).toBeUndefined();

        findModal().vm.$emit(modalEvent);

        expect(wrapper.emitted(emittedEvent)).toHaveLength(1);
      },
    );
  });

  const USER_ITEMS = ['Administrator', 'John Doe'];
  const ROLE_ITEMS = ['Reporter', 'Developer', 'Maintainer'];

  describe.each([
    {
      contextName: 'project',
      contextConfig: contextConfigs[0],
    },
    {
      contextName: 'group',
      contextConfig: contextConfigs[1],
    },
  ])('$contextName context', ({ contextName, contextConfig }) => {
    describe.each`
      category  | title         | fieldItems    | selectedItem    | principalId
      ${'USER'} | ${'Add user'} | ${USER_ITEMS} | ${'john.doe'}   | ${2}
      ${'ROLE'} | ${'Add role'} | ${ROLE_ITEMS} | ${'MAINTAINER'} | ${40}
    `(
      '$category permissions form',
      ({ category, title, fieldItems, selectedItem, principalId }) => {
        beforeEach(async () => {
          mockCreatePermission = jest.fn().mockResolvedValue(contextConfig.mockSuccessResponse);
          mockMemberSearchQuery = jest
            .fn()
            .mockResolvedValue(contextConfig.mockMemberSearchQueryResponse);
          createComponent({ permissionCategory: category, context: contextName });
          if (category === 'USER') {
            findPrincipalField().vm.$emit('shown');
            await waitForPromises();
          }
        });

        it('renders modal', () => {
          expect(findModal().props('visible')).toBe(true);
        });

        it('renders template correctly', () => {
          expect(findModal().props('title')).toBe(title);
          expect(findDatepicker().exists()).toBe(true);
          expect(findCheckbox(0).text()).toContain('Read metadata');
          expect(findCheckbox(1).text()).toContain('Read value');
          expect(findCheckbox(2).text()).toContain('Write');
          expect(findCheckbox(3).text()).toContain('Delete');
        });

        it('sets expiration date in the future', () => {
          const today = new Date();
          const expirationMinDate = findDatepicker().props('minDate').getTime();
          expect(expirationMinDate).toBeGreaterThan(today.getTime());
        });

        it('fills listbox with correct items', () => {
          const actualFieldItems = findPrincipalField()
            .props('items')
            .map((item) => item.text);

          expect(actualFieldItems).toEqual(fieldItems);
        });

        it('calls the create mutation with the correct variables', async () => {
          await submitPermission({ includeOptionalFields: true, selectedItem });

          expect(mockCreatePermission).toHaveBeenCalledWith({
            fullPath: contextConfig.fullPath,
            principal: {
              id: principalId,
              type: category,
            },
            actions: ['READ', 'READ_VALUE', 'WRITE'],
            expiredAt: '2055-08-12',
          });
        });
      },
    );

    describe('GROUP permissions form', () => {
      beforeEach(() => {
        mockCreatePermission = jest.fn().mockResolvedValue(contextConfig.mockSuccessResponse);
        mockMemberSearchQuery = jest
          .fn()
          .mockResolvedValue(contextConfig.mockMemberSearchQueryResponse);
        createComponent({ permissionCategory: 'GROUP', context: contextName });
      });

      it('renders modal', () => {
        expect(findModal().props('visible')).toBe(true);
      });

      it('renders group path input instead of listbox', () => {
        expect(findGroupPathInput().exists()).toBe(true);
        expect(findPrincipalField().exists()).toBe(false);
      });

      it('renders template correctly', () => {
        expect(findModal().props('title')).toBe('Add group');
        expect(findDatepicker().exists()).toBe(true);
        expect(findCheckbox(0).text()).toContain('Read metadata');
        expect(findCheckbox(1).text()).toContain('Read value');
        expect(findCheckbox(2).text()).toContain('Write');
        expect(findCheckbox(3).text()).toContain('Delete');
      });

      it('calls the create mutation with the correct variables', async () => {
        await submitPermission({ includeOptionalFields: true, isGroup: true });

        expect(mockCreatePermission).toHaveBeenCalledWith({
          fullPath: contextConfig.fullPath,
          principal: {
            groupPath: 'my-org/sub-group',
            type: 'GROUP',
          },
          actions: ['READ', 'READ_VALUE', 'WRITE'],
          expiredAt: '2055-08-12',
        });
      });

      describe('group path validation', () => {
        const setGroupPath = async (path) => {
          const groupPathInput = findGroupPathInput();
          groupPathInput.vm.$emit('input', path);
          groupPathInput.vm.$emit('blur');
          await nextTick();
        };

        it('shows error state for invalid group path', async () => {
          expect(findGroupPathFormGroup().attributes('state')).toBe('true');

          await setGroupPath('invalid path with spaces');

          expect(findGroupPathFormGroup().attributes('state')).toBeUndefined();
        });

        it('does not show error for blank group path', async () => {
          expect(findGroupPathFormGroup().attributes('state')).toBe('true');

          await setGroupPath('');

          expect(findGroupPathFormGroup().attributes('state')).toBe('true');
        });

        it('does not show error for valid group path', async () => {
          expect(findGroupPathFormGroup().attributes('state')).toBe('true');

          await setGroupPath('my-group/sub-group');

          expect(findGroupPathFormGroup().attributes('state')).toBe('true');
        });

        it('disables submit button when group path is invalid', async () => {
          findCheckbox(0).vm.$emit('input', true);
          await nextTick();

          await setGroupPath('invalid path');

          expect(findModal().props('actionPrimary').attributes.disabled).toBe(true);
        });

        it('enables submit button when group path is valid', async () => {
          findCheckbox(0).vm.$emit('input', true);
          await nextTick();

          await setGroupPath('my-group/sub-group');

          expect(findModal().props('actionPrimary').attributes.disabled).toBe(false);
        });

        it('re-enables submit button when error is cleared', async () => {
          findCheckbox(0).vm.$emit('input', true);
          await nextTick();

          await setGroupPath('invalid path');
          expect(findModal().props('actionPrimary').attributes.disabled).toBe(true);

          await setGroupPath('my-group');
          await nextTick();

          expect(findModal().props('actionPrimary').attributes.disabled).toBe(false);
        });
      });
    });

    describe('when submission is successful', () => {
      beforeEach(() => {
        mockCreatePermission = jest.fn().mockResolvedValue(contextConfig.mockSuccessResponse);
        mockMemberSearchQuery = jest
          .fn()
          .mockResolvedValue(contextConfig.mockMemberSearchQueryResponse);
        createComponent({ permissionCategory: 'ROLE', context: contextName });
      });

      it('disables submission button by default', () => {
        expect(findModal().props('actionPrimary').attributes.disabled).toBe(true);
      });

      it('enables submission button when required fields are provided', async () => {
        await inputRequiredFields();

        expect(findModal().props('actionPrimary').attributes.disabled).toBe(false);
      });

      it('emits the refetch event', async () => {
        expect(wrapper.emitted('refetch')).toBeUndefined();

        await submitPermission();

        expect(wrapper.emitted('refetch')).toHaveLength(1);
      });

      it('hides modal and shows toast message on successful submission', async () => {
        expect(mockCreatePermission).toHaveBeenCalledTimes(0);

        await submitPermission();

        expect(mockCreatePermission).toHaveBeenCalledTimes(1);
        expect(wrapper.emitted('hide')).toHaveLength(1);
        expect(mockToastShow).toHaveBeenCalledWith(
          'Secrets manager permissions were successfully updated.',
        );
      });
    });

    describe('when submission returns errors', () => {
      beforeEach(() => {
        mockCreatePermission = jest
          .fn()
          .mockResolvedValue(contextConfig.mockErrorResponse('This permission is invalid.'));
        mockMemberSearchQuery = jest
          .fn()
          .mockResolvedValue(contextConfig.mockMemberSearchQueryResponse);
        createComponent({ permissionCategory: 'ROLE', context: contextName });
      });

      it('renders error message from API', async () => {
        await submitPermission();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'This permission is invalid.',
          containerSelector: ALERT_CONTAINER_SELECTOR,
        });
      });
    });

    describe('when submission fails', () => {
      const error = new Error('GraphQL error: API error');
      beforeEach(() => {
        mockCreatePermission = jest.fn().mockRejectedValue(error);
        mockMemberSearchQuery = jest
          .fn()
          .mockResolvedValue(contextConfig.mockMemberSearchQueryResponse);
        createComponent({ permissionCategory: 'ROLE', context: contextName });
      });

      it('renders error message with GraphQL prefix stripped', async () => {
        await submitPermission();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'API error',
          captureError: true,
          error,
          containerSelector: ALERT_CONTAINER_SELECTOR,
        });
      });
    });

    describe('debounced search', () => {
      beforeEach(() => {
        mockCreatePermission = jest.fn().mockResolvedValue(contextConfig.mockSuccessResponse);
        mockMemberSearchQuery = jest
          .fn()
          .mockResolvedValue(contextConfig.mockMemberSearchQueryResponse);
        createComponent({ permissionCategory: 'USER', context: contextName });
      });

      it('uses debounced search for user listbox with correct relations from context_config', async () => {
        findPrincipalField().vm.$emit('shown');
        await waitForPromises();

        expect(mockMemberSearchQuery).toHaveBeenCalledTimes(1);
        expect(mockMemberSearchQuery).toHaveBeenCalledWith({
          fullPath: contextConfig.fullPath,
          search: '',
          accessLevels: ['REPORTER', 'DEVELOPER', 'MAINTAINER'],
          relations: contextConfig.relations,
        });

        findPrincipalField().vm.$emit('search', 'Foo');
        await waitForDebounce();

        expect(mockMemberSearchQuery).toHaveBeenCalledTimes(2);
        expect(mockMemberSearchQuery).toHaveBeenCalledWith({
          fullPath: contextConfig.fullPath,
          search: 'Foo',
          accessLevels: ['REPORTER', 'DEVELOPER', 'MAINTAINER'],
          relations: contextConfig.relations,
        });
      });
    });
  });
});
