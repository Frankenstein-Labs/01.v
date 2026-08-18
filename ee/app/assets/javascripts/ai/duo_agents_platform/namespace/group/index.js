import { initDuoAgentsPlatformPage } from 'ee/ai/duo_agents_platform/index';
import { AGENT_PLATFORM_GROUP_PAGE } from 'ee/ai/duo_agents_platform/constants';

export const initDuoAgentsPlatformGroupPage = () => {
  initDuoAgentsPlatformPage({
    namespace: AGENT_PLATFORM_GROUP_PAGE,
    namespaceDatasetProperties: ['groupPath', 'groupId'],
  });
};
