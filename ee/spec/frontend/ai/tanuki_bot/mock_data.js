import { MESSAGE_MODEL_ROLES } from '@gitlab/duo-ui';
import {
  MESSAGE_TYPES,
  SOURCE_TYPES,
  CHAT_RESET_MESSAGE,
  CHAT_CLEAR_MESSAGE,
  CHAT_INCLUDE_MESSAGE,
} from 'ee/ai/tanuki_bot/constants';
import { PROMO_URL } from '~/constants';

export const MOCK_SLASH_COMMANDS = {
  data: {
    aiSlashCommands: [
      {
        description: 'New chat conversation.',
        name: '/new',
        shouldSubmit: false,
      },
      {
        description: 'Learn what Duo Chat can do.',
        name: '/help',
        shouldSubmit: true,
      },
    ],
  },
};

export const MOCK_SOURCE_TYPES = {
  HANDBOOK: {
    title: 'GitLab Handbook',
    source_type: SOURCE_TYPES.HANDBOOK.value,
    source_url: `${PROMO_URL}/handbook/`,
  },
  DOC: {
    stage: 'Mock Stage',
    group: 'Mock Group',
    source_type: SOURCE_TYPES.DOC.value,
    source_url: `${PROMO_URL}/company/team/`,
  },
  BLOG: {
    date: '2023-04-21',
    author: 'Test User',
    source_type: SOURCE_TYPES.BLOG.value,
    source_url: `${PROMO_URL}/blog/`,
  },
};

export const MOCK_SOURCES = Object.values(MOCK_SOURCE_TYPES);

export const MOCK_TANUKI_MESSAGE = {
  id: '123',
  content: 'Tanuki Bot message',
  contentHtml: '<p>Tanuki Bot message</p>',
  role: MESSAGE_TYPES.TANUKI,
  extras: {
    sources: MOCK_SOURCES,
    hasFeedback: false,
  },
  requestId: '987',
  errors: [],
  timestamp: '2021-04-21T12:00:00.000Z',
};

export const MOCK_USER_MESSAGE = {
  id: '456',
  content: 'User message',
  contentHtml: '<p>User message</p>',
  role: MESSAGE_TYPES.USER,
  requestId: '987',
  errors: [],
  timestamp: '2021-04-21T12:00:00.000Z',
  extras: null,
};

export const MOCK_FAILING_USER_MESSAGE = {
  content: 'User message that caused an error',
  role: MESSAGE_TYPES.USER,
  requestId: null,
  errors: ['Oh darn, you are not allowed to use AI!'],
};

export const MOCK_CHUNK_MESSAGE = (content = '', chunkId = 0, requestId = 1) => {
  return {
    id: '611363bc-c75a-44e2-80cd-f22ab5e665be',
    requestId,
    content,
    errors: [],
    role: 'ASSISTANT',
    timestamp: '2024-05-29T17:17:06Z',
    type: null,
    chunkId,
    extras: {
      sources: null,
    },
  };
};

export const GENERATE_MOCK_TANUKI_RES = (
  body = JSON.stringify(MOCK_TANUKI_MESSAGE),
  requestId = '987',
) => {
  return {
    id: '123',
    content: body,
    contentHtml: `<p>${body}</p>`,
    errors: [],
    requestId,
    role: MOCK_TANUKI_MESSAGE.role,
    timestamp: '2021-04-21T12:00:00.000Z',
    type: null,
    chunkId: null,
    extras: null,
  };
};

export const MOCK_CHAT_CACHED_MESSAGES_RES = {
  data: {
    aiMessages: {
      nodes: [MOCK_USER_MESSAGE, MOCK_TANUKI_MESSAGE],
    },
  },
};

export const MOCK_TANUKI_BOT_MUTATATION_RES = {
  data: { aiAction: { errors: [], requestId: '123', threadId: 'thread-123' } },
};

export const MOCK_USER_ID = 'gid://gitlab/User/1';
export const MOCK_CLIENT_SUBSCRIPTION_ID = '123';
export const MOCK_RESOURCE_ID = 'gid://gitlab/Issue/1';

export const MOCK_THREADS = [
  {
    __typename: 'AiConversationsThread',
    id: 'gid://gitlab/Ai::Conversation::Thread/121',
    lastUpdatedAt: '2025-02-14T15:26:11Z',
    createdAt: '2025-02-14T15:14:02Z',
    conversationType: 'DUO_CHAT',
    title: 'ddd',
  },
  {
    __typename: 'AiConversationsThread',
    id: 'gid://gitlab/Ai::Conversation::Thread/120',
    lastUpdatedAt: '2025-02-14T15:13:57Z',
    createdAt: '2025-02-14T15:13:57Z',
    conversationType: 'DUO_CHAT',
    title: null,
  },
];

export const MOCK_THREADS_RESPONSE = {
  data: {
    aiConversationThreads: {
      __typename: 'AiConversationsThreadConnection',
      nodes: MOCK_THREADS,
      pageInfo: {
        __typename: 'PageInfo',
        endCursor:
          'eyJsYXN0X3VwZGF0ZWRfYXQiOiIyMDI1LTAyLTE0IDE1OjEzOjU3LjkzMDgzNDAwMCArMDAwMCIsImlkIjoiMTIwIn0',
        hasNextPage: false,
      },
    },
  },
};

