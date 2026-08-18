import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlKeysetPagination, GlLoadingIcon, GlTruncate } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AiToolRulesTable from 'ee/ai/governance/components/ai_tool_management/ai_tool_rules_table.vue';
import AiToolRulesFilteredSearch from 'ee/ai/governance/components/ai_tool_management/ai_tool_rules_filtered_search.vue';
import getAiToolRulesQuery from 'ee/ai/governance/graphql/queries/get_ai_tool_rules.query.graphql';

Vue.use(VueApollo);

const mockPageInfo = {
  hasNextPage: true,
  hasPreviousPage: false,
  startCursor: 'cursor-start',
  endCursor: 'cursor-end',
  __typename: 'PageInfo',
};

const mockToolRules = {
  nodes: [
    {
      id: 'list_issues',
      name: 'list_issues',
      actionType: 'READ',
      category: 'GitLab Read',
      source: 'gitlab',
      webAccess: 'ALLOW',
      localAccess: null,
      backgroundAccess: null,
      __typename: 'AiToolRule',
    },
    {
      id: 'run_command',
      name: 'run_command',
      actionType: 'DESTROY',
      category: 'Commands',
      source: 'gitlab',
      webAccess: 'DENY',
      localAccess: 'ASK',
      backgroundAccess: 'DENY',
      __typename: 'AiToolRule',
    },
  ],
  pageInfo: mockPageInfo,
  __typename: 'AiToolRuleConnection',
};

const mockQueryResponse = (toolRules = mockToolRules) => ({
  data: { aiToolRules: toolRules },
});

