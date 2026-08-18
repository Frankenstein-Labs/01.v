import {
  getNamespaceIndexComponent,
  getMcpServersIndexComponent,
  getPreviousRoute,
  setPreviousRoute,
} from 'ee/ai/duo_agents_platform/router/utils';

import ProjectAgentsPlatformIndex from 'ee/ai/duo_agents_platform/namespace/project/project_agents_platform_index.vue';
import UserAgentsPlatformIndex from 'ee/ai/duo_agents_platform/namespace/user/user_agents_platform_index.vue';
import ProjectMcpServersIndex from 'ee/ai/duo_agents_platform/namespace/project/project_mcp_servers_index.vue';
import GroupMcpServersIndex from 'ee/ai/duo_agents_platform/namespace/group/group_mcp_servers_index.vue';

describe('getNamespaceIndexComponent', () => {
  describe('when namespace is not provided', () => {
    it('throws an error', () => {
      expect(() => getNamespaceIndexComponent()).toThrow(
        'The namespace argument must be passed to the Vue Router',
      );
    });
  });

  it.each`
    namespace    | expectedComponent             | expectedComponentName
    ${'project'} | ${ProjectAgentsPlatformIndex} | ${'ProjectAgentsPlatformIndex'}
    ${'user'}    | ${UserAgentsPlatformIndex}    | ${'UserAgentsPlatformIndex'}
    ${'group'}   | ${undefined}                  | ${'undefined'}
    ${'unknown'} | ${undefined}                  | ${'undefined'}
  `(
    'returns $expectedComponentName when namespace is $namespace',
    ({ namespace, expectedComponent }) => {
      expect(getNamespaceIndexComponent(namespace)).toBe(expectedComponent);
    },
  );
});

describe('getMcpServersIndexComponent', () => {
  describe('when namespace is not provided', () => {
    it('throws an error', () => {
      expect(() => getMcpServersIndexComponent()).toThrow(
        'The namespace argument must be passed to the Vue Router',
      );
    });
  });

  it.each`
    namespace    | expectedComponent         | expectedComponentName
    ${'project'} | ${ProjectMcpServersIndex} | ${'ProjectMcpServersIndex'}
    ${'group'}   | ${GroupMcpServersIndex}   | ${'GroupMcpServersIndex'}
    ${'user'}    | ${undefined}              | ${'undefined'}
    ${'unknown'} | ${undefined}              | ${'undefined'}
  `(
    'returns $expectedComponentName when namespace is $namespace',
    ({ namespace, expectedComponent }) => {
      expect(getMcpServersIndexComponent(namespace)).toBe(expectedComponent);
    },
  );
});

describe('Previous route', () => {
  beforeEach(() => {
    setPreviousRoute(null);
  });

  it('sets and gets a route', () => {
    const route = { name: 'test_route', params: { id: '123' } };
    setPreviousRoute(route);
    expect(getPreviousRoute()).toBe(route);
  });

  it('returns null when not set', () => {
    expect(getPreviousRoute()).toBeNull();
  });
});