export const MOCK_AI_RESOURCE_DATA = JSON.stringify({
  type: 'issue',
  id: 789,
  title: 'Test Issue',
});
export const MOCK_CONTEXT_PRESETS_RESPONSE = {
  data: {
    aiChatContextPresets: {
      questions: [
        'What are the main points from this MR discussion?',
        'What changes were requested by reviewers?',
        'What concerns remain unresolved in this MR?',
        'What changed in this diff?',
      ],
      aiResourceData: MOCK_AI_RESOURCE_DATA,
    },
  },
};

export const MOCK_RESPONSE_MESSAGE = {
  id: '123',
  content:
    'I\'ll write a simple Python function with comments for you. Here\'s an example:\\\\n\\\\n```python\\\\ndef calculate_factorial(n):\\\\n    \\\\"\\\\"\\\\"\\\\n    Calculate the factorial of a non-negative integer.\\\\n    \\\\n    Args:\\\\n        n (int): A non-negative integer\\\\n        \\\\n    Returns:\\\\n        int: The factorial of n (n!)\\\\n        \\\\n    Examples:\\\\n        >>> calculate_factorial(5)\\\\n        120\\\\n        >>> calculate_factorial(0)\\\\n        1\\\\n    \\\\"\\\\"\\\\"\\\\n    # Handle base cases\\\\n    if n == 0 or n == 1:\\\\n        return 1\\\\n    \\\\n    # Use recursion to calculate factorial\\\\n    return n * calculate_factorial(n - 1)\\\\n```\\\\n\\\\nThis function calculates the factorial of a number using recursion.',
  role: MESSAGE_MODEL_ROLES.assistant,
  requestId: '987',
  errors: [],
  timestamp: '2021-04-21T12:00:00.000Z',
};

export const MOCK_USER_PROMPT_MESSAGE = {
  id: '456',
  chunkId: null,
  content: 'Help me write a simple python function to calculate a factorial of a number.',
  contentHtml:
    '<p>Help me write a simple python function to calculate a factorial of a number.</p>',
  role: MESSAGE_MODEL_ROLES.user,
  requestId: '987',
  errors: [],
  timestamp: '2021-04-21T12:00:00.000Z',
};

export const SLASH_COMMANDS = [
  {
    name: CHAT_RESET_MESSAGE,
    shouldSubmit: true,
    description: 'Reset conversation, ignore the previous messages.',
  },
  {
    name: CHAT_CLEAR_MESSAGE,
    shouldSubmit: true,
    description: 'Delete all messages in this conversation.',
  },
  {
    name: '/tests',
    description: 'Write tests for the selected snippet.',
  },
  {
    name: '/refactor',
    description: 'Refactor the selected snippet.',
  },
  {
    name: '/explain',
    description: 'Explain the selected snippet.',
  },
];

export const INCLUDE_SLASH_COMMAND = {
  name: CHAT_INCLUDE_MESSAGE,
  description: 'Include additional context in the conversation.',
};

export const THREADLIST = [
  {
    __typename: 'AiConversationsThread',
    id: 'gid://gitlab/Ai::Conversation::Thread/14',
    lastUpdatedAt: '2025-01-31T11:12:05Z',
    createdAt: '2025-01-31T11:12:00Z',
    conversationType: 'DUO_CHAT',
    title: 'On the Proper Filing of Form B-789 in Triplicate',
  },
  {
    __typename: 'AiConversationsThread',
    id: 'gid://gitlab/Ai::Conversation::Thread/13',
    lastUpdatedAt: '2025-01-31T14:30:42Z',
    createdAt: '2025-01-31T14:30:36Z',
    conversationType: 'DUO_CHAT',
    title: 'The Case of the Missing Permission Slip',
  },
  {
    __typename: 'AiConversationsThread',
    id: 'gid://gitlab/Ai::Conversation::Thread/12',
    lastUpdatedAt: '2025-01-31T14:30:08Z',
    createdAt: '2025-01-31T14:30:03Z',
    conversationType: 'DUO_CHAT',
    title: 'Regarding the Metamorphosis of Code Review #2187',
  },
  {
    __typename: 'AiConversationsThread',
    id: 'gid://gitlab/Ai::Conversation::Thread/11',
    lastUpdatedAt: '2025-01-24T14:29:51Z',
    createdAt: '2025-01-24T14:29:36Z',
    conversationType: 'DUO_CHAT',
    title: "An Investigation into the Disappearance of Yesterday's Commits",
  },
  {
    __typename: 'AiConversationsThread',
    id: 'gid://gitlab/Ai::Conversation::Thread/10',
    lastUpdatedAt: '2025-01-24T14:29:25Z',
    createdAt: '2025-01-24T14:28:50Z',
    conversationType: 'DUO_CHAT',
    title: 'The Curious Incident of the Bug in the Runtime',
  },
];

export const AGENTIC_THREADLIST = [
  {
    __typename: 'DuoWorkflow',
    id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1801035',
    lastUpdatedAt: '2025-01-31T13:45:20Z',
    title: 'Help me refactor this authentication module',
    aiCatalogItemVersionId: null,
    agentName: 'GitLab Duo',
  },
  {
    __typename: 'DuoWorkflow',
    id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1796032',
    lastUpdatedAt: '2025-01-31T17:40:02Z',
    title: 'Analyze repository activity for the past week',
    aiCatalogItemVersionId: null,
    agentName: 'Data Analyst',
  },
];
