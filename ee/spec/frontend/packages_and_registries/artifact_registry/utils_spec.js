import {
  artifactDisplayName,
  buildRegistryClientUrl,
  buildRepositoryClientUrl,
  isContainerFormat,
  toFilterEnumValue,
  buildDocumentTitle,
  routeName,
  toFilterQueryValue,
  toSortEnumValue,
  toTableSort,
} from 'ee/packages_and_registries/artifact_registry/utils';
import { CLIENT_BASE_URL, SLUG } from './mock_data';

describe('isContainerFormat', () => {
  it.each(['DOCKER', 'OCI'])('reads %s as a container format', (format) => {
    expect(isContainerFormat(format)).toBe(true);
  });

  it.each(['MAVEN', 'NPM', undefined])('reads %p as not a container format', (format) => {
    expect(isContainerFormat(format)).toBe(false);
  });
});

describe('artifactDisplayName', () => {
  it('names a Maven package by its coordinates', () => {
    expect(
      artifactDisplayName({ groupId: 'com.company.payment', artifactId: 'core' }, 'MAVEN'),
    ).toBe('com.company.payment:core');
  });

  it('names a scoped npm package by its scope and name', () => {
    expect(artifactDisplayName({ scope: '@company', name: 'design-system' }, 'NPM')).toBe(
      '@company/design-system',
    );
  });

  it('names an unscoped npm package by its name alone', () => {
    expect(artifactDisplayName({ scope: null, name: 'design-tokens' }, 'NPM')).toBe(
      'design-tokens',
    );
  });

  it.each(['DOCKER', 'OCI'])('names a %s image by its name', (format) => {
    expect(artifactDisplayName({ name: 'payment-service' }, format)).toBe('payment-service');
  });

  it.each([null, undefined])(
    'reads %p as no name, so a pending read renders nothing',
    (artifact) => {
      expect(artifactDisplayName(artifact, 'MAVEN')).toBe('');
    },
  );
});

describe('toFilterQueryValue', () => {
  it('lowercases an enum value for the route query', () => {
    expect(toFilterQueryValue('MAVEN')).toBe('maven');
  });

  it.each([null, undefined])('reads %p as no filter', (value) => {
    expect(toFilterQueryValue(value)).toBe(null);
  });
});

describe('toFilterEnumValue', () => {
  const values = ['DOCKER', 'MAVEN', 'NPM', 'OCI'];

  it('resolves a lowercase query value to its enum value', () => {
    expect(toFilterEnumValue('npm', values)).toBe('NPM');
  });

  it.each([null, undefined, '', 'rubygems'])('reads %p as no filter', (value) => {
    expect(toFilterEnumValue(value, values)).toBe(null);
  });

  // Matching against the known values rather than indexing a lookup object is what
  // keeps an inherited property name from reading as a match.
  it.each(['constructor', 'toString', '__proto__'])(
    'reads the inherited property name %p as no filter',
    (value) => {
      expect(toFilterEnumValue(value, values)).toBe(null);
    },
  );

  it('does not match an enum value spelled in its own case', () => {
    expect(toFilterEnumValue('NPM', values)).toBe(null);
  });
});

describe('toSortEnumValue', () => {
  it.each([
    [{ sortBy: 'name', sortDesc: false }, 'NAME_ASC'],
    [{ sortBy: 'name', sortDesc: true }, 'NAME_DESC'],
    [{ sortBy: 'downloadsCount', sortDesc: false }, 'DOWNLOADS_COUNT_ASC'],
    [{ sortBy: 'sizeBytes', sortDesc: true }, 'SIZE_BYTES_DESC'],
    [{ sortBy: 'lastUpdatedAt', sortDesc: true }, 'LAST_UPDATED_AT_DESC'],
  ])('turns the table sort %p into %s', (sort, enumValue) => {
    expect(toSortEnumValue(sort)).toBe(enumValue);
  });
});

