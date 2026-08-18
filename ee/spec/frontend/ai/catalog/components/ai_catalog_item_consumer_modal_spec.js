import { nextTick } from 'vue';
import { noop } from 'lodash-es';
import { GlForm, GlFormGroup, GlFormRadioGroup, GlModal, GlSprintf } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import AiCatalogItemConsumerModal from 'ee/ai/catalog/components/ai_catalog_item_consumer_modal.vue';
import FormProjectDropdown from 'ee/ai/catalog/components/form_project_dropdown.vue';
import AiCatalogItemConsumerDisclaimer from 'ee/ai/catalog/components/ai_catalog_item_consumer_disclaimer.vue';
import FlowTriggerEventsField from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/flow_trigger_events_field.vue';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from 'ee/ai/catalog/constants';
import { mockFlow, mockAgent, mockProjectWithGroup } from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

const mockProjectWithGroupExtended = {
  ...mockProjectWithGroup,
  name: 'Project 1',
  nameWithNamespace: 'Group-1 / Project 1',
  fullPath: 'group-1/project-1',
  rootGroup: {
    ...mockProjectWithGroup.rootGroup,
    fullPath: 'group-1',
  },
};

const triggerTypes = ['mention', 'assign', 'assign_reviewer'];

describe('AiCatalogItemConsumerModal', () => {
  let wrapper;

  const defaultProps = {
    item: mockFlow,
  };
  const GlFormGroupStub = stubComponent(GlFormGroup, {
    props: ['state', 'labelDescription'],
  });

  const createWrapper = ({ props = {}, provide = {}, glFeatures = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogItemConsumerModal, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        isProjectNamespace: false,
        projectId: null,
        glFeatures: {
          ...glFeatures,
        },
        ...provide,
      },
      stubs: {
        GlSprintf,
        GlFormGroup: GlFormGroupStub,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findForm = () => wrapper.findComponent(GlForm);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findFormRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findErrorAlert = () => wrapper.findByTestId('error-alert');
  const findPrivateAlert = () => wrapper.findByTestId('private-alert');
  const findRestrictedAlert = () => wrapper.findByTestId('restricted-alert');
  const findSingleProjectDropdown = () => wrapper.findComponentByTestId('project-dropdown');
  const findProjectDropdown = () => wrapper.findComponent(FormProjectDropdown);
  const findProjectMultiSelect = () => wrapper.findComponentByTestId('project-multi-select');
  const findProjectName = () => wrapper.findByTestId('project-name');
  const findTriggers = () => wrapper.findComponent(FlowTriggerEventsField);

  describe('component rendering', () => {
    describe('default', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('renders modal and item name', () => {
        expect(findModal().props('title')).toBe('Enable flow in your project');
        expect(findModal().find('dt').text()).toBe('Selected flow');
        expect(findModal().find('dd').text()).toBe(mockFlow.name);
      });

      it('does not render group/project radio group', () => {
        expect(findFormRadioGroup().exists()).toBe(false);
      });

      it('renders the label description of the project field', () => {
        expect(findFormGroup().props('labelDescription')).toBe(
          'Members of the selected project will be able to use the flow.',
        );
      });

      describe.each`
        itemType
        ${AI_CATALOG_TYPE_AGENT}
        ${AI_CATALOG_TYPE_FLOW}
        ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW}
      `('when the selected item type is $itemType', ({ itemType }) => {
        it('renders the disclaimer component with correct itemType and canEnable props', () => {
          const item = {
            ...mockFlow,
            itemType,
          };
          createWrapper({ props: { item, canEnable: true } });

          const disclaimerComponent = wrapper.findComponent(AiCatalogItemConsumerDisclaimer);
          expect(disclaimerComponent.exists()).toBe(true);
          expect(disclaimerComponent.props('itemType')).toBe(itemType);
          expect(disclaimerComponent.props('canEnable')).toBe(true);
        });
      });
    });

    describe('when the item is private', () => {
      beforeEach(() => {
        createWrapper({
          props: { item: { ...mockFlow, public: false, project: mockProjectWithGroupExtended } },
        });
      });

      it('renders private alert', () => {
        expect(findPrivateAlert().exists()).toBe(true);
      });

      it('renders project name instead of dropdown', () => {
        expect(findProjectName().text()).toBe(mockProjectWithGroupExtended.nameWithNamespace);
        expect(findProjectDropdown().exists()).toBe(false);
      });
    });

    describe('when item is private but has missing project ID', () => {
      beforeEach(() => {
        createWrapper({
          props: {
            item: {
              ...mockFlow,
              public: false,
              project: { id: undefined, nameWithNamespace: 'projectNamespace' },
            },
          },
        });
      });

      it('does not render error alert due to missing project', () => {
        expect(findErrorAlert().exists()).toBe(false);
      });

      it('does not submit when missing project id', () => {
        findForm().vm.$emit('submit', { preventDefault: noop });

        expect(wrapper.emitted('submit')).toBeUndefined();
      });
    });

    describe('when the item is public', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('renders project dropdown without a selected project', () => {
        expect(findProjectName().exists()).toBe(false);
        expect(findProjectDropdown().props('value')).toBe(null);
      });

      it('passes the item id to the project dropdown so already-enabled projects are filtered out', () => {
        expect(findProjectDropdown().props('itemId')).toBe(mockFlow.id);
      });

      it('does not render the error validation initially', () => {
        expect(findFormGroup().props('state')).toBe(true);
      });

      it('renders alert when there was a problem fetching the projects', async () => {
        const error = 'Failed to load projects.';

        await findProjectDropdown().vm.$emit('error', error);

        expect(findErrorAlert().text()).toBe(error);
      });

      it('does not render private alert', () => {
        expect(findPrivateAlert().exists()).toBe(false);
      });
    });

    describe('when the item is restricted', () => {
      const restrictedFlow = {
        ...mockFlow,
        public: false,
        visibility: 'RESTRICTED',
        project: mockProjectWithGroupExtended,
      };

      describe('when aiCatalogInternalVisibility is enabled', () => {
        beforeEach(() => {
          createWrapper({
            props: { item: restrictedFlow },
            glFeatures: { aiCatalogInternalVisibility: true },
          });
        });

        it('renders the restricted alert with the group name', () => {
          expect(findRestrictedAlert().exists()).toBe(true);
          expect(findRestrictedAlert().text()).toContain(
            'This flow can only be enabled in projects within the top-level group Group 1.',
          );
        });

        it('renders the project dropdown instead of the static project name', () => {
          expect(findProjectDropdown().exists()).toBe(true);
          expect(findProjectName().exists()).toBe(false);
        });

        it('does not render the private alert', () => {
          expect(findPrivateAlert().exists()).toBe(false);
        });
      });

      describe('when aiCatalogInternalVisibility is disabled', () => {
        beforeEach(() => {
          createWrapper({
            props: { item: restrictedFlow },
          });
        });

        it('falls back to the private modal behaviour', () => {
          expect(findPrivateAlert().exists()).toBe(true);
          expect(findProjectName().exists()).toBe(true);
          expect(findRestrictedAlert().exists()).toBe(false);
        });
      });

      describe('when within project namespace', () => {
        beforeEach(() => {
          createWrapper({
            props: { item: restrictedFlow },
            provide: { isProjectNamespace: true, projectId: '1' },
            glFeatures: { aiCatalogInternalVisibility: true },
          });
        });

        it('does not render the restricted alert', () => {
          expect(findRestrictedAlert().exists()).toBe(false);
        });
      });
    });

    describe('when within project namespace', () => {
      describe('when the item is public', () => {
        beforeEach(() => {
          createWrapper({
            provide: { isProjectNamespace: true, projectId: '1' },
          });
        });

        it('hides the project section and does not render the private alert', () => {
          expect(findProjectDropdown().exists()).toBe(false);
          expect(findProjectName().exists()).toBe(false);
          expect(findPrivateAlert().exists()).toBe(false);
        });
      });

      describe('when the item is private', () => {
        beforeEach(() => {
          createWrapper({
            props: { item: { ...mockFlow, public: false, project: mockProjectWithGroupExtended } },
            provide: { isProjectNamespace: true, projectId: '1' },
          });
        });

        it('hides the project section and does not render the private alert', () => {
          expect(findProjectDropdown().exists()).toBe(false);
          expect(findProjectName().exists()).toBe(false);
          expect(findPrivateAlert().exists()).toBe(false);
        });
      });
    });
  });

  describe('when submitting the form', () => {
    it('emits the submit event', async () => {
      createWrapper();

      const projectId = 'gid://gitlab/Project/1000000';
      await findProjectDropdown().vm.$emit('input', projectId);
      findForm().vm.$emit('submit', { preventDefault: noop });

      expect(wrapper.emitted('submit')[0][0]).toStrictEqual({
        target: { projectId },
        triggerTypes,
      });
    });

    it('when in the project namespace, submits with the current project id', () => {
      createWrapper({
        provide: { isProjectNamespace: true, projectId: '1' },
      });

      findForm().vm.$emit('submit', { preventDefault: noop });

      expect(wrapper.emitted('submit')[0][0].target.projectId).toBe('gid://gitlab/Project/1');
    });

    describe('when there is no project selected', () => {
      beforeEach(() => {
        createWrapper({
          props: {
            item: { ...mockFlow, project: null },
          },
        });
      });

      it('renders alert', async () => {
        findForm().vm.$emit('submit', { preventDefault: noop });
        await nextTick();

        expect(wrapper.emitted('submit')).toBeUndefined();
        expect(findFormGroup().props('state')).toBe(false);
      });
    });
  });

  describe('when the modal emits the hidden event', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits the hide event', () => {
      findModal().vm.$emit('hidden');

      expect(wrapper.emitted('hide')).toHaveLength(1);
    });

    it('resets form state', async () => {
      const projectId = 'gid://gitlab/Project/1000000';
      await findProjectDropdown().vm.$emit('input', projectId);
      await findProjectDropdown().vm.$emit('error', 'Some error');

      findModal().vm.$emit('hidden');
      await nextTick();

      expect(wrapper.vm.projectId).toBe(null);
      expect(wrapper.vm.error).toBe(null);
      expect(wrapper.vm.isDirty).toBe(false);
    });
  });

  describe('when user does not have permission to enable a private item', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          item: { ...mockFlow, project: mockProjectWithGroupExtended, public: false },
          canEnable: false,
        },
      });
    });

    it('renders project name instead of dropdown', () => {
      expect(findProjectName().text()).toBe(mockProjectWithGroupExtended.nameWithNamespace);
      expect(findProjectDropdown().exists()).toBe(false);
    });
  });

  describe('when user has permission to enable a private item', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          item: { ...mockFlow, project: mockProjectWithGroupExtended, public: false },
          canEnable: true,
        },
      });
    });

    it('renders project name instead of dropdown', () => {
      expect(findProjectName().text()).toBe(mockProjectWithGroupExtended.nameWithNamespace);
      expect(findProjectDropdown().exists()).toBe(false);
    });
  });

  describe('when user has permission to enable a public item', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          item: { ...mockFlow, project: mockProjectWithGroupExtended },
          canEnable: true,
        },
      });
    });

    it('renders project dropdown without a selected project', () => {
      expect(findProjectName().exists()).toBe(false);
      expect(findSingleProjectDropdown().props('value')).toBe(null);
    });

    it('renders trigger selection for flows', () => {
      expect(findTriggers().exists()).toBe(true);
    });

    it('pre-selects only the default trigger types', () => {
      expect(findTriggers().props('eventTypes')).toStrictEqual([
        'mention',
        'assign',
        'assign_reviewer',
      ]);
      expect(findTriggers().props('eventTypes')).not.toContain('merge_request_ready');
      expect(findTriggers().props('eventTypes')).not.toContain('pipeline_hooks');
    });

    it('emits submit event with triggerTypes for flows and omits empty triggerFilter', async () => {
      const projectId = 'gid://gitlab/Project/1';

      await findSingleProjectDropdown().vm.$emit('input', projectId);
      findForm().vm.$emit('submit', { preventDefault: noop });

      expect(wrapper.emitted('submit')[0][0]).toStrictEqual({
        target: { projectId },
        triggerTypes,
      });
    });

    it('forwards the triggerFilter emitted by the field on submit', async () => {
      const projectId = 'gid://gitlab/Project/1';
      const triggerFilter = {
        pipeline_hooks: {
          rules: [{ field: 'object_attributes.status', operator: 'in', value: ['failed'] }],
        },
      };

      await findSingleProjectDropdown().vm.$emit('input', projectId);
      await findTriggers().vm.$emit('update:filter', triggerFilter);
      findForm().vm.$emit('submit', { preventDefault: noop });

      expect(wrapper.emitted('submit')[0][0].triggerFilter).toEqual(triggerFilter);
    });

    it('splits folded merge_request actions back into their own event types on submit', async () => {
      const projectId = 'gid://gitlab/Project/1';

      await findSingleProjectDropdown().vm.$emit('input', projectId);
      await findTriggers().vm.$emit('update:event-types', [...triggerTypes, 'merge_request']);
      await findTriggers().vm.$emit('update:filter', {
        merge_request: {
          rules: [
            { field: 'action', operator: 'in', value: ['ready', 'approved', 'code_conflict'] },
          ],
        },
      });
      findForm().vm.$emit('submit', { preventDefault: noop });

      const emitted = wrapper.emitted('submit')[0][0];
      expect(emitted.triggerTypes).toStrictEqual([
        ...triggerTypes,
        'merge_request',
        'merge_request_code_conflict',
        'merge_request_ready',
      ]);
      expect(emitted.triggerFilter).toEqual({
        merge_request: {
          rules: [{ field: 'action', operator: 'in', value: ['approved'] }],
        },
      });
    });

    it('drops merge_request when only foldable actions are selected', async () => {
      const projectId = 'gid://gitlab/Project/1';

      await findSingleProjectDropdown().vm.$emit('input', projectId);
      await findTriggers().vm.$emit('update:event-types', [...triggerTypes, 'merge_request']);
      await findTriggers().vm.$emit('update:filter', {
        merge_request: {
          rules: [{ field: 'action', operator: 'in', value: ['ready', 'code_conflict'] }],
        },
      });
      findForm().vm.$emit('submit', { preventDefault: noop });

      const emitted = wrapper.emitted('submit')[0][0];
      expect(emitted.triggerTypes).toStrictEqual([
        ...triggerTypes,
        'merge_request_code_conflict',
        'merge_request_ready',
      ]);
      expect(emitted.triggerTypes).not.toContain('merge_request');
      expect(emitted.triggerFilter).toBeUndefined();
    });

    it('does not submit when all triggers are deselected', async () => {
      const projectId = 'gid://gitlab/Project/1';

      await findSingleProjectDropdown().vm.$emit('input', projectId);
      await findTriggers().vm.$emit('update:event-types', []);
      findForm().vm.$emit('submit', { preventDefault: noop });
      await nextTick();

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('does not submit when the field reports the configuration is invalid', async () => {
      const projectId = 'gid://gitlab/Project/1';

      await findSingleProjectDropdown().vm.$emit('input', projectId);
      await findTriggers().vm.$emit('update:filter-valid', false);
      findForm().vm.$emit('submit', { preventDefault: noop });
      await nextTick();

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('passes show-errors to the field once the user attempts to submit invalid configuration', async () => {
      const projectId = 'gid://gitlab/Project/1';

      await findSingleProjectDropdown().vm.$emit('input', projectId);
      await findTriggers().vm.$emit('update:filter-valid', false);
      expect(findTriggers().props('showErrors')).toBe(false);

      findForm().vm.$emit('submit', { preventDefault: noop });
      await nextTick();

      expect(findTriggers().props('showErrors')).toBe(true);
    });
  });

  describe('when user has permission to enable a public agent', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          item: { ...mockAgent, project: mockProjectWithGroupExtended },
          canEnable: true,
        },
      });
    });

    it('does not render trigger selection for agents', () => {
      expect(findTriggers().exists()).toBe(false);
    });
  });

  describe('when user does not have permission to enable a public flow', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          item: { ...mockFlow, project: mockProjectWithGroupExtended },
          canEnable: false,
        },
      });
    });

    it('does not render trigger selection', () => {
      expect(findTriggers().exists()).toBe(false);
    });
  });

  describe('when item is private but project is null (race condition)', () => {
    const privateItemWithoutProject = {
      ...mockFlow,
      public: false,
      project: null,
    };
    const privateItemWithProject = {
      ...mockFlow,
      public: false,
      project: mockProjectWithGroupExtended,
    };

    beforeEach(() => {
      createWrapper({
        props: {
          item: privateItemWithoutProject,
        },
      });
    });

    it('does not crash when rendering', () => {
      expect(findModal().exists()).toBe(true);
    });

    it('does not render project name section', () => {
      expect(findProjectName().exists()).toBe(false);
    });

    it('does not render error alert', () => {
      expect(findErrorAlert().exists()).toBe(false);
    });

    it('does not render private alert during race window', () => {
      expect(findPrivateAlert().exists()).toBe(false);
    });

    describe('when project data arrives after mount (prop update)', () => {
      beforeEach(async () => {
        await wrapper.setProps({ item: privateItemWithProject });
      });

      it('renders the static project name once project data is available', () => {
        expect(findProjectName().text()).toBe(mockProjectWithGroupExtended.nameWithNamespace);
        expect(findProjectDropdown().exists()).toBe(false);
      });

      it('renders private alert once project data is available', () => {
        expect(findPrivateAlert().exists()).toBe(true);
      });

      it('submits with the resolved project id from the updated item', async () => {
        findForm().vm.$emit('submit', { preventDefault: noop });
        await nextTick();

        expect(wrapper.emitted('submit')).toHaveLength(1);
        expect(wrapper.emitted('submit')[0][0]).toStrictEqual({
          target: { projectId: mockProjectWithGroupExtended.id },
          triggerTypes,
        });
      });

      it('reports the race condition to Sentry so occurrences can be tracked', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException).toHaveBeenCalledWith(
          expect.objectContaining({
            message: expect.stringContaining('project data arrived after mount'),
          }),
          expect.objectContaining({
            level: 'info',
            tags: expect.objectContaining({
              race_type: 'ai_catalog_project_field',
              item_type: privateItemWithProject.itemType,
            }),
            extra: expect.objectContaining({
              item_id: privateItemWithProject.id,
              time_to_resolve_ms: expect.any(Number),
            }),
          }),
        );

        const [, context] = Sentry.captureException.mock.calls[0];
        expect(context.extra.time_to_resolve_ms).toBeGreaterThanOrEqual(0);
      });
    });
  });

  describe('when aiCatalogBulkItemConsumerCreate feature flag is on', () => {
    describe('when the item is private', () => {
      beforeEach(() => {
        createWrapper({
          props: {
            item: {
              ...mockFlow,
              public: false,
              project: mockProjectWithGroupExtended,
            },
          },
          glFeatures: { aiCatalogBulkItemConsumerCreate: true },
        });
      });

      it('renders project name instead of token selector', () => {
        expect(findProjectName().text()).toBe(mockProjectWithGroupExtended.nameWithNamespace);
        expect(findProjectMultiSelect().exists()).toBe(false);
      });
    });

    describe('when the item is restricted', () => {
      beforeEach(() => {
        createWrapper({
          props: {
            item: {
              ...mockFlow,
              public: false,
              visibility: 'RESTRICTED',
              project: mockProjectWithGroupExtended,
            },
          },
          glFeatures: {
            aiCatalogBulkItemConsumerCreate: true,
            aiCatalogInternalVisibility: true,
          },
        });
      });

      it('renders project multi select', () => {
        expect(findProjectName().exists()).toBe(false);
        expect(findProjectMultiSelect().exists()).toBe(true);
      });
    });

    describe('when the item is public', () => {
      beforeEach(() => {
        createWrapper({ glFeatures: { aiCatalogBulkItemConsumerCreate: true } });
      });

      it('renders project multi select', () => {
        expect(findProjectName().exists()).toBe(false);
        expect(findProjectMultiSelect().exists()).toBe(true);
      });

      it('passes the item id to the project multi select so already-enabled projects are filtered out', () => {
        expect(findProjectMultiSelect().props('itemId')).toBe(mockFlow.id);
      });

      it('does not render the error validation initially', () => {
        expect(findProjectMultiSelect().props('isValid')).toBe(true);
      });

      it('renders alert when there was a problem fetching the projects', async () => {
        const error = 'Failed to load projects.';

        await findProjectMultiSelect().vm.$emit('error', error);

        expect(findErrorAlert().text()).toBe(error);
      });
    });

    describe('when submitting the form', () => {
      it('emits the submit event', async () => {
        createWrapper({ glFeatures: { aiCatalogBulkItemConsumerCreate: true } });

        const projectIds = ['gid://gitlab/Project/1', 'gid://gitlab/Project/2'];

        await findProjectMultiSelect().vm.$emit('input', projectIds);
        findForm().vm.$emit('submit', { preventDefault: noop });

        expect(wrapper.emitted('submit')[0][0]).toStrictEqual({
          target: projectIds,
          triggerTypes,
        });
      });

      describe('when there is no project selected', () => {
        beforeEach(() => {
          createWrapper({
            props: {
              item: { ...mockFlow, project: null },
            },
            glFeatures: { aiCatalogBulkItemConsumerCreate: true },
          });
        });

        it('renders alert', async () => {
          findForm().vm.$emit('submit', { preventDefault: noop });
          await nextTick();

          expect(wrapper.emitted('submit')).toBeUndefined();
          expect(findProjectMultiSelect().props('isValid')).toBe(false);
        });
      });
    });

    describe('when user has permission to enable a public item', () => {
      beforeEach(() => {
        createWrapper({
          props: {
            item: { ...mockFlow, project: mockProjectWithGroupExtended },
            canEnable: true,
          },
          glFeatures: { aiCatalogBulkItemConsumerCreate: true },
        });
      });

      it('renders project multi select', () => {
        expect(findProjectName().exists()).toBe(false);
        expect(findProjectMultiSelect().exists()).toBe(true);
      });

      it('renders trigger selection for flows', () => {
        expect(findTriggers().exists()).toBe(true);
      });

      it('pre-selects only the default trigger types', () => {
        expect(findTriggers().props('eventTypes')).toStrictEqual([
          'mention',
          'assign',
          'assign_reviewer',
        ]);
        expect(findTriggers().props('eventTypes')).not.toContain('merge_request_ready');
        expect(findTriggers().props('eventTypes')).not.toContain('pipeline_hooks');
      });

      it('emits submit event with triggerTypes for flows and omits empty triggerFilter', async () => {
        const projectIds = ['gid://gitlab/Project/1', 'gid://gitlab/Project/2'];

        await findProjectMultiSelect().vm.$emit('input', projectIds);
        findForm().vm.$emit('submit', { preventDefault: noop });

        expect(wrapper.emitted('submit')[0][0]).toStrictEqual({
          target: projectIds,
          triggerTypes,
        });
      });

      it('passes show-errors to the field once the user attempts to submit invalid configuration', async () => {
        const projectIds = ['gid://gitlab/Project/1', 'gid://gitlab/Project/2'];

        await findProjectMultiSelect().vm.$emit('input', projectIds);
        await findTriggers().vm.$emit('update:filter-valid', false);
        expect(findTriggers().props('showErrors')).toBe(false);

        findForm().vm.$emit('submit', { preventDefault: noop });
        await nextTick();

        expect(findTriggers().props('showErrors')).toBe(true);
      });
    });
  });
});
