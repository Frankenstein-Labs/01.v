export const containerImagePath = {
  ancestors: null,
  topLevel: null,
  blobPath: 'test.link',
  path: 'container-image:nginx:1.17',
  image: 'nginx:1.17',
};

export const withoutPath = {
  ancestors: null,
  topLevel: null,
  blobPath: 'test.link',
  path: null,
};

export const withoutFilePath = {
  ancestors: null,
  topLevel: null,
  blobPath: null,
  path: 'package.json',
};

export const noPath = {
  ancestors: [],
  topLevel: false,
  blobPath: 'test.link',
  path: 'package.json',
};

export const topLevelPath = {
  ancestors: [],
  topLevel: true,
  blobPath: 'test.link',
  path: 'package.json',
};

export const defaultDependencyPaths = {
  nodes: [
    {
      id: 1,
      isCyclic: false,
      path: [
        { name: 'eslint', version: '9.17.0', __typename: 'DependencyPathPartial' },
        { name: 'optionator', version: '0.9.3', __typename: 'DependencyPathPartial' },
      ],
      __typename: 'DependencyPath',
    },
  ],
  pageInfo: {
    hasNextPage: false,
    hasPreviousPage: false,
    startCursor: null,
    endCursor: null,
  },
};

export const getDependencyPathsResponse = (dependencyPaths = defaultDependencyPaths) => ({
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      dependencyPaths,
      __typename: 'Project',
    },
  },
});
