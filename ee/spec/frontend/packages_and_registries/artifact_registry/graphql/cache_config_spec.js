import { InMemoryCache } from '@apollo/client/core';
import {
  possibleTypes,
  typePolicies,
} from 'ee/packages_and_registries/artifact_registry/graphql/cache_config';
import getRepositoryImagesQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository_images.query.graphql';
import {
  FIRST_PAGE_END_CURSOR,
  ORGANIZATION_GID,
  mockFirstImagePage,
  mockSecondImagePage,
  mockUntouchedRepository,
} from '../mock_data';

describe('Artifact registry cache config', () => {
  describe('the artifact connection policies', () => {
    let cache;

    // A container repository, because `images` is the connection a container format reads.
    const { name, format } = mockUntouchedRepository;

    const variablesFor = (after) => ({
      organizationId: ORGANIZATION_GID,
      name,
      first: 20,
      after,
    });

    const dataFor = (images) => ({
      organization: {
        __typename: 'Organization',
        id: ORGANIZATION_GID,
        artifactRegistryRepository: {
          __typename: 'ArtifactRegistryRepository',
          name,
          format,
          images,
        },
      },
    });

    const writePage = (images, after) =>
      cache.writeQuery({
        query: getRepositoryImagesQuery,
        variables: variablesFor(after),
        data: dataFor(images),
      });

    const readPage = (after) =>
      cache.readQuery({ query: getRepositoryImagesQuery, variables: variablesFor(after) })
        .organization.artifactRegistryRepository.images;

    beforeEach(() => {
      cache = new InMemoryCache({ possibleTypes, typePolicies });
    });

    beforeEach(() => {
      writePage(mockFirstImagePage);
      writePage(mockSecondImagePage, FIRST_PAGE_END_CURSOR);
    });

    it('holds every cursor under one entry the incoming page replaces', () => {
      expect(readPage().nodes).toEqual(mockSecondImagePage.nodes);
    });

    it('replaces the page info with it, so the pager follows the rows', () => {
      expect(readPage().pageInfo).toEqual(mockSecondImagePage.pageInfo);
    });
  });
});
