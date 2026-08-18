import { removeClientSetsFromDocument } from '@apollo/client/utilities';
import { print, visit } from 'graphql';
import createRepositoryMutation from 'ee/packages_and_registries/artifact_registry/graphql/mutations/create_repository.mutation.graphql';
import updateRepositoryMutation from 'ee/packages_and_registries/artifact_registry/graphql/mutations/update_repository.mutation.graphql';
import deleteRepositoryMutation from 'ee/packages_and_registries/artifact_registry/graphql/mutations/delete_repository.mutation.graphql';

// What Apollo would actually send; a document stripped to nothing never leaves the browser.
const serverDocumentOf = (document) => {
  const serverDocument = removeClientSetsFromDocument(document);

  return serverDocument ? print(serverDocument) : '';
};

const inputTypeOf = (document) => {
  let typeName = null;

  visit(document, {
    VariableDefinition: ({ variable, type }) => {
      if (variable.name.value === 'input') typeName = print(type);
    },
  });

  return typeName;
};

describe('Artifact registry mutation documents', () => {
  describe.each([
    [
      'createArtifactRegistryRepository',
      createRepositoryMutation,
      'ArtifactRegistryRepositoryCreateInput!',
    ],
    [
      'updateArtifactRegistryRepository',
      updateRepositoryMutation,
      'ArtifactRegistryRepositoryUpdateInput!',
    ],
    [
      'deleteArtifactRegistryRepository',
      deleteRepositoryMutation,
      'ArtifactRegistryRepositoryDeleteInput!',
    ],
  ])('%s', (_name, document, inputType) => {
    it('reaches the server whole, so the schema answers the write rather than a local resolver', () => {
      expect(serverDocumentOf(document)).toBe(print(document));
    });

    // Nothing before the request tells a local input type from the schema's own, and the
    // endpoint rejects the local one as unknown.
    it('declares the input type the schema owns', () => {
      expect(inputTypeOf(document)).toBe(inputType);
    });
  });
});
