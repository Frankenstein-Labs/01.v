import {
  buildSession,
  buildWorkItemSessionsQueryResponse as buildQueryResponse,
} from 'ee_jest/ai/mocks';

export { buildSession, buildQueryResponse };

export const MOCK_ITEM = {
  id: 'gid://gitlab/Issue/42',
  title: 'Test issue',
  webUrl: 'https://gitlab.example.com/group/project/-/issues/42',
};

export const FINISHED_SESSION = buildSession();

export const RUNNING_SESSION = buildSession({
  id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/2',
  status: 'RUNNING',
  humanStatus: 'Running',
  workflowDefinition: 'developer',
});

export const INPUT_REQUIRED_SESSION = buildSession({
  id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/3',
  status: 'INPUT_REQUIRED',
  humanStatus: 'Input required',
  workflowDefinition: 'developer',
});

export const SESSION_WITHOUT_PROJECT = buildSession({
  id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/6',
  project: null,
});
