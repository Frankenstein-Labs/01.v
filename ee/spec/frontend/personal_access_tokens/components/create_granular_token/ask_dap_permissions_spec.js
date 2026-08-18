import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AskDapPermissions from 'ee/personal_access_tokens/components/create_granular_token/ask_dap_permissions.vue';
import OpenAgenticChatButton from 'ee/ai/shared/widgets/open_agentic_chat_button.vue';
import { getExternalContextItems } from 'ee/ai/duo_agentic_chat/context/external_context_store';
import getAccessTokenPermissions from '~/personal_access_tokens/graphql/get_access_token_permissions.query.graphql';

Vue.use(VueApollo);

const mockPermissions = [
  {
    name: 'read_project',
    description: 'Grants the ability to read projects',
    action: 'read',
    category: 'groups_and_projects',
    categoryName: 'Groups and projects',
    resource: 'project',
    resourceName: 'Project',
    resourceDescription: 'Project resource description',
    boundaries: ['GROUP', 'PROJECT'],
  },
  {
    name: 'write_project',
    description: 'Grants the ability to write to projects',
    action: 'write',
    category: 'groups_and_projects',
    categoryName: 'Groups and projects',
    resource: 'project',
    resourceName: 'Project',
    resourceDescription: 'Project resource description',
    boundaries: ['GROUP', 'PROJECT'],
  },
  {
    name: 'read_contributed_project',
    description: 'Grants the ability to read contributed projects',
    action: 'read',
    category: 'user',
    categoryName: 'User',
    resource: 'user',
    resourceName: 'User',
    resourceDescription: 'User resource description',
    boundaries: ['PROJECT', 'USER'],
  },
];

const mockPermissionsResponse = { data: { accessTokenPermissions: mockPermissions } };

