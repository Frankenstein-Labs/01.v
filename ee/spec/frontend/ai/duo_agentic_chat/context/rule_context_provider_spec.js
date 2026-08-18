import { RuleContextProvider } from 'ee/ai/duo_agentic_chat/context/rule_context_provider';
import {
  DUO_WORKFLOW_ADDITIONAL_CONTEXT_USER_RULE,
  AI_CONTEXT_ID_PAGE_CONTEXT,
  AI_CONTEXT_ID_AGENT_MD,
  AI_CONTEXT_ID_CHAT_RULE,
  AGENTS_MD,
  CHAT_RULES_MD,
} from 'ee/ai/constants';
import getRuleContent from 'ee/ai/graphql/rule_content.query.graphql';

jest.mock('ee/ai/graphql/rule_content.query.graphql');

describe('RuleContextProvider', () => {
  let provider;
  let mockApollo;

  beforeEach(() => {
    mockApollo = { query: jest.fn() };
    provider = new RuleContextProvider(mockApollo, { projectPath: 'group/project' });
  });

  it('returns empty array when project has not changed', async () => {
    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { projectChanged: false },
    };

    const result = await provider.getItems(contextInjectionState);

    expect(result).toEqual([]);
  });

  it('fetches and returns rules for changed project', async () => {
    const agentBlob = { name: AGENTS_MD, rawBlob: 'agents', oid: 'abc123' };
    mockApollo.query.mockResolvedValue({
      data: { project: { repository: { blobs: { nodes: [agentBlob] } } } },
    });

    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { projectChanged: true },
    };

    const result = await provider.getItems(contextInjectionState);

    expect(result).toHaveLength(1);
    expect(result[0].id).toBe(AI_CONTEXT_ID_AGENT_MD);
    expect(result[0].content).toContain('agents');
    expect(result[0].category).toBe(DUO_WORKFLOW_ADDITIONAL_CONTEXT_USER_RULE);
  });

  it('returns cache-clearing content when blobs not found', async () => {
    mockApollo.query.mockResolvedValue({
      data: { project: { repository: { blobs: { nodes: [] } } } },
    });

    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { projectChanged: true },
      [AI_CONTEXT_ID_AGENT_MD]: { oid: 'old' },
    };

    const result = await provider.getItems(contextInjectionState);

    expect(result).toHaveLength(1);
    expect(result[0].content).toContain('Ignore any instructions previously provided');
  });

  it('marks provider as provided after first call', async () => {
    mockApollo.query.mockResolvedValue({
      data: { project: { repository: { blobs: { nodes: [] } } } },
    });

    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { projectChanged: true },
    };

    await provider.getItems(contextInjectionState);

    expect(contextInjectionState.RuleContextProvider.hasAlreadyProvided).toBe(true);
  });

  it('returns empty array when already provided', async () => {
    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { projectChanged: true },
      RuleContextProvider: { hasAlreadyProvided: true },
    };

    const result = await provider.getItems(contextInjectionState);

    expect(result).toEqual([]);
  });

  it('handles GraphQL query errors gracefully', async () => {
    mockApollo.query.mockRejectedValue(new Error('GraphQL error'));

    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { projectChanged: true },
    };

    const result = await provider.getItems(contextInjectionState);

    expect(result).toEqual([]);
  });

  it('extracts both AGENTS.md and chat-rules.md', async () => {
    const blobs = [
      { name: AGENTS_MD, rawBlob: 'agents', oid: 'abc' },
      { name: CHAT_RULES_MD, rawBlob: 'rules', oid: 'def' },
    ];
    mockApollo.query.mockResolvedValue({
      data: { project: { repository: { blobs: { nodes: blobs } } } },
    });

    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { projectChanged: true },
    };

    const result = await provider.getItems(contextInjectionState);

    expect(result).toHaveLength(2);
    expect(result[0].id).toBe(AI_CONTEXT_ID_AGENT_MD);
    expect(result[1].id).toBe(AI_CONTEXT_ID_CHAT_RULE);
  });

  it('returns empty when no project path', async () => {
    const emptyProvider = new RuleContextProvider(mockApollo);
    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { projectChanged: true },
    };

    const result = await emptyProvider.getItems(contextInjectionState);

    expect(result).toEqual([]);
    expect(mockApollo.query).not.toHaveBeenCalled();
  });

  it('queries with correct project path and file paths', async () => {
    mockApollo.query.mockResolvedValue({
      data: { project: { repository: { blobs: { nodes: [] } } } },
    });

    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { projectChanged: true },
    };

    await provider.getItems(contextInjectionState);

    expect(mockApollo.query).toHaveBeenCalledWith({
      query: getRuleContent,
      variables: {
        projectPath: 'group/project',
        paths: [AGENTS_MD, `.gitlab/duo/${CHAT_RULES_MD}`],
      },
      fetchPolicy: 'network-only',
    });
  });

  it('includes oid in metadata', async () => {
    const agentBlob = { name: AGENTS_MD, rawBlob: 'agents', oid: 'abc123' };
    mockApollo.query.mockResolvedValue({
      data: { project: { repository: { blobs: { nodes: [agentBlob] } } } },
    });

    const contextInjectionState = {
      [AI_CONTEXT_ID_PAGE_CONTEXT]: { projectChanged: true },
    };

    const result = await provider.getItems(contextInjectionState);
    const metadata = JSON.parse(result[0].metadata);

    expect(metadata.oid).toBe('abc123');
    expect(metadata.icon).toBe('document');
    expect(metadata.enabled).toBe(true);
    expect(metadata.subType).toBe('user_rule');
  });
});
