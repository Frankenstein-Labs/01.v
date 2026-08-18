import {
  REPOSITORY_FORMAT_VALUES,
  TYPENAME_ARTIFACT_REGISTRY_IMAGE,
  TYPENAME_ARTIFACT_REGISTRY_MAVEN_PACKAGE,
  TYPENAME_ARTIFACT_REGISTRY_NPM_PACKAGE,
  TYPENAME_ARTIFACT_REGISTRY_VERSION,
} from 'ee/packages_and_registries/artifact_registry/constants';
import { mockArtifacts } from 'ee/packages_and_registries/artifact_registry/graphql/mock_artifacts';
import { artifactDisplayName } from 'ee/packages_and_registries/artifact_registry/utils';

// Two names Artifact Registry serves, one that names no format at all, and the two edges of
// the name contract: a single character, and one using every separator
// REPOSITORY_NAME_PATTERN admits.
const NAMES = ['oci-repository', 'maven-repository', 'payment-core', 'a', 'x_y.z-9'];

const [FIRST_NAME, SECOND_NAME] = NAMES;

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

const MIN_ARTIFACTS = 3;

const MAX_ARTIFACTS = 25;

const CONTAINER_FORMATS = ['DOCKER', 'OCI'];

const PACKAGE_FORMATS = ['MAVEN', 'NPM'];

const ARTIFACT_KEYS = {
  [TYPENAME_ARTIFACT_REGISTRY_IMAGE]: ['__typename', 'id', 'name'],
  [TYPENAME_ARTIFACT_REGISTRY_MAVEN_PACKAGE]: [
    '__typename',
    'artifactId',
    'groupId',
    'id',
    'publishedVersions',
  ],
  [TYPENAME_ARTIFACT_REGISTRY_NPM_PACKAGE]: [
    '__typename',
    'id',
    'name',
    'publishedVersions',
    'scope',
    'versionsCount',
  ],
};

const VERSION_KEYS = ['__typename', 'createdAt', 'id', 'version'];

// Two at the least, so the connection's newest-first order is observable on every ladder.
const MIN_VERSIONS = 2;

const MAX_VERSIONS = 40;

const SEMVER_PATTERN = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/;

