import { populateWorkspacesWithProjectDetails } from 'ee/workspaces/common/services/utils';

describe('ee/workspaces/common/services/utils', () => {
  describe('populateWorkspacesWithProjectDetails', () => {
    describe('when the workspace references an existing project', () => {
      it('sets the projectName property to the project nameWithNamespace property', () => {
        const workspaces = [
          {
            projectId: 'foo',
          },
        ];
        const projects = [
          {
            id: 'foo',
            nameWithNamespace: 'Foo',
          },
        ];

        expect(populateWorkspacesWithProjectDetails(workspaces, projects)).toEqual([
          {
            projectId: 'foo',
            projectName: 'Foo',
          },
        ]);
      });
    });

    describe('when the workspace references a non existing project', () => {
      it('sets the projectName property to the project id', () => {
        const workspaces = [
          {
            projectId: 'bar',
          },
        ];
        const projects = [
          {
            id: 'foo',
            nameWithNamespace: 'Foo',
          },
        ];

        expect(populateWorkspacesWithProjectDetails(workspaces, projects)).toEqual([
          {
            projectId: 'bar',
            projectName: 'bar',
          },
        ]);
      });
    });
  });
});
