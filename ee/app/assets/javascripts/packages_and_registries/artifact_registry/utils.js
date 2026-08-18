import { numberToHumanSize } from '~/lib/utils/number_utils';
import { joinPaths } from '~/lib/utils/url_utility';
import { formatNumber } from '~/locale';
import {
  REPOSITORY_FORMAT_CONTAINER_FAMILY,
  REPOSITORY_FORMAT_MAVEN,
  REPOSITORY_FORMAT_NPM,
  REPOSITORY_FORMAT_PATH_SEGMENTS,
  REPOSITORY_SORT_COLUMNS,
} from './constants';

export const isContainerFormat = (format) => REPOSITORY_FORMAT_CONTAINER_FAMILY.includes(format);

export const artifactDisplayName = (artifact, format) => {
  if (!artifact) return '';

  if (format === REPOSITORY_FORMAT_MAVEN) return `${artifact.groupId}:${artifact.artifactId}`;

  if (format === REPOSITORY_FORMAT_NPM) {
    return artifact.scope ? `${artifact.scope}/${artifact.name}` : artifact.name;
  }

  return artifact.name;
};

export const toCount = (count) => Number(count ?? 0);

export const humanSize = (sizeBytes) => numberToHumanSize(toCount(sizeBytes));

export const formattedCount = (count) => formatNumber(toCount(count));

// A filter travels through the route query in lowercase rather than in the GraphQL
// enum spelling, because the URL is user-facing and shareable. Translating at that one
// boundary keeps an already-shared link working across an enum rename, and confines the
// enum spelling to the layer that talks to the schema.
export const toFilterQueryValue = (enumValue) => enumValue?.toLowerCase() ?? null;

// An unrecognized value reads as no filter rather than reaching the query, so a
// hand-edited or stale URL renders the unfiltered list instead of an error. Matching
// against the known values, rather than indexing a lookup object, keeps an inherited
// property name such as `constructor` from reading as a match.
export const toFilterEnumValue = (queryValue, enumValues) =>
  enumValues.find((value) => value.toLowerCase() === queryValue) ?? null;

export const toSortEnumValue = ({ sortBy, sortDesc }) =>
  `${REPOSITORY_SORT_COLUMNS[sortBy]}_${sortDesc ? 'DESC' : 'ASC'}`;

// A Map rather than an object, so `constructor` resolves to nothing rather than to an
// inherited property.
const TABLE_SORTS = new Map(
  Object.entries(REPOSITORY_SORT_COLUMNS).flatMap(([sortBy, column]) => [
    [`${column}_ASC`, { sortBy, sortDesc: false }],
    [`${column}_DESC`, { sortBy, sortDesc: true }],
  ]),
);

export const toTableSort = (enumValue) => {
  const sort = TABLE_SORTS.get(enumValue);

  // A copy, so the shared entry cannot be written through by whoever holds the sort.
  return sort ? { ...sort } : null;
};

// The name a route gives itself, defined once for the trail and the document title. A
// route naming a dynamic segment reads that segment's param; one whose segment is an
// opaque id names itself through `meta.nameGenerator`, as the other registry SPAs do, and
// falls back to the param until the page publishes something readable.
export const routeName = ({ meta, params }) =>
  meta.useId ? meta.nameGenerator?.() || params[meta.idParam ?? 'id'] : meta.text;

// Prepending each matched route's name to the base title labels the page and updates the
// browser tab and history entry. Pure, so the shell can re-derive it whenever the route or
// a resolved name changes; a router hook could only run once, on navigation. This is not a
// reliable route-change announcement on its own (screen readers announce title changes
// inconsistently on SPA navigation); focus is moved to the view container on each route
// change (see app.vue) to make the change perceivable.
export const buildDocumentTitle = ({ matched, params }, baseTitle) =>
  matched.reduce((title, { meta }) => {
    // The root route holds the Repositories crumb and is matched on every route, so
    // folding its text in would name the SPA root on every page, over a Rails page
    // title that already names it.
    if (meta.skipTitle) return title;

    // `meta.text` is the crumb, which the trail can abbreviate because the crumbs
    // ahead of it carry the rest; `meta.title` is where a route that reads that way
    // names itself in full.
    const text = meta.title ?? routeName({ meta, params });

    return text ? `${text} · ${title}` : title;
  }, baseTitle);

// A container image reference and a registry host both take an address rather than a
// URL, so the scheme comes off. Any scheme, not just http(s), since the origin is
// configuration and nothing constrains it to those two.
export const withoutScheme = (url) => url.replace(/^[a-z][a-z0-9+.-]*:\/\//i, '');

export const buildRegistryClientUrl = ({ clientBaseUrl, handle }) => {
  if (!clientBaseUrl || !handle) return null;

  return joinPaths(clientBaseUrl, handle);
};

// Composed rather than read, because Artifact Registry returns no URL on the repository
// resource and the origin reaches the browser as mount data.
export const buildRepositoryClientUrl = ({ clientBaseUrl, slug, format, name }) => {
  const registryUrl = buildRegistryClientUrl({ clientBaseUrl, handle: slug });
  const formatSegment = REPOSITORY_FORMAT_PATH_SEGMENTS[format];

  if (!registryUrl || !formatSegment || !name) return null;

  return joinPaths(registryUrl, formatSegment, encodeURIComponent(name));
};