describe('AskDapPermissions', () => {
  let wrapper;
  let mockApollo;

  const mockQueryHandler = jest.fn().mockResolvedValue(mockPermissionsResponse);

  const createComponent = ({
    queryHandler = mockQueryHandler,
    agenticAvailable = true,
    props = {},
  } = {}) => {
    mockApollo = createMockApollo([[getAccessTokenPermissions, queryHandler]]);

    wrapper = shallowMountExtended(AskDapPermissions, {
      apolloProvider: mockApollo,
      propsData: props,
      provide: { agenticAvailable },
    });
  };

  beforeEach(() => {
    window.gon = { current_user_id: 42 };
    createComponent();
  });

  // Destroy after every test so the component's registered external-context
  // provider is disposed and does not leak into the module-level store.
  afterEach(() => {
    wrapper?.destroy();
  });

  const findOpenWithAgent = () => wrapper.findComponent(OpenAgenticChatButton);

  describe('rendering', () => {
    it('renders the OpenAgenticChatButton component with correct props', () => {
      expect(findOpenWithAgent().exists()).toBe(true);
      expect(findOpenWithAgent().props('buttonText')).toBe('Add permissions with Duo');
      expect(findOpenWithAgent().props('resourceId')).toBe('gid://gitlab/User/42');
      expect(findOpenWithAgent().props('agent')).toEqual({ name: 'Permissions Assistant' });
      expect(findOpenWithAgent().props('welcomeMessage')).toContain(
        'fine-grained permissions assistant',
      );
      expect(findOpenWithAgent().props('predefinedPrompts')).toEqual(
        expect.arrayContaining([expect.any(String)]),
      );
    });

    it('does not render when agenticAvailable is false', () => {
      createComponent({ agenticAvailable: false });

      expect(findOpenWithAgent().exists()).toBe(false);
    });
  });

  describe('Apollo query', () => {
    it('fetches permissions on mount', async () => {
      await waitForPromises();

      expect(mockQueryHandler).toHaveBeenCalled();
    });

    it('disables the button while permissions are loading', () => {
      expect(findOpenWithAgent().props('buttonOptions')).toMatchObject({ disabled: true });
    });

    it('enables the button after permissions are loaded', async () => {
      await waitForPromises();

      expect(findOpenWithAgent().props('buttonOptions')).toMatchObject({ disabled: false });
    });

    describe('when the query fails', () => {
      beforeEach(() => {
        createComponent({ queryHandler: jest.fn().mockRejectedValue(new Error('network error')) });
      });

      it('disables the button', async () => {
        await waitForPromises();

        expect(findOpenWithAgent().props('buttonOptions')).toMatchObject({ disabled: true });
      });

      it('sets a title on the button options', async () => {
        await waitForPromises();

        expect(findOpenWithAgent().props('buttonOptions')).toMatchObject({
          title: 'Unable to load permissions',
        });
      });
    });
  });

  describe('handleToolCompleted()', () => {
    const callHandler = (name, args) => {
      findOpenWithAgent().vm.$emit('tool-completed', { name, args });
    };

    beforeEach(() => {
      wrapper.vm.permissions = mockPermissions;
    });

    it('emits the validated select scopes as permissions-selected', () => {
      callHandler('set_form_permissions', { select: { namespace: ['read_project'] } });

      expect(wrapper.emitted('permissions-selected')[0]).toEqual([
        { namespace: ['read_project'], user: [], instance: [] },
      ]);
    });

    it('emits the validated clear scopes as permissions-cleared', () => {
      callHandler('set_form_permissions', { clear: { namespace: ['read_project'] } });

      expect(wrapper.emitted('permissions-cleared')[0]).toEqual([
        { namespace: ['read_project'], user: [], instance: [] },
      ]);
    });

    it('handles both select and clear in the same event', () => {
      callHandler('set_form_permissions', {
        select: { namespace: ['write_project'] },
        clear: { namespace: ['read_project'] },
      });

      expect(wrapper.emitted('permissions-selected')[0]).toEqual([
        { namespace: ['write_project'], user: [], instance: [] },
      ]);
      expect(wrapper.emitted('permissions-cleared')[0]).toEqual([
        { namespace: ['read_project'], user: [], instance: [] },
      ]);
    });

    it('filters out invalid permission names', () => {
      callHandler('set_form_permissions', {
        select: { namespace: ['read_project', 'not_a_valid_permission'] },
      });

      expect(wrapper.emitted('permissions-selected')[0]).toEqual([
        { namespace: ['read_project'], user: [], instance: [] },
      ]);
    });

    it('does not emit when no valid permissions exist', () => {
      callHandler('set_form_permissions', { select: { namespace: ['not_a_valid_permission'] } });

      expect(wrapper.emitted('permissions-selected')).toBeUndefined();
    });

    describe('boundary validation', () => {
      it('keeps a permission placed in a single valid boundary', () => {
        callHandler('set_form_permissions', {
          select: { user: ['read_contributed_project'] },
        });

        expect(wrapper.emitted('permissions-selected')[0]).toEqual([
          { namespace: [], user: ['read_contributed_project'], instance: [] },
        ]);
      });

      it('keeps a permission placed in multiple valid boundaries', () => {
        callHandler('set_form_permissions', {
          select: {
            user: ['read_contributed_project'],
            namespace: ['read_contributed_project'],
          },
        });

        expect(wrapper.emitted('permissions-selected')[0]).toEqual([
          {
            namespace: ['read_contributed_project'],
            user: ['read_contributed_project'],
            instance: [],
          },
        ]);
      });

      it('drops a permission placed in a boundary it does not belong to', () => {
        callHandler('set_form_permissions', {
          select: {
            user: ['read_contributed_project'],
            global: ['read_contributed_project'],
          },
        });

        expect(wrapper.emitted('permissions-selected')[0]).toEqual([
          { namespace: [], user: ['read_contributed_project'], instance: [] },
        ]);
      });

      it('does not emit when the only placement is in an invalid boundary', () => {
        callHandler('set_form_permissions', {
          select: { global: ['read_project'] },
        });

        expect(wrapper.emitted('permissions-selected')).toBeUndefined();
      });
    });

    it('ignores events for a different tool', () => {
      callHandler('some_other_tool', { select: { namespace: ['read_project'] } });

      expect(wrapper.emitted('permissions-selected')).toBeUndefined();
      expect(wrapper.emitted('permissions-cleared')).toBeUndefined();
    });

    it('ignores events with no args', () => {
      callHandler('set_form_permissions');

      expect(wrapper.emitted('permissions-selected')).toBeUndefined();
      expect(wrapper.emitted('permissions-cleared')).toBeUndefined();
    });

    describe('replayed tool results', () => {
      const emitWithId = (messageId, args) => {
        findOpenWithAgent().vm.$emit('tool-completed', {
          name: 'set_form_permissions',
          args,
          messageId,
        });
      };

      it('applies a given tool result only once, ignoring replays of the same message', () => {
        emitWithId('msg-1', { select: { namespace: ['read_project'] } });
        emitWithId('msg-1', { select: { namespace: ['read_project'] } });

        expect(wrapper.emitted('permissions-selected')).toHaveLength(1);
      });

      it('still applies a distinct tool result with a new message id', () => {
        emitWithId('msg-1', { select: { namespace: ['read_project'] } });
        emitWithId('msg-2', { select: { namespace: ['write_project'] } });

        expect(wrapper.emitted('permissions-selected')).toHaveLength(2);
      });
    });
  });

  describe('form context injection', () => {
    beforeEach(() => {
      wrapper.destroy();
    });

    it('registers a provider exposing the current form state to the chat', () => {
      createComponent({
        props: {
          formPermissions: { namespace: ['read_project'], user: [], instance: [] },
        },
      });

      const [item] = getExternalContextItems();

      expect(item.category).toBe('permissions_form_context');
      expect(JSON.parse(item.content)).toEqual({
        namespace: ['read_project'],
        user: [],
        global: [],
      });
    });

    it('reads the latest form state each time it is read (not frozen)', async () => {
      createComponent({
        props: {
          formPermissions: { namespace: ['read_project'], user: [], instance: [] },
        },
      });

      await wrapper.setProps({
        formPermissions: { namespace: ['read_project', 'write_project'], user: [], instance: [] },
      });

      const [item] = getExternalContextItems();

      expect(JSON.parse(item.content)).toEqual({
        namespace: ['read_project', 'write_project'],
        user: [],
        global: [],
      });
    });

    it('unregisters the provider when destroyed', () => {
      createComponent();
      wrapper.destroy();

      expect(getExternalContextItems()).toEqual([]);
    });
  });
});
