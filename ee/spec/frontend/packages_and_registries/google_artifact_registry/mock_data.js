export const headerData = {
  projectId: 'dev-package-container-96a3ff34',
  repository: 'myrepo',
  artifactRegistryRepositoryUrl:
    'https://console.cloud.google.com/artifacts/docker/dev-package-container-96a3ff34/us-east1/myrepo',
};

export const imageData = {
  name: 'projects/dev-package-container-96a3ff34/locations/us-east1/repositories/myrepo/dockerImages/alpine@sha256:6a0657acfef760bd9e293361c9b558e98e7d740ed0dffca823d17098a4ffddf5',
  image: 'alpine',
  digest: 'sha256:1234567890abcdef1234567890abcdef12345678',
  tags: ['latest', 'v1.0.0', 'v1.0.1'],
  uploadTime: '2019-01-01T00:00:00Z',
  updateTime: '2020-01-01T00:00:00Z',
  uri: 'us-east1-docker.pkg.dev/dev-package-container-96a3ff34/myrepo/alpine@sha256:6a0657acfef760bd9e293361c9b558e98e7d740ed0dffca823d17098a4ffddf5',
};

export const imageDetailsFields = {
  imageSizeBytes: 2827903,
  buildTime: '2023-12-07T11:48:47.598511Z',
  mediaType: 'application/vnd.docker.distribution.manifest.v2+json',
  projectId: 'dev-package-container-96a3ff34',
  location: 'us-east1',
  repository: 'myrepo',
  artifactRegistryImageUrl:
    'https://us-east1-docker.pkg.dev/dev-package-container-96a3ff34/myrepo/alpine@sha256:6a0657acfef760bd9e293361c9b558e98e7d740ed0dffca823d17098a4ffddf5',
};

export const pageInfo = {
  endCursor:
    'AHbNynEacusA9NuBnkImcu8MKm43rE5oPeSUI7BcKyVTfxEs5vKtEIVo8M_Rt2ofv85b7pTb7defAQ3QquZzt5MeNcEe2V5Pr-nL0ZYsozbEAF0jxnb8Zh9EYxxCn5mwo5MxrLoa1uLEkditOxPB6B_sGg6WtgsVjdUG7BQ30VgbEhYtyuEZpWyDps-CbkJUyppodEu6FuJIRGlVNpPvNOdeUxnfEQYVtRrPu6n76VF8xDJEXYH1MMoF4CsZ9AhdVnEQ9U88',
  startCursor: null,
  hasNextPage: true,
  hasPreviousPage: false,
};

export const getArtifactRepositoryQueryResponse = {
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/1',
      googleCloudArtifactRegistryRepository: {
        ...headerData,
        __typename: 'GoogleCloudArtifactRegistryRepository',
      },
    },
  },
};

export const getArtifactsQueryResponse = (override = {}) => ({
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/1',
      googleCloudArtifactRegistryRepository: {
        __typename: 'GoogleCloudArtifactRegistryRepository',
        projectId: headerData.projectId,
        artifacts: {
          nodes: [
            {
              ...imageData,
              __typename: 'GoogleCloudArtifactRegistryDockerImage',
            },
          ],
          pageInfo: {
            ...pageInfo,
            __typename: 'PageInfo',
          },
          ...override,
        },
      },
    },
  },
});

export const getArtifactDetailsQueryResponse = {
  data: {
    googleCloudArtifactRegistryRepositoryArtifact: {
      ...imageData,
      ...imageDetailsFields,
      __typename: 'GoogleCloudArtifactRegistryDockerImageDetails',
    },
  },
};