describe('Artifact registry mock artifacts', () => {
  const idsOf = (artifacts) => artifacts.map(({ id }) => id);

  const displayNamesOf = (artifacts, format) =>
    artifacts.map((artifact) => artifactDisplayName(artifact, format));

  const typenamesOf = (artifacts) => [...new Set(artifacts.map(({ __typename }) => __typename))];

  const laddersOf = (artifacts) => artifacts.map(({ publishedVersions }) => publishedVersions);

  const versionIdsOf = (artifacts) => laddersOf(artifacts).flatMap(idsOf);

  const versionStringsOf = (ladder) => ladder.map(({ version }) => version);

  const publishedAtOf = (ladder) => ladder.map(({ createdAt }) => Date.parse(createdAt));

  const newestFirst = (publishedAt) => [...publishedAt].sort((left, right) => right - left);

  describe('the page it generates', () => {
    it.each(NAMES)('generates a page for %s, whatever the name', (name) => {
      expect(mockArtifacts(name, 'MAVEN').length).toBeGreaterThanOrEqual(MIN_ARTIFACTS);
      expect(mockArtifacts(name, 'MAVEN').length).toBeLessThanOrEqual(MAX_ARTIFACTS);
    });

    it.each(NAMES)('generates as many artifacts for %s whatever the format', (name) => {
      const counts = REPOSITORY_FORMAT_VALUES.map((format) => mockArtifacts(name, format).length);

      expect(new Set(counts).size).toBe(1);
    });

    it('sizes the page from the name, so two names do not both read as one length', () => {
      const lengths = NAMES.map((name) => mockArtifacts(name, 'MAVEN').length);

      expect(new Set(lengths).size).toBeGreaterThan(1);
    });
  });

  // The single-artifact read resolves an id the connection handed out, so a generator minting
  // a fresh id per call would leave every artifact URL dead the moment the page navigated.
  describe('the artifact ids', () => {
    it.each(REPOSITORY_FORMAT_VALUES)('generates opaque UUIDs for a %s repository', (format) => {
      const ids = idsOf(mockArtifacts(FIRST_NAME, format));

      expect(ids).toHaveLength(new Set(ids).size);
      ids.forEach((id) => expect(id).toMatch(UUID_PATTERN));
    });

    it.each(NAMES)('generates the same ids on a second call for %s', (name) => {
      expect(idsOf(mockArtifacts(name, 'MAVEN'))).toEqual(idsOf(mockArtifacts(name, 'MAVEN')));
    });

    // An id the connection handed out stays the handle on the same artifact whichever shape a
    // read renders it as.
    it('generates ids that do not move with the format', () => {
      const [reference, ...rest] = REPOSITORY_FORMAT_VALUES.map((format) =>
        idsOf(mockArtifacts(FIRST_NAME, format)),
      );

      rest.forEach((ids) => expect(ids).toEqual(reference));
    });

    it('gives no two repositories an id in common', () => {
      const ids = idsOf(mockArtifacts(FIRST_NAME, 'MAVEN'));
      const otherIds = idsOf(mockArtifacts(SECOND_NAME, 'MAVEN'));

      expect(ids.filter((id) => otherIds.includes(id))).toEqual([]);
    });
  });

  describe('the artifact shape, which the format decides', () => {
    it.each(CONTAINER_FORMATS)('generates images for %s', (format) => {
      expect(typenamesOf(mockArtifacts(FIRST_NAME, format))).toEqual([
        TYPENAME_ARTIFACT_REGISTRY_IMAGE,
      ]);
    });

    it('generates Maven packages for MAVEN', () => {
      expect(typenamesOf(mockArtifacts(FIRST_NAME, 'MAVEN'))).toEqual([
        TYPENAME_ARTIFACT_REGISTRY_MAVEN_PACKAGE,
      ]);
    });

    it('generates npm packages for NPM', () => {
      expect(typenamesOf(mockArtifacts(FIRST_NAME, 'NPM'))).toEqual([
        TYPENAME_ARTIFACT_REGISTRY_NPM_PACKAGE,
      ]);
    });

    it.each(REPOSITORY_FORMAT_VALUES)('carries the whole %s shape and nothing else', (format) => {
      mockArtifacts(FIRST_NAME, format).forEach((artifact) => {
        const { __typename: typename } = artifact;

        expect(Object.keys(artifact).sort()).toEqual(ARTIFACT_KEYS[typename]);
      });
    });

    it('scopes some npm packages and leaves others unscoped', () => {
      const scopes = mockArtifacts(FIRST_NAME, 'NPM').map(({ scope }) => scope);

      expect(scopes).toContain(null);
      expect(scopes.filter(Boolean).every((scope) => scope.startsWith('@'))).toBe(true);
    });
  });

  // The versions connection reads its rows off the package the artifact reads answer with, so a
  // package carrying no ladder renders an empty version list in a browser.
  describe('the version ladder every package carries', () => {
    it.each(PACKAGE_FORMATS)('ladders every %s package', (format) => {
      laddersOf(mockArtifacts(FIRST_NAME, format)).forEach((ladder) => {
        expect(ladder.length).toBeGreaterThanOrEqual(MIN_VERSIONS);
        expect(ladder.length).toBeLessThanOrEqual(MAX_VERSIONS);
      });
    });

    it.each(PACKAGE_FORMATS)('sizes a %s ladder per package, not per repository', (format) => {
      const lengths = laddersOf(mockArtifacts(FIRST_NAME, format)).map(({ length }) => length);

      expect(new Set(lengths).size).toBeGreaterThan(1);
    });

    it('gives two packages of one repository different versions', () => {
      const [first, second] = laddersOf(mockArtifacts(FIRST_NAME, 'MAVEN'));

      expect(versionStringsOf(first)).not.toEqual(versionStringsOf(second));
    });

    // The artifact table formats this through `formatNumber`, so a string renders as NaN, and it
    // labels the list the version route goes on to render, so a count past the ladder overstates.
    it('counts the versions it laddered on an npm package', () => {
      mockArtifacts(FIRST_NAME, 'NPM').forEach(({ versionsCount, publishedVersions }) => {
        expect(versionsCount).toBe(publishedVersions.length);
      });
    });

    it.each(PACKAGE_FORMATS)('carries the whole version shape on a %s package', (format) => {
      laddersOf(mockArtifacts(FIRST_NAME, format))
        .flat()
        .forEach((version) => {
          const { __typename: typename } = version;

          expect(Object.keys(version).sort()).toEqual(VERSION_KEYS);
          expect(typename).toBe(TYPENAME_ARTIFACT_REGISTRY_VERSION);
        });
    });

    it.each(PACKAGE_FORMATS)('names every %s version once, as a semantic version', (format) => {
      laddersOf(mockArtifacts(FIRST_NAME, format)).forEach((ladder) => {
        const versions = versionStringsOf(ladder);

        expect(versions).toHaveLength(new Set(versions).size);
        versions.forEach((version) => expect(version).toMatch(SEMVER_PATTERN));
      });
    });

    it('ladders a prerelease somewhere, so a list renders one beside the releases', () => {
      const versions = NAMES.flatMap((name) =>
        laddersOf(mockArtifacts(name, 'MAVEN')).flatMap(versionStringsOf),
      );

      expect(versions.some((version) => version.includes('-'))).toBe(true);
    });

    // `versionsNewestFirst` orders the connection on the parsed timestamp, so two rows
    // publishing at one moment would leave their order down to the generation order.
    it.each(PACKAGE_FORMATS)('publishes each %s version at a moment of its own', (format) => {
      laddersOf(mockArtifacts(FIRST_NAME, format)).forEach((ladder) => {
        const publishedAt = publishedAtOf(ladder);

        expect(publishedAt).toHaveLength(new Set(publishedAt).size);
        publishedAt.forEach((moment) => {
          expect(moment).not.toBeNaN();
          expect(moment).toBeLessThanOrEqual(Date.now());
        });
      });
    });

    it('ladders out of published order, so the connection’s newest-first sort does work', () => {
      const reordered = NAMES.flatMap((name) => laddersOf(mockArtifacts(name, 'MAVEN'))).some(
        (ladder) => {
          const publishedAt = publishedAtOf(ladder);

          return publishedAt.join() !== newestFirst(publishedAt).join();
        },
      );

      expect(reordered).toBe(true);
    });

    it.each(PACKAGE_FORMATS)(
      'mints an opaque UUID for every %s version, and each one once',
      (format) => {
        const ids = versionIdsOf(mockArtifacts(FIRST_NAME, format));

        expect(ids).toHaveLength(new Set(ids).size);
        ids.forEach((id) => expect(id).toMatch(UUID_PATTERN));
      },
    );

    // Both connections cursor on the id of the row they page over, so an id shared between an
    // artifact and a version would let one connection's cursor name a row in the other.
    it('gives no version an id an artifact answers under', () => {
      const artifacts = mockArtifacts(FIRST_NAME, 'NPM');
      const versionIds = new Set(versionIdsOf(artifacts));

      expect(idsOf(artifacts).filter((id) => versionIds.has(id))).toEqual([]);
    });

    it('gives no two repositories a version id in common', () => {
      const versionIds = new Set(versionIdsOf(mockArtifacts(SECOND_NAME, 'NPM')));

      expect(
        versionIdsOf(mockArtifacts(FIRST_NAME, 'NPM')).filter((id) => versionIds.has(id)),
      ).toEqual([]);
    });

    // An artifact keeps its id whichever shape a read renders it as, so the ladder under that id
    // has to keep its version ids and strings too.
    it('ladders an artifact the same under either package shape', () => {
      expect(laddersOf(mockArtifacts(FIRST_NAME, 'MAVEN'))).toEqual(
        laddersOf(mockArtifacts(FIRST_NAME, 'NPM')),
      );
    });
  });

  describe('the names a page reads under', () => {
    it.each(REPOSITORY_FORMAT_VALUES)('names every %s artifact, and each one once', (format) => {
      const names = displayNamesOf(mockArtifacts(FIRST_NAME, format), format);

      expect(names).toHaveLength(new Set(names).size);
      names.forEach((name) => expect(name).not.toBe(''));
    });

    it.each(REPOSITORY_FORMAT_VALUES)('names two %s repositories apart', (format) => {
      const names = displayNamesOf(mockArtifacts(FIRST_NAME, format), format);
      const otherNames = displayNamesOf(mockArtifacts(SECOND_NAME, format), format);

      expect(names.filter((name) => otherNames.includes(name))).toEqual([]);
    });
  });

  // Every read calls this again, so a page that differed between two calls would leave the id one
  // read handed out unresolvable by the next, and would move the rows under a reload.
  it.each(NAMES)('generates the identical page on a second call for %s', (name) => {
    REPOSITORY_FORMAT_VALUES.forEach((format) => {
      expect(mockArtifacts(name, format)).toEqual(mockArtifacts(name, format));
    });
  });

  // The resolvers hand these objects straight over, so a generator holding onto them would let
  // one read edit what the next one answers.
  it('hands out artifacts a caller cannot write back through', () => {
    const [artifact] = mockArtifacts(FIRST_NAME, 'NPM');
    const { name } = artifact;
    artifact.name = 'Edited by the caller';

    expect(mockArtifacts(FIRST_NAME, 'NPM')[0].name).toBe(name);
  });

  it('hands out versions a caller cannot write back through', () => {
    const [{ publishedVersions }] = mockArtifacts(FIRST_NAME, 'NPM');
    const { version } = publishedVersions[0];
    publishedVersions[0].version = '9.9.9-edited-by-the-caller';

    expect(mockArtifacts(FIRST_NAME, 'NPM')[0].publishedVersions[0].version).toBe(version);
  });
});
