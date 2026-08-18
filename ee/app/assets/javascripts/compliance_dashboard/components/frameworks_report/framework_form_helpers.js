import produce from 'immer';
import InternalEvents from '~/tracking/internal_events';
import createComplianceFrameworkMutation from '../../graphql/mutations/create_compliance_framework.mutation.graphql';
import updateComplianceFrameworkMutation from '../../graphql/mutations/update_compliance_framework.mutation.graphql';
import deleteComplianceFrameworkMutation from '../../graphql/mutations/delete_compliance_framework.mutation.graphql';
import createRequirementMutation from '../../graphql/mutations/create_compliance_requirement.mutation.graphql';
import updateRequirementMutation from '../../graphql/mutations/update_compliance_requirement.mutation.graphql';
import deleteRequirementMutation from '../../graphql/mutations/delete_compliance_requirement.mutation.graphql';
import getComplianceFrameworkQuery from './wizard/graphql/get_compliance_framework.query.graphql';
import createComplianceFrameworkFromTemplateMutation from './wizard/graphql/create_compliance_framework_from_template.mutation.graphql';

const buildControlPayload = (control) => ({
  name: control.name,
  controlType: control.controlType || 'internal',
  externalControlName: control.externalControlName || '',
  externalUrl: control.externalUrl || '',
  expression: control.expression || '',
  ...(control.secretToken && { secretToken: control.secretToken }),
  ...(control.pingEnabled !== undefined && { pingEnabled: control.pingEnabled }),
});

const findFrameworkInDraft = (draft, graphqlId) =>
  draft.namespace.complianceFrameworks.nodes.find((f) => f.id === graphqlId);

export const updateRequirementCacheOnCreate = (
  cache,
  { data: { createComplianceRequirement } },
  { queryVariables, graphqlId, index = null },
) => {
  const newRequirement = createComplianceRequirement?.requirement;
  const errors = createComplianceRequirement?.errors;

  if (errors && errors.length) {
    return;
  }

  const sourceData = cache.readQuery({
    query: getComplianceFrameworkQuery,
    variables: queryVariables,
  });

  const updatedData = produce(sourceData, (draft) => {
    const framework = findFrameworkInDraft(draft, graphqlId);
    if (framework) {
      if (index !== null) {
        framework.complianceRequirements.nodes.splice(index, 0, newRequirement);
      } else {
        framework.complianceRequirements.nodes.push(newRequirement);
      }
    }
  });

  cache.writeQuery({
    query: getComplianceFrameworkQuery,
    variables: queryVariables,
    data: updatedData,
  });
};

export const updateRequirementCacheOnUpdate = (
  cache,
  { data: { updateComplianceRequirement } },
  { queryVariables, graphqlId },
) => {
  const updatedRequirement = updateComplianceRequirement?.requirement;
  const errors = updateComplianceRequirement?.errors;

  if (errors && errors.length) {
    return;
  }

  const sourceData = cache.readQuery({
    query: getComplianceFrameworkQuery,
    variables: queryVariables,
  });

  const updatedData = produce(sourceData, (draft) => {
    const framework = findFrameworkInDraft(draft, graphqlId);
    if (framework) {
      const index = framework.complianceRequirements.nodes.findIndex(
        (req) => req.id === updatedRequirement.id,
      );
      if (index !== -1) {
        framework.complianceRequirements.nodes[index] = updatedRequirement;
      }
    }
  });

  cache.writeQuery({
    query: getComplianceFrameworkQuery,
    variables: queryVariables,
    data: updatedData,
  });
};

export const updateRequirementCacheOnDelete = (
  cache,
  { data: { destroyComplianceRequirement } },
  { queryVariables, graphqlId, requirementId },
) => {
  const errors = destroyComplianceRequirement?.errors;
  if (errors && errors.length) {
    return;
  }

  const sourceData = cache.readQuery({
    query: getComplianceFrameworkQuery,
    variables: queryVariables,
  });

  const updatedData = produce(sourceData, (draft) => {
    const framework = findFrameworkInDraft(draft, graphqlId);
    if (framework) {
      framework.complianceRequirements.nodes = framework.complianceRequirements.nodes.filter(
        (req) => req.id !== requirementId,
      );
    }
  });

  cache.writeQuery({
    query: getComplianceFrameworkQuery,
    variables: queryVariables,
    data: updatedData,
  });
};

export const createFramework = async (apollo, { groupPath, params }) => {
  const { data } = await apollo.mutate({
    mutation: createComplianceFrameworkMutation,
    variables: {
      input: {
        namespacePath: groupPath,
        params,
      },
    },
  });

  const framework = data?.createComplianceFramework?.framework;
  const errors = data?.createComplianceFramework?.errors;

  if (errors && errors.length) {
    throw errors;
  }

  InternalEvents.trackEvent('create_compliance_framework', { property: framework.id });

  return framework.id;
};

