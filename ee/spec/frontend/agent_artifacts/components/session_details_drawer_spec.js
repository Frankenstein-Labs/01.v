import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAttributeList, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SessionDetailsDrawer from 'ee/agent_artifacts/components/session_details_drawer.vue';
import SessionDetailsBody from 'ee/agent_artifacts/components/session_details_body.vue';
import SessionAuditEventsList from 'ee/agent_artifacts/components/session_audit_events_list.vue';
import AuditEventDetailsPanel from 'ee/agent_artifacts/components/audit_event_details_panel.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import DynamicPanel from '~/vue_shared/components/dynamic_panel.vue';
import { formatAgentDefinition } from 'ee/ai/duo_agents_platform/utils';
import getProjectSessionAuditEventsQuery from 'ee/agent_artifacts/graphql/queries/get_project_session_audit_events.query.graphql';

Vue.use(VueApollo);

jest.mock('ee/ai/duo_agents_platform/utils', () => ({
  formatAgentDefinition: jest.fn((name) => name),
}));

describe('SessionDetailsDrawer', () => {
  let wrapper;

  const mockActiveItem = {
    id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1908',
    workflowDefinition: 'false_positive_detection/v1',
    workflowCreatedAt: '2024-01-01T12:00:00Z',
    webPath: '/gitlab-org/security-scanner/-/automate/agent-sessions/1908',
    downloadPath: '/gitlab-org/security-scanner/-/security/agent_artifacts/1908/download',
    project: {
      name: 'security-scanner',
      webPath: '/gitlab-org/security-scanner',
    },
  };

  const PROJECT_FULL_PATH = 'gitlab-org/security-scanner';

  const buildEvent = (id) => ({
    id,
    eventName: 'tool_execution',
    createdAt: '2026-05-04T10:30:00Z',
    details: {},
    ipAddress: '127.0.0.1',
    workflowId: '1908',
    author: null,
    __typename: 'AiAuditEvent',
  });

  const pageOneEvents = [buildEvent('event-1'), buildEvent('event-2')];
  const pageTwoEvents = [buildEvent('event-3'), buildEvent('event-4')];

  const buildResponse = ({ nodes, hasNextPage, hasPreviousPage }) => ({
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        duoWorkflowSessionArtifacts: {
          nodes: [
            {
              id: mockActiveItem.id,
              auditEvents: {
                nodes,
                pageInfo: {
                  hasNextPage,
                  hasPreviousPage,
                  startCursor: nodes[0]?.id ?? null,
                  endCursor: nodes[nodes.length - 1]?.id ?? null,
                  __typename: 'PageInfo',
                },
                __typename: 'AiAuditEventConnection',
              },
              __typename: 'DuoWorkflowSessionArtifact',
            },
          ],
          __typename: 'DuoWorkflowSessionArtifactConnection',
        },
        __typename: 'Project',
      },
    },
  });

  const pageOneResponse = buildResponse({
    nodes: pageOneEvents,
    hasNextPage: true,
    hasPreviousPage: false,
  });

  const pageTwoResponse = buildResponse({
    nodes: pageTwoEvents,
    hasNextPage: false,
    hasPreviousPage: true,
  });

  const notFoundResponse = {
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        duoWorkflowSessionArtifacts: {
          nodes: [],
          __typename: 'DuoWorkflowSessionArtifactConnection',
        },
        __typename: 'Project',
      },
    },
  };

  const createComponent = ({
    props = {},
    handler = jest.fn().mockResolvedValue(pageOneResponse),
    mount = shallowMountExtended,
    provide = {},
  } = {}) => {
    const apolloProvider = createMockApollo([[getProjectSessionAuditEventsQuery, handler]]);

    wrapper = mount(SessionDetailsDrawer, {
      apolloProvider,
      provide: {
        projectFullPath: PROJECT_FULL_PATH,
        groupFullPath: null,
        ...provide,
      },
      propsData: {
        activeItem: mockActiveItem,
        ...props,
      },
      stubs: {
        MountingPortal: { template: '<div><slot /></div>' },
        DynamicPanel: {
          template: '<div><slot name="header" /><slot /></div>',
          emits: ['close'],
        },
        SessionDetailsBody,
        SessionAuditEventsList,
        CrudComponent,
        GlAttributeList,
        GlButton,
      },
    });

    return handler;
  };

  const findDrawer = () => wrapper.findByTestId('session-details-drawer');
  const findDynamicPanel = () => wrapper.findComponent(DynamicPanel);
  const findDrawerContentTitle = () => wrapper.findByTestId('session-content-title');
  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findViewFullSessionButton = () => wrapper.findByTestId('view-full-session-details-button');
  const findSessionLink = () => wrapper.findByTestId('session-link');
  const findFormattedDate = () => wrapper.findByTestId('formatted-date');
  const findProjectLink = () => wrapper.findByTestId('project-link');
  const findSessionDetailsBody = () => wrapper.findComponent(SessionDetailsBody);
  const findAuditEventPanel = () => wrapper.findComponent(AuditEventDetailsPanel);
  const findBackButton = () => wrapper.findComponentByTestId('audit-event-back-button');
  const findPrevButton = () => wrapper.findComponentByTestId('audit-event-prev-button');
  const findNextButton = () => wrapper.findComponentByTestId('audit-event-next-button');

  describe('basic rendering (shallow, no query)', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the drawer', () => {
      expect(findDrawer().exists()).toBe(true);
    });

    it('displays formatted agent name in content', () => {
      expect(findDrawerContentTitle().text()).toBe(
        formatAgentDefinition(mockActiveItem.workflowDefinition),
      );
    });

    it('does not render the event navigation controls while viewing the session', () => {
      expect(findBackButton().exists()).toBe(false);
      expect(findPrevButton().exists()).toBe(false);
      expect(findNextButton().exists()).toBe(false);
    });

    it('emits close event when DynamicPanel emits close', async () => {
      await findDynamicPanel().vm.$emit('close');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    describe('keyboard navigation', () => {
      it('emits close event when Escape key is pressed', () => {
        const event = new KeyboardEvent('keydown', { key: 'Escape' });
        document.dispatchEvent(event);

        expect(wrapper.emitted('close')).toHaveLength(1);
      });

      it('does not emit close event when other keys are pressed', () => {
        const event = new KeyboardEvent('keydown', { key: 'Enter' });
        document.dispatchEvent(event);

        expect(wrapper.emitted('close')).toBeUndefined();
      });
    });

    describe('event listener cleanup', () => {
      it('removes keydown event listener on destroy', () => {
        const removeEventListenerSpy = jest.spyOn(document, 'removeEventListener');

        wrapper.destroy();

        expect(removeEventListenerSpy).toHaveBeenCalledWith('keydown', wrapper.vm.closeOnEscape);
      });
    });

    describe('session details body', () => {
      it('renders the SessionDetailsBody and passes through the session id', () => {
        expect(findSessionDetailsBody().exists()).toBe(true);
        expect(findSessionDetailsBody().props('sessionId')).toBe(mockActiveItem.id);
      });

      it('passes a null session id through when the active item has none', () => {
        createComponent({ props: { activeItem: { ...mockActiveItem, id: null } } });

        expect(findSessionDetailsBody().props('sessionId')).toBe(null);
      });

      it('forwards the body select event as its own select', () => {
        findSessionDetailsBody().vm.$emit('select', { id: 'event-1' });

        expect(wrapper.emitted('select')).toEqual([[{ id: 'event-1' }]]);
      });
    });

    describe('when an audit event is selected', () => {
      const mockEvent = { id: 'event-1', eventName: 'ai_agent_session_ended', details: {} };

      beforeEach(() => {
        createComponent({
          props: { selectedEvent: mockEvent },
        });
      });

      it('renders the audit event details panel instead of the session body', () => {
        expect(findAuditEventPanel().exists()).toBe(true);
        expect(findSessionDetailsBody().exists()).toBe(false);
      });

      it('emits close when DynamicPanel emits close', async () => {
        await findDynamicPanel().vm.$emit('close');

        expect(wrapper.emitted('close')).toHaveLength(1);
      });

      it('renders the back and prev/next controls in the chrome', () => {
        expect(findBackButton().exists()).toBe(true);
        expect(findPrevButton().exists()).toBe(true);
        expect(findNextButton().exists()).toBe(true);
      });

      it('emits back when the back button is clicked', () => {
        findBackButton().vm.$emit('click');

        expect(wrapper.emitted('back')).toHaveLength(1);
      });

      it('renders the download button with the active item download path', () => {
        expect(wrapper.findByTestId('download-audit-artifact-button').exists()).toBe(true);
        expect(wrapper.findByTestId('download-audit-artifact-button').attributes('href')).toBe(
          mockActiveItem.downloadPath,
        );
      });

      it('does not render the download button when the active item has no download path', () => {
        createComponent({
          props: {
            activeItem: { ...mockActiveItem, downloadPath: null },
            selectedEvent: mockEvent,
          },
        });

        expect(wrapper.findByTestId('download-audit-artifact-button').exists()).toBe(false);
      });
    });

    describe('session details section', () => {
      it('renders CrudComponent', () => {
        expect(findCrudComponent().exists()).toBe(true);
      });

      it('renders view full session details button in actions slot', () => {
        expect(findViewFullSessionButton().exists()).toBe(true);
        expect(findViewFullSessionButton().text()).toBe('View full session details');
        expect(findViewFullSessionButton().attributes('href')).toBe(mockActiveItem.webPath);
      });

      it('renders session row with session link', () => {
        expect(findSessionLink().attributes('href')).toBe(mockActiveItem.webPath);
        expect(findSessionLink().text()).toBe('#1908');
      });

      it('renders date row with formatted date', () => {
        expect(findFormattedDate().text()).toBe('2024-01-01 12:00:00 UTC');
      });

      it('renders project row with project link', () => {
        expect(findProjectLink().attributes('href')).toBe(mockActiveItem.project.webPath);
      });

      it('renders project row with a hyphen placeholder when project is not present', () => {
        createComponent({
          props: {
            activeItem: {
              ...mockActiveItem,
              project: null,
            },
          },
        });

        expect(findProjectLink().exists()).toBe(false);
        expect(wrapper.findByTestId('project-empty').text()).toBe('—');
      });
    });
  });

  describe('audit events query and navigation', () => {
    describe('crossing a page boundary going forward', () => {
      let handler;

      beforeEach(async () => {
        handler = jest
          .fn()
          .mockResolvedValueOnce(pageOneResponse)
          .mockResolvedValueOnce(pageTwoResponse);

        createComponent({ props: { selectedEvent: pageOneEvents[1] }, handler });
        await waitForPromises();
      });

      it('fetches the next page using the current endCursor', async () => {
        wrapper.vm.goToNext();
        await waitForPromises();

        expect(handler).toHaveBeenCalledTimes(2);
        expect(handler).toHaveBeenLastCalledWith(
          expect.objectContaining({ after: pageOneEvents[1].id, before: null }),
        );
      });

      it('auto-selects the first event of the newly loaded page', async () => {
        wrapper.vm.goToNext();
        await waitForPromises();

        expect(wrapper.emitted('select')).toEqual([[pageTwoEvents[0]]]);
      });

      it('disables both buttons while the fetch is in flight', async () => {
        wrapper.vm.goToNext();
        await nextTick();

        expect(wrapper.vm.hasPrevEvent).toBe(false);
        expect(wrapper.vm.hasNextEvent).toBe(false);

        await waitForPromises();
      });
    });

    describe('crossing a page boundary going backward', () => {
      let handler;

      beforeEach(async () => {
        handler = jest
          .fn()
          .mockResolvedValueOnce(pageTwoResponse)
          .mockResolvedValueOnce(pageOneResponse);

        createComponent({ props: { selectedEvent: pageTwoEvents[0] }, handler });
        await waitForPromises();
      });

      it('fetches the previous page using the current startCursor', async () => {
        wrapper.vm.goToPrevious();
        await waitForPromises();

        expect(handler).toHaveBeenCalledTimes(2);
        expect(handler).toHaveBeenLastCalledWith(
          expect.objectContaining({ before: pageTwoEvents[0].id, after: null }),
        );
      });

      it('auto-selects the last event of the newly loaded page', async () => {
        wrapper.vm.goToPrevious();
        await waitForPromises();

        expect(wrapper.emitted('select')).toEqual([[pageOneEvents[1]]]);
      });
    });

    describe('when there are no more pages', () => {
      it('does not fetch or emit select when goToNext is called at the last event with no next page', async () => {
        const handler = jest.fn().mockResolvedValue(pageTwoResponse);
        createComponent({ props: { selectedEvent: pageTwoEvents[1] }, handler });
        await waitForPromises();

        wrapper.vm.goToNext();
        await waitForPromises();

        expect(handler).toHaveBeenCalledTimes(1);
        expect(wrapper.emitted('select')).toBeUndefined();
      });

      it('does not fetch or emit select when goToPrevious is called at the first event with no previous page', async () => {
        const handler = jest.fn().mockResolvedValue(pageOneResponse);
        createComponent({ props: { selectedEvent: pageOneEvents[0] }, handler });
        await waitForPromises();

        wrapper.vm.goToPrevious();
        await waitForPromises();

        expect(handler).toHaveBeenCalledTimes(1);
        expect(wrapper.emitted('select')).toBeUndefined();
      });
    });

    describe('when neither groupFullPath nor projectFullPath is provided', () => {
      it('skips the query', async () => {
        const handler = jest.fn().mockResolvedValue(pageOneResponse);
        createComponent({ handler, provide: { projectFullPath: null } });
        await waitForPromises();

        expect(handler).not.toHaveBeenCalled();
      });
    });

    describe('when the workflow is not found', () => {
      it('shows the error alert instead of the empty state', async () => {
        const handler = jest.fn().mockResolvedValue(notFoundResponse);
        createComponent({ handler });
        await waitForPromises();

        expect(wrapper.text()).toContain('Failed to load audit events.');
        expect(wrapper.findByTestId('empty-state').exists()).toBe(false);
      });
    });

    describe('when the active session changes', () => {
      const OTHER_SESSION_ID = 'gid://gitlab/Ai::DuoWorkflows::Workflow/2909';

      const pageToSecondPage = async (handler) => {
        createComponent({ handler });
        await waitForPromises();

        wrapper.vm.handleNext(pageOneEvents[1].id);
        await waitForPromises();

        expect(handler).toHaveBeenLastCalledWith(
          expect.objectContaining({ after: pageOneEvents[1].id }),
        );
      };

      it('queries the new session from the first page instead of reusing the old cursor', async () => {
        const handler = jest.fn().mockResolvedValue(pageOneResponse);
        await pageToSecondPage(handler);

        await wrapper.setProps({
          activeItem: { ...mockActiveItem, id: OTHER_SESSION_ID },
        });
        await waitForPromises();

        expect(handler).toHaveBeenLastCalledWith(
          expect.objectContaining({
            workflowId: OTHER_SESSION_ID,
            after: null,
            before: null,
          }),
        );
      });

      it('does not auto-select an event when a boundary fetch is abandoned mid-flight', async () => {
        const handler = jest.fn().mockResolvedValue(pageOneResponse);
        createComponent({ props: { selectedEvent: pageOneEvents[1] }, handler });
        await waitForPromises();

        // Start a boundary fetch, then switch sessions before it settles. The
        // pending auto-select must not carry over and pick an event in the new
        // session on the user's behalf.
        wrapper.vm.goToNext();
        expect(wrapper.vm.isFetchingBoundary).toBe(true);

        await wrapper.setProps({
          activeItem: { ...mockActiveItem, id: OTHER_SESSION_ID },
        });
        await waitForPromises();

        expect(wrapper.emitted('select')).toBeUndefined();
      });

      it('clears the error from a not-found session while the new session loads', async () => {
        const handler = jest
          .fn()
          .mockResolvedValueOnce(notFoundResponse)
          .mockResolvedValue(pageOneResponse);
        createComponent({ handler });
        await waitForPromises();

        expect(wrapper.text()).toContain('Failed to load audit events.');

        await wrapper.setProps({
          activeItem: { ...mockActiveItem, id: OTHER_SESSION_ID },
        });

        // The error alert outranks the loading state in the list template, so
        // a stale flag would show the old session's error during the fetch.
        expect(wrapper.text()).not.toContain('Failed to load audit events.');

        await waitForPromises();

        expect(wrapper.text()).not.toContain('Failed to load audit events.');
        expect(wrapper.findByTestId('audit-events-timeline').exists()).toBe(true);
      });
    });
  });
});
