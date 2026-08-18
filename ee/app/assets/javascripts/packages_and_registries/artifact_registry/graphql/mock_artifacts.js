import { MILLISECONDS_IN_DAY, getStartOfDay } from '~/lib/utils/datetime/date_calculation_utility';
import {
  REPOSITORY_FORMAT_NPM,
  TYPENAME_ARTIFACT_REGISTRY_IMAGE,
  TYPENAME_ARTIFACT_REGISTRY_MAVEN_PACKAGE,
  TYPENAME_ARTIFACT_REGISTRY_NPM_PACKAGE,
  TYPENAME_ARTIFACT_REGISTRY_VERSION,
} from '../constants';
import { isContainerFormat } from '../utils';

const COMPONENTS = [
  'core',
  'api',
  'gateway',
  'auth',
  'billing',
  'catalog',
  'checkout',
  'client',
  'common',
  'config',
  'crypto',
  'dashboard',
  'events',
  'hooks',
  'icons',
  'ledger',
  'logging',
  'metrics',
  'notifier',
  'parser',
  'runtime',
  'scheduler',
  'storage',
  'telemetry',
  'utils',
];

const MAVEN_GROUP_PREFIX = 'com.example';

const NPM_SCOPE = '@company';

const MIN_ARTIFACTS = 3;

const MAX_ARTIFACTS = COMPONENTS.length;

// Every third npm package is unscoped, so a browser shows both the scoped and the unscoped
// display name.
const UNSCOPED_EVERY = 3;

// Two at the least, so the newest-first order the versions connection imposes is observable on
// every ladder.
const MIN_VERSIONS = 2;

const MAX_VERSIONS = 40;

const PATCHES_PER_MINOR = 5;

// Carried by the newest release of every package, so a version list renders a prerelease beside
// the releases.
const PRERELEASE = '-rc.1';

const PUBLISH_INTERVAL_DAYS = 2;

// How long ago a package's newest release can fall, so the dates two packages' version lists
// render differ.
const PUBLISH_SPREAD_DAYS = 30;

// Pick a replacement pair only if every `hash * MULTIPLIER` stays exactly representable:
// past that, float rounding makes the hash non-deterministic and ids start colliding.
const hashOf = (seed) => {
  const MODULUS = 2147483647;
  const MULTIPLIER = 16807;

  return [...seed].reduce(
    (hash, character) => (hash * MULTIPLIER + character.codePointAt(0)) % MODULUS,
    1,
  );
};

const HEX_DIGITS_PER_HASH = 8;

const UUID_HEX_DIGITS = 32;

const hexFrom = (seed) => hashOf(seed).toString(16).padStart(HEX_DIGITS_PER_HASH, '0');

const uuidFrom = (seed) => {
  const digits = Array.from({ length: UUID_HEX_DIGITS / HEX_DIGITS_PER_HASH }, (_, chunk) =>
    hexFrom(`${seed}#${chunk}`),
  ).join('');

  return [
    digits.slice(0, 8),
    digits.slice(8, 12),
    digits.slice(12, 16),
    digits.slice(16, 20),
    digits.slice(20),
  ].join('-');
};

// Artifact Registry addresses an artifact by an opaque UUID, unlike a repository, which it
// addresses by name (api/openapi/v1.yaml, `ArtifactId`).
//
// Derived from the repository name and the position, never from the format: an id that moved
// with the format would address the same artifact differently under each shape, leaving a URL
// one read handed out dead to the next. Including the name keeps one repository's `image(id:)`
// from answering for another's artifact.
const artifactId = (name, index) => uuidFrom(`${name}#${index}`);

// Dated back from midnight rather than from the moment of the call, so two reads a moment apart
// date one ladder identically, and read per ladder rather than captured once, so a ladder follows
// the clock in force when it is generated. Nothing it dates falls after midnight, so every release
// reads as published already.
const publishedAt = (daysAgo) => {
  const midnight = getStartOfDay(new Date(), { utc: true }).getTime();

  return new Date(midnight - daysAgo * MILLISECONDS_IN_DAY).toISOString();
};

// The major follows the package's position, so two packages of one repository do not both read as
// one ladder; the minor and the patch follow the release's, so no two releases of one package read
// as one version.
const versionNumber = (index, position) =>
  `${index + 1}.${Math.floor(position / PATCHES_PER_MINOR)}.${position % PATCHES_PER_MINOR}`;

// The versions connection reads its rows off the package an artifact read answered with, so a
// package carrying no ladder renders an empty version list.
//
// Seeded on the artifact's position rather than on the format, so the ladder under an artifact id
// is the same ladder whichever shape a read renders that artifact as. Generated oldest first, so
// the newest-first order the connection imposes is ordering it does rather than the order it was
// handed.
const versionLadder = (name, index) => {
  const count =
    MIN_VERSIONS + (hashOf(`${name}#${index}#versions`) % (MAX_VERSIONS - MIN_VERSIONS + 1));
  const newestDaysAgo = hashOf(`${name}#${index}#published`) % PUBLISH_SPREAD_DAYS;

  return Array.from({ length: count }, (_, position) => ({
    __typename: TYPENAME_ARTIFACT_REGISTRY_VERSION,
    id: uuidFrom(`${name}#${index}#version#${position}`),
    version: `${versionNumber(index, position)}${position === count - 1 ? PRERELEASE : ''}`,
    createdAt: publishedAt(newestDaysAgo + (count - 1 - position) * PUBLISH_INTERVAL_DAYS),
  }));
};

// The repository name leads every readable name below, so a browser can tell which repository
// it is looking at.
const image = (name, index) => ({
  __typename: TYPENAME_ARTIFACT_REGISTRY_IMAGE,
  id: artifactId(name, index),
  name: `${name}/${COMPONENTS[index]}`,
});

const mavenPackage = (name, index) => ({
  __typename: TYPENAME_ARTIFACT_REGISTRY_MAVEN_PACKAGE,
  id: artifactId(name, index),
  groupId: `${MAVEN_GROUP_PREFIX}.${name}`,
  artifactId: COMPONENTS[index],
  publishedVersions: versionLadder(name, index),
});

const npmPackage = (name, index) => {
  const publishedVersions = versionLadder(name, index);

  return {
    __typename: TYPENAME_ARTIFACT_REGISTRY_NPM_PACKAGE,
    id: artifactId(name, index),
    name: `${name}-${COMPONENTS[index]}`,
    scope: index % UNSCOPED_EVERY === 0 ? null : NPM_SCOPE,
    // The artifact table states this beside a list the versions connection resolves separately, so
    // a count past the ladder would overstate the rows that list renders.
    versionsCount: publishedVersions.length,
    publishedVersions,
  };
};

// The container formats share the image shape because a repository of either holds images,
// which is also why one set of OCI Distribution Spec endpoints serves both.
const artifactBuilder = (format) => {
  if (isContainerFormat(format)) return image;

  if (format === REPOSITORY_FORMAT_NPM) return npmPackage;

  return mavenPackage;
};

// From the name alone: the detail read states this count beside a list resolved for the
// repository's format, so a count that moved with the format would contradict that list.
const artifactCount = (name) =>
  MIN_ARTIFACTS + (hashOf(name) % (MAX_ARTIFACTS - MIN_ARTIFACTS + 1));

// The artifacts a repository holds, generated from its name so every repository renders a
// list. A name generates the identical page on every call, which keeps an id the connection
// handed out resolvable by the single-artifact read that follows it.
export const mockArtifacts = (name, format) => {
  const build = artifactBuilder(format);

  return Array.from({ length: artifactCount(name) }, (_, index) => build(name, index));
};
