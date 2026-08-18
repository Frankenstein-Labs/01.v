import {
  createFramework,
  updateFramework,
  deleteFramework,
  createRequirementAtIndex,
  createRequirements,
  updateRequirement,
  deleteRequirement,
  submitNewFramework,
  submitFromTemplate,
  updateRequirementCacheOnCreate,
  updateRequirementCacheOnUpdate,
  updateRequirementCacheOnDelete,
} from 'ee/compliance_dashboard/components/frameworks_report/framework_form_helpers';
import getComplianceFrameworkQuery from 'ee/compliance_dashboard/components/frameworks_report/wizard/graphql/get_compliance_framework.query.graphql';
import createComplianceFrameworkMutation from 'ee/compliance_dashboard/graphql/mutations/create_compliance_framework.mutation.graphql';
import updateComplianceFrameworkMutation from 'ee/compliance_dashboard/graphql/mutations/update_compliance_framework.mutation.graphql';
import deleteComplianceFrameworkMutation from 'ee/compliance_dashboard/graphql/mutations/delete_compliance_framework.mutation.graphql';
import createRequirementMutation from 'ee/compliance_dashboard/graphql/mutations/create_compliance_requirement.mutation.graphql';
import updateRequirementMutation from 'ee/compliance_dashboard/graphql/mutations/update_compliance_requirement.mutation.graphql';
import deleteRequirementMutation from 'ee/compliance_dashboard/graphql/mutations/delete_compliance_requirement.mutation.graphql';
import createComplianceFrameworkFromTemplateMutation from 'ee/compliance_dashboard/components/frameworks_report/wizard/graphql/create_compliance_framework_from_template.mutation.graphql';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

