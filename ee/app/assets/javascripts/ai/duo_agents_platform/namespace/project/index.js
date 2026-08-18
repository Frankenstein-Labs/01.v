import { initDuoAgentsPlatformPage } from 'ee/ai/duo_agents_platform/index';
import { AGENT_PLATFORM_PROJECT_PAGE } from 'ee/ai/duo_agents_platform/constants';

export const initDuoAgentsPlatformProjectPage = () => {
  initDuoAgentsPlatformPage({
    namespace: AGENT_PLATFORM_PROJECT_PAGE,
    namespaceDatasetProperties: ['projectPath', 'projectId', 'rootGroupId'],
  });
};