describe('toTableSort', () => {
  it.each([
    ['NAME_ASC', { sortBy: 'name', sortDesc: false }],
    ['NAME_DESC', { sortBy: 'name', sortDesc: true }],
    ['DOWNLOADS_COUNT_ASC', { sortBy: 'downloadsCount', sortDesc: false }],
    ['SIZE_BYTES_DESC', { sortBy: 'sizeBytes', sortDesc: true }],
    ['LAST_UPDATED_AT_DESC', { sortBy: 'lastUpdatedAt', sortDesc: true }],
  ])('turns the enum value %s into the table sort %p', (enumValue, sort) => {
    expect(toTableSort(enumValue)).toEqual(sort);
  });

  // A sort column the list renders no column for, and one the enum never carried.
  it.each([null, undefined, '', 'ARTIFACTS_COUNT_DESC', 'NAME', 'NAME_SIDEWAYS'])(
    'reads %p as no sort',
    (enumValue) => {
      expect(toTableSort(enumValue)).toBe(null);
    },
  );

  // A Map rather than an object is what keeps an inherited property name from resolving
  // to something that is not a sort.
  it.each(['constructor', 'toString', '__proto__'])(
    'reads the inherited property name %p as no sort',
    (enumValue) => {
      expect(toTableSort(enumValue)).toBe(null);
    },
  );

  // The sort is handed on as a prop, so a caller must not write through to the lookup.
  it('returns a copy, so a caller cannot write through to the next call', () => {
    const first = toTableSort('NAME_ASC');

    first.sortDesc = true;

    expect(toTableSort('NAME_ASC')).toEqual({ sortBy: 'name', sortDesc: false });
  });
});

describe('routeName', () => {
  it('reads the crumb text for a route with no dynamic segment', () => {
    expect(routeName({ meta: { text: 'Repositories' }, params: {} })).toBe('Repositories');
  });

  it('reads the param a dynamic route names', () => {
    expect(routeName({ meta: { useId: true }, params: { id: 'payment-core' } })).toBe(
      'payment-core',
    );
  });

  it('reads the param named in meta.idParam', () => {
    expect(
      routeName({
        meta: { useId: true, idParam: 'artifactId' },
        params: { id: 'payment-core', artifactId: 'abc' },
      }),
    ).toBe('abc');
  });

  it.each([
    ['the id param', { useId: true }, {}],
    ['the param named in meta.idParam', { useId: true, idParam: 'artifactId' }, { id: 'abc' }],
  ])('resolves no name for a dynamic route missing %s', (_, meta, params) => {
    expect(routeName({ meta, params })).toBeUndefined();
  });

  it('prefers the name the route resolves over its param', () => {
    expect(
      routeName({
        meta: {
          useId: true,
          idParam: 'artifactId',
          nameGenerator: () => 'com.company.payment:core',
        },
        params: { artifactId: 'abc' },
      }),
    ).toBe('com.company.payment:core');
  });

  it('falls back to the param until a name resolves', () => {
    expect(
      routeName({
        meta: { useId: true, idParam: 'artifactId', nameGenerator: () => '' },
        params: { artifactId: 'abc' },
      }),
    ).toBe('abc');
  });
});

