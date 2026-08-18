import { GlAttributeList, GlButton, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SessionDetailsBody from 'ee/agent_artifacts/components/session_details_body.vue';
import SessionAuditEventsList from 'ee/agent_artifacts/components/session_audit_events_list.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { formatAgentDefinition } from 'ee/ai/duo_agents_platform/utils';
import { DEFAULT_CLIENT_TYPE } from 'ee/agent_artifacts/constants';
import { mockUser } from '../mock_data';

jest.mock('ee/ai/duo_agents_platform/utils', () => ({
  formatAgentDefinition: jest.fn((name) => name),
}));

describe('SessionDetailsBody', () => {
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
    triggeredBy: mockUser,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(SessionDetailsBody, {
      propsData: {
        activeItem: mockActiveItem,
        sessionId: mockActiveItem.id,
        ...props,
      },
      stubs: {
        CrudComponent,
        GlAttributeList,
        GlButton,
        SessionAuditEventsList: true,
      },
    });
  };

  const findTitle = () => wrapper.findByTestId('session-content-title');
  const findAttributeList = () => wrapper.findComponent(GlAttributeList);
  const findRows = () => findAttributeList().props('items');
  const findRow = (type) => findRows().find((item) => item.type === type);
  const findProjectLink = () => wrapper.findByTestId('project-link');
  const findSessionLink = () => wrapper.findByTestId('session-link');
  const findUserContent = () => wrapper.findByTestId('user-content');
  const findUserLink = () => wrapper.findByTestId('user-link');
  const findUserEmpty = () => wrapper.findByTestId('user-empty');
  const findFormattedDate = () => wrapper.findByTestId('formatted-date');
  const findAuditEventsList = () => wrapper.findComponent(SessionAuditEventsList);
  const findDownloadButton = () => wrapper.findComponentByTestId('download-audit-artifact-button');
  const findClientTypeName = () => wrapper.findByTestId('client-type-name');
  const findClientTypeNameIcon = () =>
    wrapper.findByTestId('client-type-name').findComponent(GlIcon);

  beforeEach(() => {
    createComponent();
  });

  it('renders the formatted session title', () => {
    expect(findTitle().text()).toBe(formatAgentDefinition(mockActiveItem.workflowDefinition));
  });

  it('renders every row inline with an icon on the label', () => {
    expect(findAttributeList().props('layout')).toBe('horizontal');
    expect(findRows().map((item) => [item.label, item.icon])).toEqual([
      ['Session', 'session-ai'],
      ['User', 'user'],
      ['Date', 'clock'],
      ['Project', 'project'],
      ['Client type', 'agent-ai'],
    ]);
  });

  describe('when the session belongs to a project', () => {
    it('renders the session row linking to the session', () => {
      expect(findRow('session')).toBeDefined();
      expect(findSessionLink().attributes('href')).toBe(mockActiveItem.webPath);
      expect(findSessionLink().text()).toBe('#1908');
    });

    it('renders the project row', () => {
      expect(findRow('project')).toBeDefined();
    });

    it('renders the project link from the active item', () => {
      expect(findProjectLink().exists()).toBe(true);
      expect(findProjectLink().attributes('href')).toBe(mockActiveItem.project.webPath);
    });

    it('renders the date row', () => {
      expect(findRow('date')).toBeDefined();
      expect(findFormattedDate().exists()).toBe(true);
    });
  });

  describe('when the session belongs to a group (no project)', () => {
    beforeEach(() => {
      createComponent({ activeItem: { ...mockActiveItem, project: null } });
    });

    it('does not render the session row', () => {
      expect(findRow('session')).toBeUndefined();
    });

    it('renders the project row with a hyphen placeholder', () => {
      expect(findRow('project')).toBeDefined();
      expect(findProjectLink().exists()).toBe(false);
      expect(wrapper.findByTestId('project-empty').text()).toBe('—');
    });

    it('still renders the date row', () => {
      expect(findRow('date')).toBeDefined();
    });

    it('still renders the client type row', () => {
      expect(findRow('clientType')).toBeDefined();
    });
  });

  describe('client type row', () => {
    it('renders the client type row', () => {
      expect(findRow('clientType')).toBeDefined();
    });

    it('renders the default client type icon next to the client type name', () => {
      expect(findClientTypeNameIcon().exists()).toBe(true);
      expect(findClientTypeNameIcon().props('name')).toBe(DEFAULT_CLIENT_TYPE.icon);
    });

    it('renders the default client type name', () => {
      expect(findClientTypeName().text()).toContain(DEFAULT_CLIENT_TYPE.name);
    });
  });

  describe('user row', () => {
    it('renders the user row', () => {
      expect(findRow('user')).toBeDefined();
    });

    it('renders the user name link when triggeredBy is present', () => {
      expect(findUserContent().exists()).toBe(true);
      expect(findUserLink().attributes('href')).toBe(mockUser.webPath);
      expect(findUserLink().text()).toBe(mockUser.name);
    });

    it('renders a hyphen when triggeredBy is null', () => {
      createComponent({ activeItem: { ...mockActiveItem, triggeredBy: null } });

      expect(findUserContent().exists()).toBe(false);
      expect(findUserEmpty().text()).toBe('—');
    });
  });

  describe('download audit artifact button', () => {
    it('renders the button with a download icon', () => {
      expect(findDownloadButton().exists()).toBe(true);
      expect(findDownloadButton().props('icon')).toBe('download');
    });

    it('renders the button label', () => {
      expect(findDownloadButton().text()).toBe('Download Session Artifacts');
    });

    it('links to the download path of the active item', () => {
      expect(findDownloadButton().attributes('href')).toBe(mockActiveItem.downloadPath);
    });

    it('does not render the button when there is no download path', () => {
      createComponent({
        activeItem: { ...mockActiveItem, downloadPath: null },
      });

      expect(findDownloadButton().exists()).toBe(false);
    });
  });

  describe('audit events list', () => {
    it('renders the list when session id is present', () => {
      expect(findAuditEventsList().exists()).toBe(true);
    });

    it('does not render the list when there is no session id', () => {
      createComponent({ sessionId: null });

      expect(findAuditEventsList().exists()).toBe(false);
    });

    it('passes events, pageInfo, isLoading and hasError through to the list', () => {
      const events = [{ id: 'event-1' }];
      const pageInfo = { hasNextPage: true };

      createComponent({ events, pageInfo, isLoading: true, hasError: true });

      expect(findAuditEventsList().props('events')).toBe(events);
      expect(findAuditEventsList().props('pageInfo')).toBe(pageInfo);
      expect(findAuditEventsList().props('isLoading')).toBe(true);
      expect(findAuditEventsList().props('hasError')).toBe(true);
    });

    it('re-emits select when the list emits select', () => {
      const event = { id: 'event-1' };

      findAuditEventsList().vm.$emit('select', event);

      expect(wrapper.emitted('select')).toEqual([[event]]);
    });

    it('re-emits next when the list emits next', () => {
      findAuditEventsList().vm.$emit('next', 'cursor-1');

      expect(wrapper.emitted('next')).toEqual([['cursor-1']]);
    });

    it('re-emits prev when the list emits prev', () => {
      findAuditEventsList().vm.$emit('prev', 'cursor-1');

      expect(wrapper.emitted('prev')).toEqual([['cursor-1']]);
    });
  });
});