describe('AiToolRulesTable', () => {
  let wrapper;
  let queryHandler;

  const createComponent = ({
    queryHandlerImpl = jest.fn().mockResolvedValue(mockQueryResponse()),
    provide = {},
  } = {}) => {
    queryHandler = queryHandlerImpl;

    const apolloProvider = createMockApollo([[getAiToolRulesQuery, queryHandler]]);

    wrapper = mountExtended(AiToolRulesTable, {
      apolloProvider,
      provide: {
        groupFullPath: 'gitlab-org',
        ...provide,
      },
      stubs: {
        AiToolRuleAccessControl: true,
        GlTruncate,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findRows = () => wrapper.findAllByTestId('ai-tool-rule-row');
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findAccessControls = (testId) => wrapper.findAllByTestId(testId);
  const findFilteredSearch = () => wrapper.findComponent(AiToolRulesFilteredSearch);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ queryHandlerImpl: jest.fn(() => new Promise(() => {})) });
    });

    it('shows loading icon', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });

    it('does not show error alert', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when data is loaded', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders a row for each tool rule', () => {
      expect(findRows()).toHaveLength(2);
    });

    it('renders tool names', () => {
      const names = wrapper.findAllByTestId('tool-name');
      expect(names.at(0).text()).toBe('list_issues');
      expect(names.at(1).text()).toBe('run_command');
    });

    it('renders tool categories', () => {
      const categories = wrapper.findAllByTestId('tool-category');
      expect(categories.at(0).text()).toBe('GitLab Read');
      expect(categories.at(1).text()).toBe('Commands');
    });

    it('renders tool sources', () => {
      const sources = wrapper.findAllByTestId('tool-source');
      expect(sources.at(0).text()).toBe('gitlab');
    });

    it('renders action type badges', () => {
      expect(wrapper.findAllByTestId('tool-action-type').at(0).text()).toBe('READ');
      expect(wrapper.findAllByTestId('tool-action-type').at(1).text()).toBe('DESTROY');
    });

    it('renders a web access control per row', () => {
      expect(findAccessControls('tool-web-access-control')).toHaveLength(2);
    });

    it('renders a local access control per row', () => {
      expect(findAccessControls('tool-local-access-control')).toHaveLength(2);
    });

    it('renders a Runner access control per row', () => {
      expect(findAccessControls('tool-background-access-control')).toHaveLength(2);
    });

    it('renders a "Runner access" column header', () => {
      expect(wrapper.text()).toContain('Runner access');
    });
  });

  describe('pagination', () => {
    describe('when pages are available', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('renders pagination', () => {
        expect(findPagination().exists()).toBe(true);
      });

      it('fetches next page when pagination emits next', async () => {
        findPagination().vm.$emit('next', mockPageInfo.endCursor);
        await waitForPromises();

        expect(queryHandler).toHaveBeenCalledTimes(2);
        expect(queryHandler).toHaveBeenLastCalledWith(
          expect.objectContaining({ after: mockPageInfo.endCursor, before: null }),
        );
      });

      it('fetches previous page when pagination emits prev', async () => {
        findPagination().vm.$emit('prev', mockPageInfo.startCursor);
        await waitForPromises();

        expect(queryHandler).toHaveBeenCalledTimes(2);
        expect(queryHandler).toHaveBeenLastCalledWith(
          expect.objectContaining({ before: mockPageInfo.startCursor, after: null }),
        );
      });
    });

    describe('when no pages are available', () => {
      it('does not render pagination', async () => {
        createComponent({
          queryHandlerImpl: jest.fn().mockResolvedValue(
            mockQueryResponse({
              ...mockToolRules,
              pageInfo: { hasNextPage: false, hasPreviousPage: false, __typename: 'PageInfo' },
            }),
          ),
        });
        await waitForPromises();

        expect(findPagination().exists()).toBe(false);
      });
    });
  });

  describe('filtering', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the filtered search bar', () => {
      expect(findFilteredSearch().exists()).toBe(true);
    });

    it('requests with null filters initially', () => {
      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ search: null, actionType: null }),
      );
    });

    it('maps emitted filters to query variables', async () => {
      findFilteredSearch().vm.$emit('filter', { search: 'issues', actionType: 'READ' });
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ search: 'issues', actionType: 'READ' }),
      );
    });

    it('resets keyset pagination when filters change', async () => {
      findPagination().vm.$emit('next', mockPageInfo.endCursor);
      await waitForPromises();
      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ after: mockPageInfo.endCursor }),
      );

      findFilteredSearch().vm.$emit('filter', { search: 'issues', actionType: null });
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ after: null, before: null, search: 'issues' }),
      );
    });

    it('sends null when filters are cleared', async () => {
      findFilteredSearch().vm.$emit('filter', { search: '', actionType: null });
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ search: null, actionType: null }),
      );
    });
  });

  describe('empty state', () => {
    beforeEach(async () => {
      createComponent({
        queryHandlerImpl: jest.fn().mockResolvedValue(
          mockQueryResponse({
            nodes: [],
            pageInfo: { hasNextPage: false, hasPreviousPage: false, __typename: 'PageInfo' },
            __typename: 'AiToolRuleConnection',
          }),
        ),
      });
      await waitForPromises();
    });

    it('shows empty state message', () => {
      expect(wrapper.findByTestId('ai-tool-rules-empty').exists()).toBe(true);
      expect(wrapper.text()).toContain('No tool rules found.');
    });
  });

  describe('error state', () => {
    beforeEach(async () => {
      createComponent({
        queryHandlerImpl: jest.fn().mockRejectedValue(new Error('GraphQL error')),
      });
      await waitForPromises();
    });

    it('shows error alert', () => {
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toContain('Failed to load tool rules.');
    });
  });

  describe('bypass warnings', () => {
    const baseToolRule = {
      actionType: 'READ',
      category: 'GitLab Read',
      source: 'gitlab',
      webAccess: 'ALLOW',
      localAccess: null,
      backgroundAccess: null,
      __typename: 'AiToolRule',
    };

    const mockBypassRules = {
      nodes: [
        { ...baseToolRule, id: 'gitlab_api_get', name: 'gitlab_api_get' },
        { ...baseToolRule, id: 'gitlab_graphql', name: 'gitlab_graphql' },
        {
          ...baseToolRule,
          id: 'run_command',
          name: 'run_command',
          actionType: 'DESTROY',
          category: 'Commands',
        },
        { ...baseToolRule, id: 'list_issues', name: 'list_issues' },
      ],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: null,
        __typename: 'PageInfo',
      },
      __typename: 'AiToolRuleConnection',
    };

    const READ_BYPASS_WARNING =
      'This tool can access any GitLab read endpoint. Changes to other read tools may not take effect if this tool remains on Allow.';
    const COMMAND_BYPASS_WARNING =
      'This tool can invoke shell commands including git, curl, and file operations. It may bypass restrictions set on other tools.';

    // Fixture row order: gitlab_api_get, gitlab_graphql, run_command, list_issues
    const ROW_INDEX = {
      gitlab_api_get: 0,
      gitlab_graphql: 1,
      run_command: 2,
      list_issues: 3,
    };

    const findRowWarning = (toolName) => {
      const rows = wrapper.findAllByTestId('ai-tool-rule-row');
      return rows.at(ROW_INDEX[toolName]).find('[data-testid="tool-bypass-warning"]');
    };

    beforeEach(async () => {
      createComponent({
        queryHandlerImpl: jest.fn().mockResolvedValue(mockQueryResponse(mockBypassRules)),
      });
      await waitForPromises();
    });

    it('shows the read-bypass warning for gitlab_api_get', () => {
      expect(findRowWarning('gitlab_api_get').exists()).toBe(true);
      expect(findRowWarning('gitlab_api_get').text()).toBe(READ_BYPASS_WARNING);
    });

    it('shows the read-bypass warning for gitlab_graphql', () => {
      expect(findRowWarning('gitlab_graphql').exists()).toBe(true);
      expect(findRowWarning('gitlab_graphql').text()).toBe(READ_BYPASS_WARNING);
    });

    it('shows the command-bypass warning for run_command', () => {
      expect(findRowWarning('run_command').exists()).toBe(true);
      expect(findRowWarning('run_command').text()).toBe(COMMAND_BYPASS_WARNING);
    });

    it('does not show a warning for tools without a known bypass', () => {
      expect(findRowWarning('list_issues').exists()).toBe(false);
    });
  });

  describe('group mode (no project)', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('queries with projectPath null and does not fire a second (floor) query', () => {
      expect(queryHandler).toHaveBeenCalledTimes(1);
      expect(queryHandler).toHaveBeenLastCalledWith(expect.objectContaining({ projectPath: null }));
    });

    it('does not render inheritance badges', () => {
      expect(wrapper.findByTestId('tool-web-access-inheritance').exists()).toBe(false);
      expect(wrapper.findByTestId('tool-local-access-inheritance').exists()).toBe(false);
      expect(wrapper.findByTestId('tool-background-access-inheritance').exists()).toBe(false);
    });
  });

  describe('project-scoped mode', () => {
    const PROJECT_PATH = 'gitlab-org/my-project';

    // Floor (group) values: list_issues web ALLOW (matches effective -> inherited),
    // background null (matches effective -> inherited);
    // run_command web ASK (effective DENY -> overridden),
    // background ALLOW (effective DENY -> overridden).
    const mockFloorRules = {
      nodes: [
        {
          ...mockToolRules.nodes[0],
          webAccess: 'ALLOW',
          localAccess: null,
          backgroundAccess: null,
        },
        {
          ...mockToolRules.nodes[1],
          webAccess: 'ASK',
          localAccess: 'ASK',
          backgroundAccess: 'ALLOW',
        },
      ],
      pageInfo: mockPageInfo,
      __typename: 'AiToolRuleConnection',
    };

    // The same query document serves both reads; route by presence of projectPath.
    const scopedHandler = ({ effective = mockToolRules, floor = mockFloorRules } = {}) =>
      jest.fn((variables) =>
        Promise.resolve(mockQueryResponse(variables.projectPath ? effective : floor)),
      );

    const findWebControls = () => wrapper.findAllComponentsByTestId('tool-web-access-control');
    const findWebBadges = () => wrapper.findAllByTestId('tool-web-access-inheritance');
    const findBackgroundControls = () =>
      wrapper.findAllComponentsByTestId('tool-background-access-control');
    const findBackgroundBadges = () =>
      wrapper.findAllByTestId('tool-background-access-inheritance');

    it('fires both the effective (with projectPath) and floor (without) queries', async () => {
      createComponent({
        queryHandlerImpl: scopedHandler(),
        provide: { projectFullPath: PROJECT_PATH },
      });
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledWith(
        expect.objectContaining({ projectPath: PROJECT_PATH }),
      );
      expect(queryHandler).toHaveBeenCalledWith(
        expect.not.objectContaining({ projectPath: expect.anything() }),
      );
    });

    it('passes projectFullPath and the per-tool floor value to each access control', async () => {
      createComponent({
        queryHandlerImpl: scopedHandler(),
        provide: { projectFullPath: PROJECT_PATH },
      });
      await waitForPromises();

      expect(findWebControls().at(0).props('projectFullPath')).toBe(PROJECT_PATH);
      expect(findWebControls().at(0).props('floorValue')).toBe('ALLOW');
      expect(findWebControls().at(1).props('floorValue')).toBe('ASK');
    });

    it('passes the per-tool floor value to each Runner (backgroundAccess) control', async () => {
      createComponent({
        queryHandlerImpl: scopedHandler(),
        provide: { projectFullPath: PROJECT_PATH },
      });
      await waitForPromises();

      expect(findBackgroundControls().at(0).props('floorValue')).toBe(null);
      expect(findBackgroundControls().at(1).props('floorValue')).toBe('ALLOW');
    });

    it('shows "Inherited from group" when effective matches floor and "Overrides group" otherwise', async () => {
      createComponent({
        queryHandlerImpl: scopedHandler(),
        provide: { projectFullPath: PROJECT_PATH },
      });
      await waitForPromises();

      expect(findWebBadges().at(0).text()).toBe('Inherited from group');
      expect(findWebBadges().at(1).text()).toBe('Overrides group');
    });

    it('shows the same inheritance semantics for the Runner (backgroundAccess) column', async () => {
      createComponent({
        queryHandlerImpl: scopedHandler(),
        provide: { projectFullPath: PROJECT_PATH },
      });
      await waitForPromises();

      expect(findBackgroundBadges().at(0).text()).toBe('Inherited from group');
      expect(findBackgroundBadges().at(1).text()).toBe('Overrides group');
    });

    it('renders access controls as disabled when not editable', async () => {
      createComponent({
        queryHandlerImpl: scopedHandler(),
        provide: { projectFullPath: PROJECT_PATH, aiToolRulesEditable: false },
      });
      await waitForPromises();

      expect(findWebControls().at(0).props('disabled')).toBe(true);
    });

    it('shows a warning and falls back gracefully when the floor query fails', async () => {
      // The floor query is the one without projectPath (see scopedHandler above), so the
      // reject branch fails only the floor read while the effective read keeps resolving.
      const handler = jest.fn((variables) =>
        variables.projectPath
          ? Promise.resolve(mockQueryResponse(mockToolRules))
          : Promise.reject(new Error('floor error')),
      );
      createComponent({
        queryHandlerImpl: handler,
        provide: { projectFullPath: PROJECT_PATH },
      });
      await waitForPromises();

      expect(wrapper.findByTestId('floor-load-error').exists()).toBe(true);
      // Effective rows still render; floor unavailable -> no floor value enforced.
      expect(findRows()).toHaveLength(2);
      expect(findWebControls().at(0).props('floorValue')).toBe(null);
    });
  });
});
