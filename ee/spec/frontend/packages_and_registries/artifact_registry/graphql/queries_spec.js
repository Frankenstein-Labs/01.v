import { removeClientSetsFromDocument } from '@apollo/client/utilities';
import { visit } from 'graphql';
import getArtifactQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_artifact.query.graphql';
import getArtifactVersionsQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_artifact_versions.query.graphql';
import getRepositoriesQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repositories.query.graphql';
import getRepositoryQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository.query.graphql';
import getRepositoryDetailQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository_detail.query.graphql';
import getRepositoryImagesQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository_images.query.graphql';
import getRepositoryPackagesQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository_packages.query.graphql';

// A variable left declared but unused is rejected by the endpoint, and nothing before the
// request catches it: the source document does use the variable, so schema validation passes.
const unusedVariablesInServerDocument = (document) => {
  const serverDocument = removeClientSetsFromDocument(document);

  if (!serverDocument) return [];

  const referenced = new Set();

  visit(serverDocument, {
    VariableDefinition: () => false,
    Variable: ({ name }) => {
      referenced.add(name.value);
    },
  });

  return serverDocument.definitions
    .flatMap(({ variableDefinitions = [] }) => variableDefinitions)
    .map(({ variable }) => variable.name.value)
    .filter((name) => !referenced.has(name));
};

const variableNames = (document) =>
  document.definitions
    .flatMap(({ variableDefinitions = [] }) => variableDefinitions)
    .map(({ variable }) => variable.name.value);

// The top-level field names a repository selection carries, without descending into it.
const repositoryFields = (document) => {
  const fields = [];

  if (!document) return fields;

  visit(document, {
    Field: ({ name, selectionSet }) => {
      if (name.value !== 'artifactRegistryRepository') return undefined;

      fields.push(...selectionSet.selections.map((selection) => selection.name.value));

      return false;
    },
  });

  return fields;
};

describe('Artifact registry query documents', () => {
  describe.each([
    ['getArtifactRegistryArtifactVersions', getArtifactVersionsQuery],
    ['getArtifactRegistryRepositories', getRepositoriesQuery],
    ['getArtifactRegistryRepository', getRepositoryQuery],
    ['getArtifactRegistryRepositoryArtifact', getArtifactQuery],
    ['getArtifactRegistryRepositoryDetail', getRepositoryDetailQuery],
    ['getArtifactRegistryRepositoryImages', getRepositoryImagesQuery],
    ['getArtifactRegistryRepositoryPackages', getRepositoryPackagesQuery],
  ])('%s, with its client fields stripped as Apollo strips them', (_name, document) => {
    it('leaves behind no variable the server rejects as declared but not used', () => {
      expect(unusedVariablesInServerDocument(document)).toEqual([]);
    });
  });

  describe('getArtifactRegistryRepositoryDetail', () => {
    const serverFields = () =>
      repositoryFields(removeClientSetsFromDocument(getRepositoryDetailQuery));

    it('sends every server-backed field, so the read is the schema’s answer', () => {
      expect(serverFields()).toEqual([
        'name',
        'format',
        'kind',
        'visibility',
        'description',
        'downloadsCount',
        'sizeBytes',
        'lastUpdatedAt',
      ]);
    });

    it('keeps back exactly the fields with no server backing', () => {
      const sent = serverFields();

      expect(
        repositoryFields(getRepositoryDetailQuery).filter((field) => !sent.includes(field)),
      ).toEqual(['artifactsCount', 'createdAt', 'createdBy', 'updatedBy']);
    });
  });

  describe.each([
    ['getArtifactRegistryRepositoryImages', getRepositoryImagesQuery, 'images'],
    ['getArtifactRegistryRepositoryPackages', getRepositoryPackagesQuery, 'packages'],
  ])('%s', (_name, document, connection) => {
    it('asks the server for the repository identity and the format the connection turns on', () => {
      expect(repositoryFields(removeClientSetsFromDocument(document))).toEqual(['name', 'format']);
    });

    it('keeps back the artifact connection alone', () => {
      expect(repositoryFields(document)).toEqual(['name', 'format', connection]);
    });

    it('declares the identity variables alone, so no paging argument reaches the server', () => {
      expect(variableNames(removeClientSetsFromDocument(document))).toEqual([
        'organizationId',
        'name',
      ]);
    });
  });

  describe('getArtifactRegistryRepositoryArtifact', () => {
    it('asks the server for the repository identity and the format the artifact shape follows', () => {
      expect(repositoryFields(removeClientSetsFromDocument(getArtifactQuery))).toEqual([
        'name',
        'format',
      ]);
    });

    it('keeps back the two single-artifact fields alone', () => {
      expect(repositoryFields(getArtifactQuery)).toEqual(['name', 'format', 'image', 'package']);
    });

    it('declares the identity variables alone, so no artifact id is left declared', () => {
      expect(variableNames(removeClientSetsFromDocument(getArtifactQuery))).toEqual([
        'organizationId',
        'name',
      ]);
    });
  });

  describe('getArtifactRegistryArtifactVersions', () => {
    it('asks the server for the repository identity and the format the artifact shape follows', () => {
      expect(repositoryFields(removeClientSetsFromDocument(getArtifactVersionsQuery))).toEqual([
        'name',
        'format',
      ]);
    });

    it('keeps back the artifact the versions hang off alone', () => {
      expect(repositoryFields(getArtifactVersionsQuery)).toEqual(['name', 'format', 'package']);
    });

    it('declares the identity variables alone, so no artifact id is left declared', () => {
      expect(variableNames(removeClientSetsFromDocument(getArtifactVersionsQuery))).toEqual([
        'organizationId',
        'name',
      ]);
    });
  });

  describe('getArtifactRegistryRepositoryByName', () => {
    it('asks the server for every field the form prefills from', () => {
      expect(repositoryFields(removeClientSetsFromDocument(getRepositoryQuery))).toEqual([
        'name',
        'format',
        'kind',
        'visibility',
        'description',
      ]);
    });
  });
});