export const updateFramework = async (apollo, { graphqlId, params }) => {
  const { data } = await apollo.mutate({
    mutation: updateComplianceFrameworkMutation,
    variables: {
      input: {
        id: graphqlId,
        params,
      },
    },
  });

  const errors = data?.updateComplianceFramework?.errors;

  if (errors && errors.length) {
    throw errors;
  }
};

export const deleteFramework = async (apollo, { graphqlId, refetchConfig = {} }) => {
  const {
    data: { destroyComplianceFramework },
  } = await apollo.mutate({
    mutation: deleteComplianceFrameworkMutation,
    variables: {
      input: {
        id: graphqlId,
      },
    },
    ...refetchConfig,
  });

  const [error] = destroyComplianceFramework.errors;

  if (error) {
    throw error;
  }
};

export const createRequirementAtIndex = async (
  apollo,
  { frameworkId, requirement, index = null, isNewFramework = false, queryVariables, graphqlId },
) => {
  const controls = (
    requirement.stagedControls ||
    requirement.complianceRequirementsControls?.nodes ||
    []
  ).map(buildControlPayload);

  const { data } = await apollo.mutate({
    mutation: createRequirementMutation,
    variables: {
      input: {
        complianceFrameworkId: frameworkId,
        params: {
          name: requirement.name,
          description: requirement.description,
        },
        controls,
      },
    },
    ...(isNewFramework
      ? {}
      : {
          update: (cache, result) =>
            updateRequirementCacheOnCreate(cache, result, { queryVariables, graphqlId, index }),
        }),
  });

  const errors = data?.createComplianceRequirement?.errors;

  if (errors && errors.length) {
    throw new Error(errors[0]);
  }
};

export const createRequirements = async (apollo, { frameworkId, requirements }) => {
  const newRequirements = requirements.filter((requirement) => !requirement.id);

  if (newRequirements.length === 0) {
    return;
  }

  const createRequirementPromises = newRequirements.map((requirement) =>
    createRequirementAtIndex(apollo, { frameworkId, requirement, isNewFramework: true }),
  );

  await Promise.all(createRequirementPromises);
};

export const updateRequirement = async (apollo, { requirement, queryVariables, graphqlId }) => {
  const controls = (requirement.stagedControls || []).map(buildControlPayload);

  const { data } = await apollo.mutate({
    mutation: updateRequirementMutation,
    variables: {
      input: {
        id: requirement.id,
        params: {
          name: requirement.name,
          description: requirement.description,
        },
        controls,
      },
    },
    update: (cache, result) =>
      updateRequirementCacheOnUpdate(cache, result, { queryVariables, graphqlId }),
  });

  const errors = data?.updateComplianceRequirement?.errors;

  if (errors && errors.length) {
    throw new Error(errors[0]);
  }
};

export const deleteRequirement = async (apollo, { requirementId, queryVariables, graphqlId }) => {
  const { data } = await apollo.mutate({
    mutation: deleteRequirementMutation,
    variables: {
      input: {
        id: requirementId,
      },
    },
    update: (cache, result) =>
      updateRequirementCacheOnDelete(cache, result, { queryVariables, graphqlId, requirementId }),
  });

  const errors = data?.destroyComplianceRequirement?.errors;
  if (errors && errors.length) {
    throw new Error(errors[0]);
  }
};

export const submitNewFramework = async (apollo, { groupPath, params, requirements }) => {
  const frameworkId = await createFramework(apollo, { groupPath, params });
  await createRequirements(apollo, { frameworkId, requirements });
  return frameworkId;
};

export const submitFromTemplate = async (
  apollo,
  { groupPath, templateId, overrides = {}, projects = null },
) => {
  const { data } = await apollo.mutate({
    mutation: createComplianceFrameworkFromTemplateMutation,
    variables: {
      input: {
        namespacePath: groupPath,
        templateId,
        ...overrides,
      },
    },
  });

  const framework = data?.createComplianceFrameworkFromTemplate?.framework;
  const errors = data?.createComplianceFrameworkFromTemplate?.errors;

  if (errors && errors.length) {
    throw errors;
  }

  InternalEvents.trackEvent('create_compliance_framework_from_template', {
    property: framework.id,
  });

  if (projects && (projects.addProjects?.length || projects.removeProjects?.length)) {
    await updateFramework(apollo, {
      graphqlId: framework.id,
      params: {
        projects: {
          addProjects: projects.addProjects || [],
          removeProjects: projects.removeProjects || [],
        },
      },
    });
  }

  return framework.id;
};
