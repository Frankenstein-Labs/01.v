import { visit } from 'graphql';
import { omit } from 'lodash-es';
import { createMockClient } from 'helpers/mock_apollo_helper';
import { typePolicies as globalTypePolicies } from '~/lib/graphql';
import { REPOSITORY_FORMAT_VALUES } from 'ee/packages_and_registries/artifact_registry/constants';
import {
  possibleTypes,
  typePolicies as artifactRegistryTypePolicies,
} from 'ee/packages_and_registries/artifact_registry/graphql/cache_config';
import { mockArtifacts } from 'ee/packages_and_registries/artifact_registry/graphql/mock_artifacts';
import { mockResolvers } from 'ee/packages_and_registries/artifact_registry/graphql/mock_resolvers';
import typeDefs from 'ee/packages_and_registries/artifact_registry/graphql/typedefs.graphql';
import getArtifactQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_artifact.query.graphql';
import getArtifactVersionsQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_artifact_versions.query.graphql';
import getRepositoryQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository.query.graphql';
import getRepositoryDetailQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository_detail.query.graphql';
import getRepositoryImagesQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository_images.query.graphql';
import getRepositoryPackagesQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_repository_packages.query.graphql';
import { isContainerFormat } from 'ee/packages_and_registries/artifact_registry/utils';
import { ORGANIZATION_GID } from '../mock_data';

const REPOSITORY_TYPENAME = 'ArtifactRegistryRepository';

// Two names Artifact Registry serves, plus the two edges of the name contract: a single
// character, and one using every separator REPOSITORY_NAME_PATTERN admits.
const NAMES = ['oci-repository', 'maven-repository', 'a', 'x_y.z-9'];

const [NAME] = NAMES;

const CONTAINER_FORMATS = [
  ['DOCKER', 'ArtifactRegistryImageConnection'],
  ['OCI', 'ArtifactRegistryImageConnection'],
];

const PACKAGE_FORMATS = [
  ['MAVEN', 'ArtifactRegistryPackageConnection'],
  ['NPM', 'ArtifactRegistryPackageConnection'],
];

const PACKAGE_SHAPES = [
  ['MAVEN', 'ArtifactRegistryMavenPackage'],
  ['NPM', 'ArtifactRegistryNpmPackage'],
];

// `publishedVersions` is the field the versions resolver reads its parent's ladder off, and no
// document selects it, so an artifact read back through one carries no ladder.
const withoutLadder = (artifact) => omit(artifact, 'publishedVersions');

const newestFirst = (versions) =>
  [...versions].sort((left, right) => Date.parse(right.createdAt) - Date.parse(left.createdAt));

const declaredFields = (kinds) => {
  const fields = {};

  const collect = (node) => {
    fields[node.name.value] = (node.fields ?? []).map(({ name }) => name.value).sort();

    return false;
  };

  visit(typeDefs, Object.fromEntries(kinds.map((kind) => [kind, collect])));

  return fields;
};

const locallyDeclaredFields = () => declaredFields(['ObjectTypeDefinition', 'ObjectTypeExtension']);

// A field graphql/typedefs.graphql adds to a type the schema owns has no server backing, so a
// resolver has to answer it. A field on a wholly local type needs no resolver of its own: it is
// read off the object the resolver one level up returned.
const extendedFields = () => declaredFields(['ObjectTypeExtension']);

