import {
  getAccessLevels,
  getAccessLevelInputFromEdges,
  getAccessLevelsRolesAndEEText,
} from 'ee/projects/settings/utils';
import { accessLevelsMockResponse, accessLevelsMockResult } from './mock_data';

describe('EE Utils', () => {
  describe('getAccessLevels', () => {
    it('takes accessLevels response data and returns accessLevels object', () => {
      const mergeAccessLevels = getAccessLevels(accessLevelsMockResponse);
      expect(mergeAccessLevels).toEqual(accessLevelsMockResult);
    });
  });

  describe('getAccessLevelInputFromEdges', () => {
    it('returns an empty array when given an empty array', () => {
      const edges = [];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([]);
    });

    it('returns an array with accessLevel when node has accessLevel', () => {
      const edges = [{ node: { accessLevel: 30 } }];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ accessLevel: 30 }]);
    });

    it('returns an array with deployKeys when node has deployKeys', () => {
      const edges = [{ node: { deployKey: { id: 14 } } }];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ deployKeyId: 14 }]);
    });

    it('returns an array with groupId when node has group.id', () => {
      const edges = [{ node: { group: { id: 1 } } }];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ groupId: 1 }]);
    });

    it('returns an array with userId when node has user.id', () => {
      const edges = [{ node: { user: { id: 2 } } }];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ userId: 2 }]);
    });

    it('returns an array with groupId, and userId when node has all properties', () => {
      const edges = [
        {
          node: {
            accessLevel: 30,
            group: { id: 1 },
            user: { id: 2 },
          },
        },
      ];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ groupId: 1, userId: 2 }]);
    });

    it('returns an array with multiple objects when given multiple edges', () => {
      const edges = [
        { node: { accessLevel: 30, group: { id: 1 } } },
        { node: { user: { id: 2 } } },
        { node: { accessLevel: 40 } },
      ];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ groupId: 1 }, { userId: 2 }, { accessLevel: 40 }]);
    });

    it('returns an array with memberRoleId when node has memberRole.id', () => {
      const edges = [{ node: { memberRole: { id: 42 } } }];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ memberRoleId: 42 }]);
    });

    it('omits accessLevel when node has a memberRole (member_role checked before access_level)', () => {
      const edges = [{ node: { accessLevel: 30, memberRole: { id: 42 } } }];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ memberRoleId: 42 }]);
    });
  });

  describe('getAccessLevelsRolesAndEEText', () => {
    it('returns an empty array when no roles, groups, or users', () => {
      const result = getAccessLevelsRolesAndEEText({ roles: [], groups: [], users: [] });
      expect(result).toEqual([]);
    });

    it('returns roles text when only roles are present', () => {
      const result = getAccessLevelsRolesAndEEText({ roles: [40], groups: [], users: [] });
      expect(result).toEqual(['Maintainers']);
    });

    it('returns groups text when only groups are present', () => {
      const result = getAccessLevelsRolesAndEEText({ roles: [], groups: [{ id: '1' }], users: [] });
      expect(result).toEqual(['1 group']);
    });

    it('returns multiple groups text', () => {
      const result = getAccessLevelsRolesAndEEText({
        roles: [],
        groups: [{ id: '1' }, { id: '2' }],
        users: [],
      });
      expect(result).toEqual(['2 groups']);
    });

    it('returns users text when only users are present', () => {
      const result = getAccessLevelsRolesAndEEText({ roles: [], groups: [], users: [{ id: '1' }] });
      expect(result).toEqual(['1 user']);
    });

    it('returns multiple users text', () => {
      const result = getAccessLevelsRolesAndEEText({
        roles: [],
        groups: [],
        users: [{ id: '1' }, { id: '2' }],
      });
      expect(result).toEqual(['2 users']);
    });

    it('returns combined text for roles, groups, and users', () => {
      const result = getAccessLevelsRolesAndEEText({
        roles: [40],
        groups: [{ id: '1' }],
        users: [{ id: '2' }],
      });
      expect(result).toEqual(['Maintainers', '1 group', '1 user']);
    });

    it('returns custom role names when member roles are present', () => {
      const result = getAccessLevelsRolesAndEEText({
        roles: [],
        groups: [],
        users: [],
        memberRoles: [{ id: '1', name: 'Lead Developer' }],
      });
      expect(result).toEqual(['Lead Developer']);
    });

    it('returns combined text including custom role names', () => {
      const result = getAccessLevelsRolesAndEEText({
        roles: [40],
        groups: [{ id: '1' }],
        users: [{ id: '2' }],
        memberRoles: [{ id: '3', name: 'Lead Developer' }],
      });
      expect(result).toEqual(['Maintainers', 'Lead Developer', '1 group', '1 user']);
    });

    it('returns combined text for multiple of each type', () => {
      const result = getAccessLevelsRolesAndEEText({
        roles: [30, 40],
        groups: [{ id: '1' }, { id: '2' }],
        users: [{ id: '3' }, { id: '4' }],
      });
      expect(result).toEqual(['Developers and Maintainers, Maintainers', '2 groups', '2 users']);
    });
  });
});
