import { SECRETS_MANAGER_PERMISSIONS_CONTEXT_CONFIG } from 'ee/pages/projects/shared/permissions/secrets_manager/context_config';
import { ENTITY_PROJECT, ENTITY_GROUP } from 'ee/ci/secrets/constants';

describe('SECRETS_MANAGER_PERMISSIONS_CONTEXT_CONFIG', () => {
  describe('searchMembers relations', () => {
    it('project context includes direct, inherited, and invited group members', () => {
      expect(
        SECRETS_MANAGER_PERMISSIONS_CONTEXT_CONFIG[ENTITY_PROJECT].searchMembers.relations,
      ).toEqual(['DIRECT', 'INHERITED', 'INVITED_GROUPS']);
    });

    it('group context includes direct, inherited, and shared group members', () => {
      expect(
        SECRETS_MANAGER_PERMISSIONS_CONTEXT_CONFIG[ENTITY_GROUP].searchMembers.relations,
      ).toEqual(['DIRECT', 'INHERITED', 'SHARED_FROM_GROUPS']);
    });
  });
});