describe('framework_form_helpers', () => {
  const groupPath = 'group-1';
  const graphqlId = 'gid://gitlab/ComplianceManagement::Framework/1';
  const queryVariables = { fullPath: groupPath, complianceFramework: graphqlId };

  let apollo;
  const mockMutate = (response) => {
    apollo = { mutate: jest.fn().mockResolvedValue({ data: response }) };
  };

  describe('createFramework', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('returns the new framework id on success', async () => {
      mockMutate({
        createComplianceFramework: {
          framework: { id: graphqlId },
          errors: [],
        },
      });

      const result = await createFramework(apollo, { groupPath, params: { name: 'A' } });

      expect(result).toBe(graphqlId);
      expect(apollo.mutate).toHaveBeenCalledWith({
        mutation: createComplianceFrameworkMutation,
        variables: { input: { namespacePath: groupPath, params: { name: 'A' } } },
      });
    });

    it('fires the create_compliance_framework internal event with the framework id', async () => {
      mockMutate({
        createComplianceFramework: {
          framework: { id: graphqlId },
          errors: [],
        },
      });
      const { trackEventSpy } = bindInternalEventDocument(document.body);

      await createFramework(apollo, { groupPath, params: { name: 'A' } });

      expect(trackEventSpy).toHaveBeenCalledWith('create_compliance_framework', {
        property: graphqlId,
      });
    });

    it('throws server-side errors', async () => {
      mockMutate({
        createComplianceFramework: {
          framework: null,
          errors: ['Name has already been taken'],
        },
      });

      await expect(createFramework(apollo, { groupPath, params: {} })).rejects.toEqual([
        'Name has already been taken',
      ]);
    });
  });

  describe('updateFramework', () => {
    it('issues the update mutation with the right input', async () => {
      mockMutate({ updateComplianceFramework: { errors: [] } });

      await updateFramework(apollo, { graphqlId, params: { name: 'B' } });

      expect(apollo.mutate).toHaveBeenCalledWith({
        mutation: updateComplianceFrameworkMutation,
        variables: { input: { id: graphqlId, params: { name: 'B' } } },
      });
    });

    it('throws server-side errors', async () => {
      mockMutate({ updateComplianceFramework: { errors: ['boom'] } });

      await expect(updateFramework(apollo, { graphqlId, params: {} })).rejects.toEqual(['boom']);
    });
  });

  describe('deleteFramework', () => {
    it('issues the delete mutation', async () => {
      mockMutate({ destroyComplianceFramework: { errors: [] } });

      await deleteFramework(apollo, { graphqlId });

      expect(apollo.mutate).toHaveBeenCalledWith({
        mutation: deleteComplianceFrameworkMutation,
        variables: { input: { id: graphqlId } },
      });
    });

    it('forwards refetchConfig to apollo.mutate', async () => {
      mockMutate({ destroyComplianceFramework: { errors: [] } });
      const refetchConfig = { awaitRefetchQueries: true, refetchQueries: [] };

      await deleteFramework(apollo, { graphqlId, refetchConfig });

      expect(apollo.mutate).toHaveBeenCalledWith(expect.objectContaining(refetchConfig));
    });

    it('throws when destroyComplianceFramework returns an error', async () => {
      mockMutate({ destroyComplianceFramework: { errors: ['nope'] } });

      await expect(deleteFramework(apollo, { graphqlId })).rejects.toBe('nope');
    });
  });

  describe('createRequirementAtIndex', () => {
    const requirement = {
      name: 'r1',
      description: 'd1',
      stagedControls: [{ name: 'c1', controlType: 'internal', expression: 'expr' }],
    };

    it('issues the createRequirement mutation with mapped controls', async () => {
      mockMutate({ createComplianceRequirement: { errors: [] } });

      await createRequirementAtIndex(apollo, {
        frameworkId: graphqlId,
        requirement,
        isNewFramework: true,
      });

      expect(apollo.mutate).toHaveBeenCalledWith(
        expect.objectContaining({
          mutation: createRequirementMutation,
          variables: {
            input: {
              complianceFrameworkId: graphqlId,
              params: { name: 'r1', description: 'd1' },
              controls: [
                {
                  name: 'c1',
                  controlType: 'internal',
                  externalControlName: '',
                  externalUrl: '',
                  expression: 'expr',
                },
              ],
            },
          },
        }),
      );
    });

    it('omits the update callback when isNewFramework is true', async () => {
      mockMutate({ createComplianceRequirement: { errors: [] } });

      await createRequirementAtIndex(apollo, {
        frameworkId: graphqlId,
        requirement,
        isNewFramework: true,
      });

      expect(apollo.mutate.mock.calls[0][0].update).toBeUndefined();
    });

    it('passes an update callback when isNewFramework is false', async () => {
      mockMutate({ createComplianceRequirement: { errors: [] } });

      await createRequirementAtIndex(apollo, {
        frameworkId: graphqlId,
        requirement,
        isNewFramework: false,
        queryVariables,
        graphqlId,
      });

      expect(apollo.mutate.mock.calls[0][0].update).toEqual(expect.any(Function));
    });

    it('throws when the mutation returns errors', async () => {
      mockMutate({ createComplianceRequirement: { errors: ['rejected'] } });

      await expect(
        createRequirementAtIndex(apollo, {
          frameworkId: graphqlId,
          requirement,
          isNewFramework: true,
        }),
      ).rejects.toEqual(new Error('rejected'));
    });

    it('falls back to complianceRequirementsControls.nodes when stagedControls is missing', async () => {
      mockMutate({ createComplianceRequirement: { errors: [] } });
      const requirementWithControlsNodes = {
        name: 'r2',
        description: 'd2',
        complianceRequirementsControls: {
          nodes: [{ name: 'c2' }],
        },
      };

      await createRequirementAtIndex(apollo, {
        frameworkId: graphqlId,
        requirement: requirementWithControlsNodes,
        isNewFramework: true,
      });

      expect(apollo.mutate.mock.calls[0][0].variables.input.controls[0].name).toBe('c2');
    });
  });

  describe('createRequirements', () => {
    it('skips requirements that already have an id', async () => {
      mockMutate({ createComplianceRequirement: { errors: [] } });

      await createRequirements(apollo, {
        frameworkId: graphqlId,
        requirements: [{ id: 'gid://1', name: 'existing' }, { name: 'new' }],
      });

      expect(apollo.mutate).toHaveBeenCalledTimes(1);
      expect(apollo.mutate.mock.calls[0][0].variables.input.params.name).toBe('new');
    });

    it('does not call apollo.mutate when there is nothing to create', async () => {
      apollo = { mutate: jest.fn() };

      await createRequirements(apollo, {
        frameworkId: graphqlId,
        requirements: [{ id: 'gid://1', name: 'existing' }],
      });

      expect(apollo.mutate).not.toHaveBeenCalled();
    });

    it('issues all create mutations in parallel', async () => {
      mockMutate({ createComplianceRequirement: { errors: [] } });

      await createRequirements(apollo, {
        frameworkId: graphqlId,
        requirements: [{ name: 'a' }, { name: 'b' }, { name: 'c' }],
      });

      expect(apollo.mutate).toHaveBeenCalledTimes(3);
    });
  });

  describe('updateRequirement', () => {
    it('issues the update mutation with mapped controls and a cache update', async () => {
      mockMutate({ updateComplianceRequirement: { errors: [] } });

      await updateRequirement(apollo, {
        requirement: { id: 'req-1', name: 'n', description: 'd', stagedControls: [{ name: 'c' }] },
        queryVariables,
        graphqlId,
      });

      const call = apollo.mutate.mock.calls[0][0];
      expect(call.mutation).toBe(updateRequirementMutation);
      expect(call.update).toEqual(expect.any(Function));
    });

    it('throws when the mutation returns errors', async () => {
      mockMutate({ updateComplianceRequirement: { errors: ['nope'] } });

      await expect(
        updateRequirement(apollo, {
          requirement: { id: 'req-1', name: 'n', description: 'd' },
          queryVariables,
          graphqlId,
        }),
      ).rejects.toEqual(new Error('nope'));
    });
  });

  describe('deleteRequirement', () => {
    it('issues the delete mutation with a cache update', async () => {
      mockMutate({ destroyComplianceRequirement: { errors: [] } });

      await deleteRequirement(apollo, { requirementId: 'req-1', queryVariables, graphqlId });

      const call = apollo.mutate.mock.calls[0][0];
      expect(call.mutation).toBe(deleteRequirementMutation);
      expect(call.variables).toEqual({ input: { id: 'req-1' } });
      expect(call.update).toEqual(expect.any(Function));
    });

    it('throws when the mutation returns errors', async () => {
      mockMutate({ destroyComplianceRequirement: { errors: ['nope'] } });

      await expect(
        deleteRequirement(apollo, { requirementId: 'req-1', queryVariables, graphqlId }),
      ).rejects.toEqual(new Error('nope'));
    });
  });

  describe('submitNewFramework', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('creates the framework and then creates requirements, returning the framework id', async () => {
      apollo = {
        mutate: jest
          .fn()
          .mockResolvedValueOnce({
            data: {
              createComplianceFramework: { framework: { id: graphqlId }, errors: [] },
            },
          })
          .mockResolvedValueOnce({
            data: { createComplianceRequirement: { errors: [] } },
          }),
      };
      bindInternalEventDocument(document.body);

      const result = await submitNewFramework(apollo, {
        groupPath,
        params: { name: 'A' },
        requirements: [{ name: 'r' }],
      });

      expect(result).toBe(graphqlId);
      expect(apollo.mutate).toHaveBeenCalledTimes(2);
      expect(apollo.mutate.mock.calls[0][0].mutation).toBe(createComplianceFrameworkMutation);
      expect(apollo.mutate.mock.calls[1][0].mutation).toBe(createRequirementMutation);
    });

    it('skips requirement creation when there are no new requirements', async () => {
      mockMutate({
        createComplianceFramework: { framework: { id: graphqlId }, errors: [] },
      });

      const result = await submitNewFramework(apollo, {
        groupPath,
        params: {},
        requirements: [],
      });

      expect(result).toBe(graphqlId);
      expect(apollo.mutate).toHaveBeenCalledTimes(1);
    });
  });

  describe('updateRequirementCacheOnCreate', () => {
    let cache;
    const buildSourceData = (existingRequirements) => ({
      namespace: {
        complianceFrameworks: {
          nodes: [
            {
              id: graphqlId,
              complianceRequirements: { nodes: existingRequirements },
            },
          ],
        },
      },
    });

    beforeEach(() => {
      cache = {
        readQuery: jest.fn().mockReturnValue(buildSourceData([{ id: 'a' }, { id: 'b' }])),
        writeQuery: jest.fn(),
      };
    });

    it('appends the new requirement when index is not provided', () => {
      const result = {
        data: { createComplianceRequirement: { requirement: { id: 'c' }, errors: [] } },
      };

      updateRequirementCacheOnCreate(cache, result, { queryVariables, graphqlId });

      const written = cache.writeQuery.mock.calls[0][0].data;
      expect(written.namespace.complianceFrameworks.nodes[0].complianceRequirements.nodes).toEqual([
        { id: 'a' },
        { id: 'b' },
        { id: 'c' },
      ]);
    });

    it('splices the new requirement at the given index', () => {
      const result = {
        data: { createComplianceRequirement: { requirement: { id: 'c' }, errors: [] } },
      };

      updateRequirementCacheOnCreate(cache, result, { queryVariables, graphqlId, index: 1 });

      const written = cache.writeQuery.mock.calls[0][0].data;
      expect(written.namespace.complianceFrameworks.nodes[0].complianceRequirements.nodes).toEqual([
        { id: 'a' },
        { id: 'c' },
        { id: 'b' },
      ]);
    });

    it('skips writing when the mutation reported errors', () => {
      const result = {
        data: { createComplianceRequirement: { requirement: null, errors: ['nope'] } },
      };

      updateRequirementCacheOnCreate(cache, result, { queryVariables, graphqlId });

      expect(cache.writeQuery).not.toHaveBeenCalled();
    });

    it('reads the framework cache via the right query and variables', () => {
      const result = {
        data: { createComplianceRequirement: { requirement: { id: 'c' }, errors: [] } },
      };

      updateRequirementCacheOnCreate(cache, result, { queryVariables, graphqlId });

      expect(cache.readQuery).toHaveBeenCalledWith({
        query: getComplianceFrameworkQuery,
        variables: queryVariables,
      });
    });
  });

  describe('updateRequirementCacheOnUpdate', () => {
    let cache;

    beforeEach(() => {
      cache = {
        readQuery: jest.fn().mockReturnValue({
          namespace: {
            complianceFrameworks: {
              nodes: [
                {
                  id: graphqlId,
                  complianceRequirements: {
                    nodes: [
                      { id: 'a', name: 'old-a' },
                      { id: 'b', name: 'old-b' },
                    ],
                  },
                },
              ],
            },
          },
        }),
        writeQuery: jest.fn(),
      };
    });

    it('replaces the existing requirement at the matching index', () => {
      const result = {
        data: {
          updateComplianceRequirement: {
            requirement: { id: 'b', name: 'new-b' },
            errors: [],
          },
        },
      };

      updateRequirementCacheOnUpdate(cache, result, { queryVariables, graphqlId });

      const written = cache.writeQuery.mock.calls[0][0].data;
      expect(written.namespace.complianceFrameworks.nodes[0].complianceRequirements.nodes).toEqual([
        { id: 'a', name: 'old-a' },
        { id: 'b', name: 'new-b' },
      ]);
    });

    it('skips writing when the mutation reported errors', () => {
      const result = {
        data: {
          updateComplianceRequirement: { requirement: null, errors: ['nope'] },
        },
      };

      updateRequirementCacheOnUpdate(cache, result, { queryVariables, graphqlId });

      expect(cache.writeQuery).not.toHaveBeenCalled();
    });
  });

  describe('updateRequirementCacheOnDelete', () => {
    let cache;

    beforeEach(() => {
      cache = {
        readQuery: jest.fn().mockReturnValue({
          namespace: {
            complianceFrameworks: {
              nodes: [
                {
                  id: graphqlId,
                  complianceRequirements: {
                    nodes: [{ id: 'a' }, { id: 'b' }, { id: 'c' }],
                  },
                },
              ],
            },
          },
        }),
        writeQuery: jest.fn(),
      };
    });

    it('removes the requirement with the matching id', () => {
      const result = { data: { destroyComplianceRequirement: { errors: [] } } };

      updateRequirementCacheOnDelete(cache, result, {
        queryVariables,
        graphqlId,
        requirementId: 'b',
      });

      const written = cache.writeQuery.mock.calls[0][0].data;
      expect(written.namespace.complianceFrameworks.nodes[0].complianceRequirements.nodes).toEqual([
        { id: 'a' },
        { id: 'c' },
      ]);
    });

    it('skips writing when the mutation reported errors', () => {
      const result = { data: { destroyComplianceRequirement: { errors: ['nope'] } } };

      updateRequirementCacheOnDelete(cache, result, {
        queryVariables,
        graphqlId,
        requirementId: 'b',
      });

      expect(cache.writeQuery).not.toHaveBeenCalled();
    });
  });

  describe('submitFromTemplate', () => {
    const templateId =
      'gid://gitlab/ComplianceManagement::Frameworks::TemplateRegistry::Template/gdpr';
    const overrides = { name: 'Custom GDPR', description: 'd', color: '#fff', default: false };
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    const successResponse = {
      createComplianceFrameworkFromTemplate: {
        framework: { id: graphqlId, name: 'Custom GDPR' },
        errors: [],
      },
    };

    it('issues the createFromTemplate mutation with overrides and returns the framework id', async () => {
      mockMutate(successResponse);

      const result = await submitFromTemplate(apollo, {
        groupPath,
        templateId,
        overrides,
      });

      expect(result).toBe(graphqlId);
      expect(apollo.mutate).toHaveBeenCalledWith({
        mutation: createComplianceFrameworkFromTemplateMutation,
        variables: {
          input: { namespacePath: groupPath, templateId, ...overrides },
        },
      });
    });

    it('fires the create_compliance_framework_from_template internal event', async () => {
      mockMutate(successResponse);
      const { trackEventSpy } = bindInternalEventDocument(document.body);

      await submitFromTemplate(apollo, { groupPath, templateId, overrides });

      expect(trackEventSpy).toHaveBeenCalledWith('create_compliance_framework_from_template', {
        property: graphqlId,
      });
    });

    it('issues an update mutation when projects to add are provided', async () => {
      apollo = {
        mutate: jest
          .fn()
          .mockResolvedValueOnce({ data: successResponse })
          .mockResolvedValueOnce({ data: { updateComplianceFramework: { errors: [] } } }),
      };

      await submitFromTemplate(apollo, {
        groupPath,
        templateId,
        overrides,
        projects: { addProjects: [1], removeProjects: [] },
      });

      expect(apollo.mutate).toHaveBeenCalledTimes(2);
      expect(apollo.mutate).toHaveBeenLastCalledWith({
        mutation: updateComplianceFrameworkMutation,
        variables: {
          input: {
            id: graphqlId,
            params: { projects: { addProjects: [1], removeProjects: [] } },
          },
        },
      });
    });

    it('skips the update mutation when no project changes are provided', async () => {
      mockMutate(successResponse);

      await submitFromTemplate(apollo, { groupPath, templateId, overrides });

      expect(apollo.mutate).toHaveBeenCalledTimes(1);
    });

    it('throws server-side errors from the mutation', async () => {
      mockMutate({
        createComplianceFrameworkFromTemplate: { framework: null, errors: ['nope'] },
      });

      await expect(
        submitFromTemplate(apollo, { groupPath, templateId, overrides }),
      ).rejects.toEqual(['nope']);
    });
  });
});
