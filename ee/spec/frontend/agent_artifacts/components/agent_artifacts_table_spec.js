import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlKeysetPagination, GlTruncate, GlLoadingIcon, GlAlert, GlIcon } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import AgentArtifactsTable from 'ee/agent_artifacts/components/agent_artifacts_table.vue';
import getAgentArtifactsQuery from 'ee/agent_artifacts/graphql/queries/get_agent_artifacts.query.graphql';
import getProjectAgentArtifactsQuery from 'ee/agent_artifacts/graphql/queries/get_project_agent_artifacts.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { DEFAULT_CLIENT_TYPE } from 'ee/agent_artifacts/constants';
import {
  mockArtifactNodes,
  mockArtifactNodeNoWebPath,
  mockPageInfo,
  mockAgentArtifactsResponse,
  mockProjectAgentArtifactsResponse,
  mockEmptyAgentArtifactsResponse,
  mockUser,
} from '../mock_data';

Vue.use(VueApollo);

const GROUP_FULL_PATH = 'gitlab-org';
const PROJECT_FULL_PATH = 'g/p';

describe('AgentArtifactsTable', () => {
  let wrapper;

  const createComponent = ({
    handler = jest.fn().mockResolvedValue(mockAgentArtifactsResponse),
    filter = {},
    provide = {},
  } = {}) => {
    const apolloProvider = createMockApollo([[getAgentArtifactsQuery, handler]]);

    wrapper = mountExtended(AgentArtifactsTable, {
      apolloProvider,
      provide: {
        groupFullPath: GROUP_FULL_PATH,
        ...provide,
      },
      propsData: {
        filter,
      },
      stubs: {
        GlTruncate,
      },
    });

    return handler;
  };

  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ handler: jest.fn().mockReturnValue(new Promise(() => {})) });
    });

    it('shows the table with busy state', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });
  });

  describe('when data is loaded', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('displays ai items', () => {
      const truncate = wrapper.findByTestId('ai-item-name').findComponent(GlTruncate);
      expect(truncate.props('text')).toBe('False positive detection/v1');
    });

    it('renders session links', () => {
      const sessionLinks = wrapper.findAllByTestId('session-link');
      expect(sessionLinks).toHaveLength(2);
      expect(sessionLinks.at(0).attributes('href')).toBe(mockArtifactNodes[0].webPath);
      expect(sessionLinks.at(0).text()).toBe('#1908');
    });

    it('displays audit events count', () => {
      const auditCounts = wrapper.findAllByTestId('audit-events-count');
      expect(auditCounts).toHaveLength(2);
      expect(auditCounts.at(0).text()).toBe(`${mockArtifactNodes[0].auditEventsCount}`);
    });

    it('renders project links', () => {
      const { project } = mockArtifactNodes[0];
      const projectLinks = wrapper.findAllByTestId('project-link');
      expect(projectLinks).toHaveLength(2);
      expect(projectLinks.at(0).attributes('href')).toBe(project.webPath);
      const truncate = projectLinks.at(0).findComponent(GlTruncate);
      expect(truncate.props('text')).toBe(project.name);
    });

    it('displays formatted start time', () => {
      const startTimes = wrapper.findAllByTestId('start-time');
      expect(startTimes).toHaveLength(2);
      expect(startTimes.at(0).text()).toContain('2026-03-05');
      expect(startTimes.at(0).text()).toContain('22:14:17');
    });

    describe('user column', () => {
      it('renders the user name link when triggeredBy is present', () => {
        const userLinks = wrapper.findAllByTestId('user-link');
        expect(userLinks).toHaveLength(2);
        expect(userLinks.at(0).attributes('href')).toBe(mockUser.webPath);
        expect(userLinks.at(0).text()).toBe(mockUser.name);
      });

      it('renders the user avatar when triggeredBy is present', () => {
        const userAvatars = wrapper.findAllByTestId('user-avatar');
        expect(userAvatars).toHaveLength(2);
      });
    });

    describe('aiItem client type display', () => {
      it('renders the client type icon when the client type has an icon', () => {
        const icon = wrapper.findByTestId('ai-item-client-type-icon').findComponent(GlIcon);
        expect(icon.exists()).toBe(true);
        expect(icon.props('name')).toBe(DEFAULT_CLIENT_TYPE.icon);
      });

      it('renders the client type name', () => {
        expect(wrapper.findByTestId('ai-item-client-type-name').text()).toBe(
          DEFAULT_CLIENT_TYPE.name,
        );
      });
    });
  });

  describe('empty cell fallbacks', () => {
    beforeEach(async () => {
      const handler = jest.fn().mockResolvedValue({
        data: {
          group: {
            id: 'gid://gitlab/Group/1',
            duoWorkflowSessionArtifacts: {
              count: 1,
              nodes: [mockArtifactNodeNoWebPath],
              pageInfo: { ...mockPageInfo, hasNextPage: false, hasPreviousPage: false },
              __typename: 'DuoWorkflowSessionArtifactConnection',
            },
            __typename: 'Group',
          },
        },
      });
      createComponent({ handler });
      await waitForPromises();
    });

    it('renders a hyphen instead of a session link when webPath is null', () => {
      expect(wrapper.findByTestId('session-link').exists()).toBe(false);
      expect(wrapper.findByTestId('session-empty').text()).toBe('—');
    });

    it('renders a hyphen instead of a project link when project is null', () => {
      expect(wrapper.findByTestId('project-link').exists()).toBe(false);
      expect(wrapper.findByTestId('project-empty').text()).toBe('—');
    });

    it('renders a hyphen instead of a user link when triggeredBy is null', () => {
      expect(wrapper.findByTestId('user-link').exists()).toBe(false);
      expect(wrapper.findByTestId('user-empty').text()).toBe('—');
    });
  });

  describe('pagination', () => {
    describe('when pages available', () => {
      let handler;

      beforeEach(async () => {
        handler = createComponent();
        await waitForPromises();
      });

      it('renders pagination', () => {
        expect(findPagination().exists()).toBe(true);
      });

      it('fetches next page when pagination emits next', async () => {
        findPagination().vm.$emit('next', mockPageInfo.endCursor);
        await waitForPromises();

        expect(handler).toHaveBeenCalledTimes(2);
        expect(handler).toHaveBeenLastCalledWith(
          expect.objectContaining({ after: mockPageInfo.endCursor, before: null }),
        );
      });

      it('fetches previous page when pagination emits prev', async () => {
        findPagination().vm.$emit('prev', mockPageInfo.startCursor);
        await waitForPromises();

        expect(handler).toHaveBeenCalledTimes(2);
        expect(handler).toHaveBeenLastCalledWith(
          expect.objectContaining({ before: mockPageInfo.startCursor, after: null }),
        );
      });
    });

    describe('when no pages available', () => {
      it('does not render pagination', async () => {
        createComponent({
          handler: jest.fn().mockResolvedValue(mockEmptyAgentArtifactsResponse),
        });
        await waitForPromises();

        expect(findPagination().exists()).toBe(false);
      });
    });
  });

  describe('empty state', () => {
    beforeEach(async () => {
      createComponent({
        handler: jest.fn().mockResolvedValue(mockEmptyAgentArtifactsResponse),
      });
      await waitForPromises();
    });

    it('shows empty state message', () => {
      expect(wrapper.text()).toContain('No agent artifacts found.');
    });

    describe('when AI audit event storage is disabled', () => {
      const SETTINGS_PATH = '/groups/gitlab-org/-/settings/gitlab_duo/configuration';

      it('shows the storage disabled nudge when storage is disabled and no filter is active', async () => {
        createComponent({
          handler: jest.fn().mockResolvedValue(mockEmptyAgentArtifactsResponse),
          provide: {
            aiAuditEventsStorageEnabled: false,
            aiAuditEventsSettingsPath: SETTINGS_PATH,
          },
        });
        await waitForPromises();

        expect(wrapper.findByTestId('storage-disabled-empty-state').exists()).toBe(true);
        expect(wrapper.text()).not.toContain('No agent artifacts found.');
        expect(wrapper.findByTestId('enable-storage-link').attributes('href')).toBe(SETTINGS_PATH);
      });

      it('shows the generic empty state when a filter is active', async () => {
        createComponent({
          handler: jest.fn().mockResolvedValue(mockEmptyAgentArtifactsResponse),
          filter: { name: 'Test Agent' },
          provide: {
            aiAuditEventsStorageEnabled: false,
            aiAuditEventsSettingsPath: SETTINGS_PATH,
          },
        });
        await waitForPromises();

        expect(wrapper.findByTestId('storage-disabled-empty-state').exists()).toBe(false);
        expect(wrapper.text()).toContain('No agent artifacts found.');
      });

      it('shows the storage disabled nudge in project mode with the project settings path', async () => {
        const PROJECT_SETTINGS_PATH = '/g/p/-/edit#js-gitlab-duo-settings';
        const emptyProjectResponse = {
          data: {
            project: {
              id: 'gid://gitlab/Project/1',
              duoWorkflowSessionArtifacts: {
                count: 0,
                nodes: [],
                pageInfo: {
                  startCursor: null,
                  endCursor: null,
                  hasNextPage: false,
                  hasPreviousPage: false,
                  __typename: 'PageInfo',
                },
                __typename: 'DuoWorkflowSessionArtifactConnection',
              },
              __typename: 'Project',
            },
          },
        };
        const handler = jest.fn().mockResolvedValue(emptyProjectResponse);
        const apolloProvider = createMockApollo([[getProjectAgentArtifactsQuery, handler]]);

        wrapper = mountExtended(AgentArtifactsTable, {
          apolloProvider,
          provide: {
            groupFullPath: null,
            projectFullPath: PROJECT_FULL_PATH,
            aiAuditEventsStorageEnabled: false,
            aiAuditEventsSettingsPath: PROJECT_SETTINGS_PATH,
          },
          propsData: {
            filter: {},
          },
          stubs: {
            GlTruncate,
          },
        });
        await waitForPromises();

        expect(wrapper.findByTestId('storage-disabled-empty-state').exists()).toBe(true);
        expect(wrapper.text()).not.toContain('No agent artifacts found.');
        expect(wrapper.findByTestId('enable-storage-link').attributes('href')).toBe(
          PROJECT_SETTINGS_PATH,
        );
      });

      it('renders the nudge as plain text with no link when the settings path is empty', async () => {
        createComponent({
          handler: jest.fn().mockResolvedValue(mockEmptyAgentArtifactsResponse),
          provide: {
            aiAuditEventsStorageEnabled: false,
            aiAuditEventsSettingsPath: '',
          },
        });
        await waitForPromises();

        expect(wrapper.findByTestId('storage-disabled-empty-state').exists()).toBe(true);
        expect(wrapper.findByTestId('enable-storage-link').exists()).toBe(false);
        expect(wrapper.text()).toContain('AI audit event storage is turned off');
        expect(wrapper.text()).toContain('Turn on storage');
      });
    });

    it('shows the generic empty state when storage is enabled', async () => {
      createComponent({
        handler: jest.fn().mockResolvedValue(mockEmptyAgentArtifactsResponse),
        provide: {
          aiAuditEventsStorageEnabled: true,
          aiAuditEventsSettingsPath: '/groups/gitlab-org/-/settings/gitlab_duo/configuration',
        },
      });
      await waitForPromises();

      expect(wrapper.findByTestId('storage-disabled-empty-state').exists()).toBe(false);
      expect(wrapper.text()).toContain('No agent artifacts found.');
    });
  });

  describe('error state', () => {
    beforeEach(async () => {
      createComponent({
        handler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
      });
      await waitForPromises();
    });

    it('shows error alert', () => {
      const alert = wrapper.findComponent(GlAlert);
      expect(alert.exists()).toBe(true);
      expect(alert.text()).toContain('Failed to load agent artifacts.');
    });

    it('does not show the storage disabled nudge on error, even when storage is disabled', async () => {
      createComponent({
        handler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
        provide: {
          aiAuditEventsStorageEnabled: false,
          aiAuditEventsSettingsPath: '/groups/gitlab-org/-/settings/gitlab_duo/configuration',
        },
      });
      await waitForPromises();

      expect(wrapper.findComponent(GlAlert).exists()).toBe(true);
      expect(wrapper.findByTestId('storage-disabled-empty-state').exists()).toBe(false);
    });
  });

  describe('row click handling', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('emits row-click event when a row is clicked', async () => {
      const rows = wrapper.findAllByTestId('agent-artifacts-table-row');
      await rows.at(0).trigger('click');

      expect(wrapper.emitted('row-click')).toHaveLength(1);
      expect(wrapper.emitted('row-click')[0][0]).toEqual(mockArtifactNodes[0]);
    });
  });

  describe('filtering', () => {
    it('passes filter to GraphQL query', async () => {
      const filter = { name: 'Test Agent' };
      const handler = createComponent({ filter });
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith(expect.objectContaining(filter));
    });

    it('passes not filter to GraphQL query', async () => {
      const filter = { not: { name: 'Excluded Agent' } };
      const handler = createComponent({ filter });
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith(expect.objectContaining(filter));
    });

    it('resets pagination when filter changes', async () => {
      const handler = createComponent({ filter: { name: 'Initial' } });
      await waitForPromises();

      findPagination().vm.$emit('next', mockPageInfo.endCursor);
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith(
        expect.objectContaining({ after: mockPageInfo.endCursor }),
      );

      await wrapper.setProps({ filter: { name: 'Updated' } });
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith(expect.objectContaining({ after: null, before: null }));
    });
  });

  describe('when neither groupFullPath nor projectFullPath is provided', () => {
    it('skips the query', async () => {
      const handler = createComponent({ provide: { groupFullPath: null } });
      await waitForPromises();

      expect(handler).not.toHaveBeenCalled();
    });
  });

  describe('project mode', () => {
    let handler;

    const createProjectComponent = () => {
      handler = jest.fn().mockResolvedValue(mockProjectAgentArtifactsResponse);
      const apolloProvider = createMockApollo([[getProjectAgentArtifactsQuery, handler]]);

      wrapper = mountExtended(AgentArtifactsTable, {
        apolloProvider,
        provide: {
          groupFullPath: null,
          projectFullPath: PROJECT_FULL_PATH,
        },
        propsData: {
          filter: {},
        },
        stubs: {
          GlTruncate,
        },
      });
    };

    beforeEach(async () => {
      createProjectComponent();
      await waitForPromises();
    });

    it('queries the project query with projectFullPath and no group/project path vars', () => {
      expect(handler).toHaveBeenCalledWith(
        expect.objectContaining({ projectFullPath: PROJECT_FULL_PATH }),
      );
      const variables = handler.mock.calls[0][0];
      expect(variables).not.toHaveProperty('groupFullPath');
      expect(variables).not.toHaveProperty('projectPath');
    });

    it('renders rows from data.project.duoWorkflowSessionArtifacts', () => {
      expect(wrapper.findAllByTestId('session-link')).toHaveLength(mockArtifactNodes.length);
    });

    it('hides the redundant Project column', () => {
      expect(wrapper.findAllByTestId('project-link')).toHaveLength(0);
      expect(wrapper.findAll('th').wrappers.map((th) => th.text())).not.toContain('Project');
    });
  });

  describe('group mode', () => {
    let handler;

    beforeEach(async () => {
      handler = createComponent();
      await waitForPromises();
    });

    it('queries the group query with groupFullPath', () => {
      expect(handler).toHaveBeenCalledWith(
        expect.objectContaining({ groupFullPath: GROUP_FULL_PATH }),
      );
    });

    it('renders rows from data.group.duoWorkflowSessionArtifacts', () => {
      expect(wrapper.findAllByTestId('session-link')).toHaveLength(mockArtifactNodes.length);
    });
  });
});