describe('Artifact registry mock resolvers', () => {
  // The repository parent the schema resolves: its identity and its format, nothing local.
  const serverParent = (name, format) => ({ __typename: REPOSITORY_TYPENAME, name, format });

  const readImages = (repository, args) =>
    mockResolvers.ArtifactRegistryRepository.images(repository, args);

  const readPackages = (repository, args) =>
    mockResolvers.ArtifactRegistryRepository.packages(repository, args);

  const readImage = (repository, id) =>
    mockResolvers.ArtifactRegistryRepository.image(repository, { id });

  const readPackage = (repository, id) =>
    mockResolvers.ArtifactRegistryRepository.package(repository, { id });

  const readVersions = (typename, artifact, args) =>
    mockResolvers[typename].versions(artifact, args);

  const readArtifactsCount = (repository) =>
    mockResolvers.ArtifactRegistryRepository.artifactsCount(repository);

  const readCreatedAt = (repository) =>
    mockResolvers.ArtifactRegistryRepository.createdAt(repository);

  const readAttribution = (field) => mockResolvers.ArtifactRegistryRepository[field]();

  const cursorFor = ({ id }) => window.btoa(JSON.stringify({ key: id }));

  const wholePageInfo = (artifacts) => ({
    __typename: 'PageInfo',
    hasPreviousPage: false,
    hasNextPage: false,
    startCursor: cursorFor(artifacts[0]),
    endCursor: cursorFor(artifacts.at(-1)),
  });

  beforeEach(() => {
    // The resolvers' delay is scheduled asynchronously, so advancing Jest's timers cannot
    // reach it; collapsing it keeps these assertions about behavior rather than timing.
    jest.spyOn(global, 'setTimeout').mockImplementation((callback) => callback());
  });

  describe('the fields it answers', () => {
    // A resolver standing over a field the schema resolves would override the server for every
    // read selecting it.
    it.each(Object.keys(mockResolvers))(
      'answers no %s field beyond the ones graphql/typedefs.graphql declares',
      (typename) => {
        const declared = locallyDeclaredFields()[typename] ?? [];

        expect(
          Object.keys(mockResolvers[typename]).filter((field) => !declared.includes(field)),
        ).toEqual([]);
      },
    );

    it.each(Object.keys(extendedFields()))(
      'answers every field graphql/typedefs.graphql adds to the schema’s %s',
      (typename) => {
        expect(Object.keys(mockResolvers[typename] ?? {}).sort()).toEqual(
          extendedFields()[typename],
        );
      },
    );
  });

  describe('the artifact connections', () => {
    it.each(CONTAINER_FORMATS)(
      'resolves images and no packages for a %s repository',
      async (format, typename) => {
        const artifacts = mockArtifacts(NAME, format);

        expect(await readImages(serverParent(NAME, format))).toEqual({
          __typename: typename,
          nodes: artifacts,
          pageInfo: wholePageInfo(artifacts),
        });
        expect(await readPackages(serverParent(NAME, format))).toBe(null);
      },
    );

    it.each(PACKAGE_FORMATS)(
      'resolves packages and no images for a %s repository',
      async (format, typename) => {
        const artifacts = mockArtifacts(NAME, format);

        expect(await readPackages(serverParent(NAME, format))).toEqual({
          __typename: typename,
          nodes: artifacts,
          pageInfo: wholePageInfo(artifacts),
        });
        expect(await readImages(serverParent(NAME, format))).toBe(null);
      },
    );

    it.each(NAMES)('resolves a populated connection for %s, whatever the name', async (name) => {
      const { nodes } = await readPackages(serverParent(name, 'MAVEN'));

      expect(nodes).toEqual(mockArtifacts(name, 'MAVEN'));
      expect(nodes.length).toBeGreaterThan(0);
    });

    it('resolves nodes a caller cannot write the next read through', async () => {
      const { nodes } = await readPackages(serverParent(NAME, 'NPM'));
      const { name } = nodes[0];
      nodes[0].name = 'Edited by the caller';

      expect((await readPackages(serverParent(NAME, 'NPM'))).nodes[0].name).toBe(name);
    });
  });

  describe('the single-artifact reads', () => {
    it.each(CONTAINER_FORMATS)(
      'resolves an image and no package for a %s repository',
      async (format) => {
        const [artifact] = mockArtifacts(NAME, format);

        expect(await readImage(serverParent(NAME, format), artifact.id)).toEqual(artifact);
        expect(await readPackage(serverParent(NAME, format), artifact.id)).toBe(null);
      },
    );

    it.each(PACKAGE_FORMATS)(
      'resolves a package and no image for a %s repository',
      async (format) => {
        const [artifact] = mockArtifacts(NAME, format);

        expect(await readPackage(serverParent(NAME, format), artifact.id)).toEqual(artifact);
        expect(await readImage(serverParent(NAME, format), artifact.id)).toBe(null);
      },
    );

    it('resolves null for an artifact another repository holds', async () => {
      const [artifact] = mockArtifacts('maven-repository', 'MAVEN');

      expect(await readPackage(serverParent('a', 'MAVEN'), artifact.id)).toBe(null);
    });

    it.each`
      field        | format      | read
      ${'image'}   | ${'DOCKER'} | ${readImage}
      ${'package'} | ${'MAVEN'}  | ${readPackage}
    `('resolves null for $field when no artifact carries that id', async ({ format, read }) => {
      expect(await read(serverParent(NAME, format), 'no-such-artifact-id')).toBe(null);
    });

    it('resolves an artifact a caller cannot write the next read through', async () => {
      const [{ id, artifactId }] = mockArtifacts(NAME, 'MAVEN');
      const artifact = await readPackage(serverParent(NAME, 'MAVEN'), id);
      artifact.artifactId = 'Edited by the caller';

      expect((await readPackage(serverParent(NAME, 'MAVEN'), id)).artifactId).toBe(artifactId);
    });
  });

  describe('the versions connection', () => {
    const firstPackage = (name, format) => mockArtifacts(name, format)[0];

    it.each(PACKAGE_SHAPES)(
      'resolves the whole ladder of a %s package, newest-first',
      async (format, typename) => {
        const artifact = firstPackage(NAME, format);
        const { nodes } = await readVersions(typename, artifact);

        expect(nodes.length).toBeGreaterThan(1);
        expect(nodes).toEqual(newestFirst(artifact.publishedVersions));
      },
    );

    it.each(NAMES)('resolves a populated ladder for %s, whatever the name', async (name) => {
      const artifact = firstPackage(name, 'MAVEN');
      const { nodes } = await readVersions('ArtifactRegistryMavenPackage', artifact);

      expect(nodes.length).toBeGreaterThan(0);
      expect(nodes).toHaveLength(artifact.publishedVersions.length);
    });

    it('resolves as many rows as the count the artifact table states for an npm package', async () => {
      const npmPackage = firstPackage(NAME, 'NPM');
      const { nodes } = await readVersions('ArtifactRegistryNpmPackage', npmPackage);

      expect(nodes).toHaveLength(npmPackage.versionsCount);
    });

    // A parent read back through a document carries no ladder, so the connection answers empty
    // on one rather than throwing.
    it('resolves an empty connection for a parent carrying no ladder', async () => {
      const parent = withoutLadder(firstPackage(NAME, 'MAVEN'));

      expect(await readVersions('ArtifactRegistryMavenPackage', parent)).toMatchObject({
        __typename: 'ArtifactRegistryVersionConnection',
        nodes: [],
      });
    });
  });

  describe('the paging arguments', () => {
    const idsOf = ({ nodes }) => nodes.map(({ id }) => id);

    const artifacts = () => mockArtifacts(NAME, 'NPM');

    const page = (pageArguments) => readPackages(serverParent(NAME, 'NPM'), pageArguments);

    it('answers the whole set when the caller asks for no page', async () => {
      expect(idsOf(await page())).toEqual(artifacts().map(({ id }) => id));
    });

    it('answers the leading rows for a forward page with no cursor', async () => {
      const [first, second] = artifacts();

      expect(idsOf(await page({ first: 2 }))).toEqual([first.id, second.id]);
    });

    it('resumes after the row the forward cursor names', async () => {
      const [first, second, third] = artifacts();

      expect(idsOf(await page({ first: 2, after: cursorFor(first) }))).toEqual([
        second.id,
        third.id,
      ]);
    });

    it('stops before the row the backward cursor names', async () => {
      const [first, second, third] = artifacts();

      expect(idsOf(await page({ last: 2, before: cursorFor(third) }))).toEqual([
        first.id,
        second.id,
      ]);
    });

    it('pages from the unbounded edge when the cursor names no row it holds', async () => {
      const [first, second] = artifacts();

      expect(idsOf(await page({ first: 2, after: cursorFor({ id: 'gone' }) }))).toEqual([
        first.id,
        second.id,
      ]);
    });

    it('reports the cursors of the rows the page holds', async () => {
      const [first, second] = artifacts();

      expect((await page({ first: 2 })).pageInfo).toEqual({
        __typename: 'PageInfo',
        hasPreviousPage: false,
        hasNextPage: true,
        startCursor: cursorFor(first),
        endCursor: cursorFor(second),
      });
    });

    it('reports no next page on the last page', async () => {
      const rows = artifacts();
      const { pageInfo } = await page({ first: rows.length, after: cursorFor(rows[0]) });

      expect(pageInfo).toMatchObject({ hasPreviousPage: true, hasNextPage: false });
    });

    it('slices the images connection by the same cursors', async () => {
      const [first, second] = mockArtifacts(NAME, 'OCI');
      const images = await readImages(serverParent(NAME, 'OCI'), {
        first: 1,
        after: cursorFor(first),
      });

      expect(idsOf(images)).toEqual([second.id]);
    });
  });

  describe('the fields the schema does not carry', () => {
    describe('the artifact counter', () => {
      it.each(NAMES)('counts the artifacts %s generates', (name) => {
        expect(readArtifactsCount(serverParent(name, 'MAVEN'))).toBe(
          String(mockArtifacts(name, 'MAVEN').length),
        );
      });

      it('resolves a string, the shape the BigInt scalar serializes to', () => {
        expect(typeof readArtifactsCount(serverParent(NAME, 'MAVEN'))).toBe('string');
      });

      // The sidebar states this count beside a list the connection resolved separately, so a
      // count that moved with the format would contradict the list it labels.
      it.each(REPOSITORY_FORMAT_VALUES)('counts the same for %s', (format) => {
        expect(readArtifactsCount(serverParent(NAME, format))).toBe(
          readArtifactsCount(serverParent(NAME, 'MAVEN')),
        );
      });
    });

    describe('the creation timestamp', () => {
      // The sidebar formats this one unconditionally, so an absent value would render as
      // today's date.
      it.each(NAMES)('resolves a formattable timestamp for %s', (name) => {
        expect(Date.parse(readCreatedAt(serverParent(name, 'MAVEN')))).not.toBeNaN();
      });

      it('resolves the same timestamp on a second read, so the sidebar does not move', () => {
        expect(readCreatedAt(serverParent(NAME, 'MAVEN'))).toBe(
          readCreatedAt(serverParent(NAME, 'MAVEN')),
        );
      });
    });

    describe('the attribution joins', () => {
      it.each(['createdBy', 'updatedBy'])('resolves the signed-in user for %s', (field) => {
        window.gon = {
          current_user_id: 7,
          current_username: 'alex',
          current_user_fullname: 'Alex Turner',
          current_user_avatar_url: '/avatar.png',
        };

        expect(readAttribution(field)).toEqual({
          __typename: 'UserCore',
          id: 'gid://gitlab/User/7',
          name: 'Alex Turner',
          avatarUrl: '/avatar.png',
          webPath: '/alex',
        });
      });

      it.each(['createdBy', 'updatedBy'])(
        'resolves null for %s when nobody is signed in',
        (field) => {
          window.gon = {};

          expect(readAttribution(field)).toBe(null);
        },
      );
    });
  });

  // Calling the resolvers directly says nothing about which parent each one is handed, or how
  // its result merges onto the server's, so these examples compose the map with a client and
  // the app's own documents.
  describe('composed with the query documents into an Apollo client', () => {
    const SERVER_FORMAT = 'NPM';

    const serverRepository = (name, overrides = {}) => ({
      __typename: REPOSITORY_TYPENAME,
      name,
      format: SERVER_FORMAT,
      kind: 'HOSTED',
      visibility: 'PRIVATE',
      description: 'Resolved by the schema',
      downloadsCount: '17',
      sizeBytes: '4096',
      lastUpdatedAt: '2026-07-02T00:00:00Z',
      ...overrides,
    });

    const organizationResponse = (repository) => ({
      data: {
        organization: {
          __typename: 'Organization',
          id: ORGANIZATION_GID,
          artifactRegistryRepository: repository,
        },
      },
    });

    const repositoryHandler = (repository) => jest.fn(() => organizationResponse(repository));

    const createClient = (handlers) =>
      createMockClient(handlers, mockResolvers, {
        possibleTypes,
        typePolicies: { ...globalTypePolicies, ...artifactRegistryTypePolicies },
      });

    const read = (client, query, variables) =>
      client
        .query({ query, variables: { organizationId: ORGANIZATION_GID, ...variables } })
        .then(({ data }) => data.organization.artifactRegistryRepository);

    beforeEach(() => {
      // The attribution resolvers read the signed-in user off `gon`, so pinning it keeps those
      // two fields out of the assertions below.
      window.gon = {};
    });

    describe('the detail read, whose repository the schema resolves', () => {
      const detailRead = (name) =>
        read(
          createClient([[getRepositoryDetailQuery, repositoryHandler(serverRepository(name))]]),
          getRepositoryDetailQuery,
          { name },
        );

      it.each(NAMES)('answers with the schema’s repository whole for %s', async (name) => {
        const { artifactsCount, createdAt, createdBy, updatedBy, ...serverBacked } =
          await detailRead(name);

        expect(serverBacked).toEqual(serverRepository(name));
      });

      it('merges the locally-resolved fields onto it rather than replacing it', async () => {
        expect(await detailRead(NAME)).toMatchObject({
          artifactsCount: String(mockArtifacts(NAME, SERVER_FORMAT).length),
          createdBy: null,
          updatedBy: null,
        });
      });
    });

    describe('the artifact read, whose repository the schema resolves', () => {
      const artifactRead = (repository, { name, artifactId }) =>
        read(createClient([[getArtifactQuery, repositoryHandler(repository)]]), getArtifactQuery, {
          name,
          artifactId,
        });

      const artifactReadFor = (name, format, artifactId) =>
        artifactRead(serverParent(name, format), { name, artifactId });

      // The document selects `versionsCount` nowhere either, so an npm package reads back
      // without it.
      const asRead = (artifact) => omit(withoutLadder(artifact), 'versionsCount');

      it.each(REPOSITORY_FORMAT_VALUES)(
        'answers the repository and its artifact under the %s shape',
        async (format) => {
          const [artifact] = mockArtifacts(NAME, format);
          const isImage = isContainerFormat(format);

          expect(await artifactReadFor(NAME, format, artifact.id)).toEqual({
            __typename: REPOSITORY_TYPENAME,
            name: NAME,
            format,
            image: isImage ? artifact : null,
            package: isImage ? null : asRead(artifact),
          });
        },
      );

      it.each(NAMES)('answers an artifact for %s, whatever the name', async (name) => {
        const [artifact] = mockArtifacts(name, SERVER_FORMAT);

        expect(await artifactReadFor(name, SERVER_FORMAT, artifact.id)).toMatchObject({
          package: asRead(artifact),
        });
      });

      it('answers no artifact for an id the repository generates none under', async () => {
        expect(await artifactReadFor(NAME, SERVER_FORMAT, 'no-such-artifact-id')).toEqual({
          __typename: REPOSITORY_TYPENAME,
          name: NAME,
          format: SERVER_FORMAT,
          image: null,
          package: null,
        });
      });

      // Which is what leaves this route its not-found state for a repository Artifact Registry
      // does not hold: existence is the schema's answer, the same as on every other read.
      it('answers nothing for a repository the schema resolves null', async () => {
        const artifactFields = ['image', 'package'].map((field) =>
          jest.spyOn(mockResolvers[REPOSITORY_TYPENAME], field),
        );

        expect(await artifactRead(null, { name: NAME, artifactId: 'any-artifact-id' })).toBe(null);
        artifactFields.forEach((resolver) => expect(resolver).not.toHaveBeenCalled());
      });
    });

    describe('the versions read, whose repository the schema resolves', () => {
      const versionsRead = (name, format, artifactId) =>
        read(
          createClient([[getArtifactVersionsQuery, repositoryHandler(serverParent(name, format))]]),
          getArtifactVersionsQuery,
          { name, artifactId },
        );

      it.each(NAMES)('answers the ladder of a package %s generates', async (name) => {
        const [artifact] = mockArtifacts(name, SERVER_FORMAT);
        const { package: versioned } = await versionsRead(name, SERVER_FORMAT, artifact.id);

        expect(versioned.versions.nodes).toEqual(newestFirst(artifact.publishedVersions));
      });

      // The document selects no `image`, so the null package is this route's whole answer for an
      // artifact the repository does not hold.
      it('answers a null package for an id the repository generates none under', async () => {
        expect(await versionsRead(NAME, SERVER_FORMAT, 'no-such-artifact-id')).toEqual({
          __typename: REPOSITORY_TYPENAME,
          name: NAME,
          format: SERVER_FORMAT,
          package: null,
        });
      });

      // A version id that moved between calls would leave the rows of the earlier read in the
      // cache beside the rows of the later one.
      it('writes one entity per version, however often the read runs', async () => {
        const [artifact] = mockArtifacts(NAME, SERVER_FORMAT);
        const handler = repositoryHandler(serverParent(NAME, SERVER_FORMAT));
        const client = createClient([[getArtifactVersionsQuery, handler]]);
        const variables = {
          organizationId: ORGANIZATION_GID,
          name: NAME,
          artifactId: artifact.id,
        };

        await client.query({ query: getArtifactVersionsQuery, variables });
        await client.query({
          query: getArtifactVersionsQuery,
          variables,
          fetchPolicy: 'network-only',
        });

        expect(handler).toHaveBeenCalledTimes(2);
        expect(
          Object.keys(client.cache.extract()).filter((key) =>
            key.startsWith('ArtifactRegistryVersion:'),
          ),
        ).toHaveLength(artifact.publishedVersions.length);
      });
    });

    // graphql/cache_config.js keys the repository on its name, so both reads write one entity
    // between them, with one artifact field per id on it. Both taking the format from the schema
    // keeps the type written under an id and the type read back against it one type.
    describe('the artifact read and the detail read, against one repository', () => {
      // NAME says OCI while the schema resolves Maven, so an answer drawn from anywhere but the
      // schema reads as the wrong artifact type in the cache.
      const RESOLVED_FORMAT = 'MAVEN';

      const ARTIFACT = mockArtifacts(NAME, RESOLVED_FORMAT)[0];

      const variables = { organizationId: ORGANIZATION_GID, name: NAME };

      // The artifact read runs first, which is the order a viewer opening an artifact URL in a
      // fresh tab produces.
      const readArtifactThenDetail = async () => {
        const client = createClient([
          [
            getRepositoryDetailQuery,
            repositoryHandler(serverRepository(NAME, { format: RESOLVED_FORMAT })),
          ],
          [getArtifactQuery, repositoryHandler(serverParent(NAME, RESOLVED_FORMAT))],
        ]);

        await client.query({
          query: getArtifactQuery,
          variables: { ...variables, artifactId: ARTIFACT.id },
        });
        await client.query({ query: getRepositoryDetailQuery, variables });

        return client;
      };

      it('leaves one artifact entity under an id, of the type the format decides', async () => {
        const client = await readArtifactThenDetail();

        expect(
          Object.keys(client.cache.extract()).filter((key) => key.endsWith(`:${ARTIFACT.id}`)),
        ).toEqual([`ArtifactRegistryMavenPackage:${ARTIFACT.id}`]);
      });

      // The cache field key follows the arguments the document names, so an artifact id passed
      // here as well would give this read a field of its own, holding a format no other read
      // could correct.
      it('writes the repository under the field key the detail read writes it under', async () => {
        const client = await readArtifactThenDetail();
        const organization = client.cache.extract()[`Organization:${ORGANIZATION_GID}`];

        expect(
          Object.keys(organization).filter((key) => key.startsWith('artifactRegistryRepository')),
        ).toEqual([`artifactRegistryRepository({"name":"${NAME}"})`]);
      });
    });

    describe('the artifact connection reads, whose repository the schema resolves', () => {
      const connectionRead = (query, name, format) =>
        read(createClient([[query, repositoryHandler(serverParent(name, format))]]), query, {
          name,
          first: 2,
        });

      it.each(CONTAINER_FORMATS)('pages the images a %s repository generates', async (format) => {
        const { images } = await connectionRead(getRepositoryImagesQuery, NAME, format);

        expect(images.nodes).toEqual(mockArtifacts(NAME, format).slice(0, 2));
      });

      it.each(PACKAGE_FORMATS)('pages the packages a %s repository generates', async (format) => {
        const { packages } = await connectionRead(getRepositoryPackagesQuery, NAME, format);

        expect(packages.nodes).toEqual(mockArtifacts(NAME, format).slice(0, 2).map(withoutLadder));
      });

      it.each(NAMES)('pages a populated connection for %s, whatever the name', async (name) => {
        const { packages } = await connectionRead(getRepositoryPackagesQuery, name, 'NPM');

        expect(packages.nodes.length).toBeGreaterThan(0);
      });
    });

    describe('the edit prefill, which declares no client field', () => {
      it('answers from the schema alone', async () => {
        const prefilled = {
          __typename: REPOSITORY_TYPENAME,
          name: NAME,
          format: SERVER_FORMAT,
          kind: 'HOSTED',
          visibility: 'PRIVATE',
          description: 'Resolved by the schema',
        };

        const prefill = await read(
          createClient([[getRepositoryQuery, repositoryHandler(prefilled)]]),
          getRepositoryQuery,
          { name: NAME },
        );

        expect(prefill).toEqual(prefilled);
      });
    });
  });
});