describe('buildDocumentTitle', () => {
  const route = (metas, params = {}) => ({ matched: metas.map((meta) => ({ meta })), params });

  it('prepends each matched route name in nesting order', () => {
    expect(buildDocumentTitle(route([{ text: 'Parent' }, { text: 'Child' }]), 'Base')).toBe(
      'Child · Parent · Base',
    );
  });

  it('leaves the base title unchanged when no matched route names itself', () => {
    expect(buildDocumentTitle(route([{}]), 'Base')).toBe('Base');
  });

  it('leaves the base title unchanged when a dynamic route resolves no name', () => {
    expect(buildDocumentTitle(route([{ useId: true }]), 'Base')).toBe('Base');
  });

  it('skips a route that opts out of the title', () => {
    expect(buildDocumentTitle(route([{ text: 'Repositories', skipTitle: true }]), 'Base')).toBe(
      'Base',
    );
  });

  it('prefers meta.title over the crumb text', () => {
    expect(buildDocumentTitle(route([{ text: 'Edit', title: 'Edit repository' }]), 'Base')).toBe(
      'Edit repository · Base',
    );
  });

  it('titles each dynamic route from its own param', () => {
    const title = buildDocumentTitle(
      route([{ useId: true }, { useId: true, idParam: 'artifactId' }], {
        id: 'payment-core',
        artifactId: 'abc',
      }),
      'Base',
    );

    expect(title).toBe('abc · payment-core · Base');
  });

  it('titles a route by the name it resolved, over its param', () => {
    const title = buildDocumentTitle(
      route([{ useId: true, idParam: 'artifactId', nameGenerator: () => 'core' }], {
        artifactId: 'abc',
      }),
      'Base',
    );

    expect(title).toBe('core · Base');
  });
});

describe('buildRegistryClientUrl', () => {
  const buildUrl = (overrides = {}) =>
    buildRegistryClientUrl({ clientBaseUrl: CLIENT_BASE_URL, handle: SLUG, ...overrides });

  it('composes the registry URL from the Artifact Registry origin and the handle', () => {
    expect(buildUrl()).toBe(`${CLIENT_BASE_URL}/${SLUG}`);
  });

  it('joins the base URL cleanly when it carries a trailing slash', () => {
    expect(buildUrl({ clientBaseUrl: `${CLIENT_BASE_URL}/` })).toBe(`${CLIENT_BASE_URL}/${SLUG}`);
  });

  it.each([
    ['the instance configures no Artifact Registry', { clientBaseUrl: null }],
    ['no handle has been claimed yet', { handle: null }],
    ['the handle field is still empty', { handle: '' }],
  ])('resolves no URL when %s', (_, overrides) => {
    expect(buildUrl(overrides)).toBeNull();
  });
});

describe('buildRepositoryClientUrl', () => {
  const buildUrl = (overrides = {}) =>
    buildRepositoryClientUrl({
      clientBaseUrl: CLIENT_BASE_URL,
      slug: SLUG,
      format: 'MAVEN',
      name: 'my-repository',
      ...overrides,
    });

  // The segment names the protocol family, not the repository's own format, which is why
  // Docker and OCI share one: a single set of OCI Distribution Spec endpoints serves both.
  describe.each([
    ['MAVEN', 'maven'],
    ['NPM', 'npm'],
    ['DOCKER', 'container'],
    ['OCI', 'container'],
  ])('for a %s repository', (format, segment) => {
    it(`composes the URL over the ${segment} segment`, () => {
      expect(buildUrl({ format })).toBe(`${CLIENT_BASE_URL}/${SLUG}/${segment}/my-repository`);
    });
  });

  it.each([
    ['a space', 'my repository', 'my%20repository'],
    ['a query delimiter', 'my?repository', 'my%3Frepository'],
    ['a fragment delimiter', 'my#repository', 'my%23repository'],
  ])('percent-encodes %s in the repository name', (_, name, encoded) => {
    expect(buildUrl({ name })).toBe(`${CLIENT_BASE_URL}/${SLUG}/maven/${encoded}`);
  });

  it('joins the base URL cleanly when it carries a trailing slash', () => {
    expect(buildUrl({ clientBaseUrl: `${CLIENT_BASE_URL}/` })).toBe(
      `${CLIENT_BASE_URL}/${SLUG}/maven/my-repository`,
    );
  });

  // Each of these would compose a URL with a hole in it, so the caller gets nothing to
  // offer rather than something that would not resolve.
  it.each([
    ['the instance configures no Artifact Registry', { clientBaseUrl: null }],
    ['the namespace slug is missing', { slug: null }],
    ['the format has no client segment', { format: 'CONDA' }],
    ['the repository has no name', { name: null }],
  ])('resolves no URL when %s', (_, overrides) => {
    expect(buildUrl(overrides)).toBeNull();
  });
});
