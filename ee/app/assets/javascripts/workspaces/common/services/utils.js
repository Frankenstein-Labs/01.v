import getProjectsDetailsQuery from '../graphql/queries/get_projects_details.query.graphql';

export const populateWorkspacesWithProjectDetails = (workspaces, projects) => {
  return workspaces.map((workspace) => {
    const project = projects.find((p) => p.id === workspace.projectId);

    return {
      ...workspace,
      projectName: project?.nameWithNamespace || workspace.projectId,
    };
  });
};

export const fetchProjectsDetails = async (apollo, workspaces) => {
  const projectIds = workspaces.map(({ projectId }) => projectId);

  try {
    const {
      data: { projects },
    } = await apollo.query({
      query: getProjectsDetailsQuery,
      variables: { ids: projectIds },
    });

    return {
      projects: projects.nodes,
    };
  } catch (error) {
    return { error };
  }
};
