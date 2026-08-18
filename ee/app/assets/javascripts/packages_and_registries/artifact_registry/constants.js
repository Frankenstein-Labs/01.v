import dockerLogoUrl from '@gitlab/svgs/dist/illustrations/logos/docker.svg?url';
import mavenLogoUrl from '@gitlab/svgs/dist/illustrations/logos/maven.svg?url';
import npmLogoUrl from '@gitlab/svgs/dist/illustrations/logos/npm.svg?url';
import { GlFilteredSearchToken } from '@gitlab/ui';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import { __, s__ } from '~/locale';

export const NOT_FOUND_ROUTE_NAME = 'not_found';

export const PAGE_NOT_FOUND_TITLE = __('Page not found');

export const REPOSITORIES_LIST_ROUTE_NAME = 'repositories_list';

export const REPOSITORY_DETAIL_ROUTE_NAME = 'repository_detail';

export const REPOSITORY_NEW_HOSTED_ROUTE_NAME = 'repository_new_hosted';

export const REPOSITORIES_LIST_TITLE = s__('ArtifactRegistry|Repositories');

export const REPOSITORY_NEW_TITLE = s__('ArtifactRegistry|Create hosted repository');

export const REPOSITORY_EDIT_ROUTE_NAME = 'repository_edit';

export const ARTIFACT_VERSIONS_ROUTE_NAME = 'artifact_versions';

export const REPOSITORY_EDIT_TITLE = s__('ArtifactRegistry|Edit hosted repository');

// The crumb ahead of this one is the repository being edited, so the trail names the
// action alone where the document title has to name the whole page.
export const REPOSITORY_EDIT_CRUMB = __('Edit');

export const REPOSITORY_HOSTED_DESCRIPTION = s__(
  'ArtifactRegistry|A hosted repository directly hosts artifacts. You can publish artifacts to and pull them from a hosted repository.',
);

export const TYPENAME_ARTIFACT_REGISTRY = 'ArtifactRegistry';

export const TYPENAME_ARTIFACT_REGISTRY_REPOSITORY = 'ArtifactRegistryRepository';

export const TYPENAME_ARTIFACT_REGISTRY_IMAGE = 'ArtifactRegistryImage';

export const TYPENAME_ARTIFACT_REGISTRY_PACKAGE = 'ArtifactRegistryPackage';

export const TYPENAME_ARTIFACT_REGISTRY_MAVEN_PACKAGE = 'ArtifactRegistryMavenPackage';

export const TYPENAME_ARTIFACT_REGISTRY_NPM_PACKAGE = 'ArtifactRegistryNpmPackage';

export const TYPENAME_ARTIFACT_REGISTRY_VERSION = 'ArtifactRegistryVersion';

export const TYPENAME_ORGANIZATION = 'Organization';

// Kind is chosen at the entry affordance rather than in the form. Artifact Registry
// accepts only hosted in Phase 1 and answers 422 for any other kind.
export const REPOSITORY_KIND_HOSTED = 'HOSTED';

// Private only for the closed beta: Internal and Public are deferred to GA, so the
// write path offers a single value rather than narrowing the shared read enum.
export const REPOSITORY_VISIBILITY_PRIVATE = 'PRIVATE';

// Transcribed from the Artifact Registry repository contract (api/openapi/v1.yaml, as
// implemented in internal/managementapi/create.go): a name is 1 to 255 lowercase
// alphanumeric characters that may be separated by '.', '_', or '-', and must start and
// end with an alphanumeric character. The name is a path segment in the client APIs, so
// the pattern is what keeps it URL-safe. Artifact Registry remains the authority; these
// bounds only spare a round trip for input it would certainly reject.
export const REPOSITORY_NAME_PATTERN = /^[a-z0-9](?:[a-z0-9._-]*[a-z0-9])?$/;

export const REPOSITORY_NAME_MAX_LENGTH = 255;

// Transcribed from the Artifact Registry namespace contract (api/openapi/gitlab-v1.yaml),
// which states the slug rules in prose and carries no pattern to generate from.
export const REGISTRY_HANDLE_CHARSET_PATTERN = /^[a-z0-9-]+$/;

export const REGISTRY_HANDLE_BOUNDARY_PATTERN = /^[a-z0-9](?:.*[a-z0-9])?$/;

export const REGISTRY_HANDLE_MIN_LENGTH = 3;

export const REGISTRY_HANDLE_MAX_LENGTH = 63;

// Not translated: a handle is drawn from a fixed charset, so a translated one would not
// be a legal handle in every locale.
export const REGISTRY_HANDLE_PLACEHOLDER = 'my-registry';

// A status with no entry here arrives with the affordance that produces it, so its
// wording comes from design rather than being derived ahead of it.
export const REGISTRY_STATUS_INDICATIONS = {
  active: s__('ArtifactRegistry|Artifact Registry is enabled'),
  disabled: s__('ArtifactRegistry|Artifact Registry is disabled'),
};

// `status` is a string rather than an enum because Artifact Registry may add values, so an
// unlisted value reads as this rather than as a blank condition.
export const REGISTRY_STATUS_INDICATION_UNKNOWN = s__(
  'ArtifactRegistry|Artifact Registry is not available for this organization',
);

export const REGISTRY_ACTION_DISABLE = 'disable';

export const REGISTRY_ACTION_ENABLE = 'enable';

// A condition Artifact Registry imposed for security or billing reasons is not the
// organization owner's to lift, so a status absent here carries no action at all.
export const REGISTRY_STATUS_ACTIONS = {
  active: REGISTRY_ACTION_DISABLE,
  disabled: REGISTRY_ACTION_ENABLE,
};

export const REPOSITORY_DESCRIPTION_MAX_LENGTH = 1024;

// The MVP formats, mirroring the Artifact Registry repository-resource contract. The
// Docker and OCI split replaces the former single container format. Alphabetical,
// because the create form renders these in declaration order and defaults to the first.
export const REPOSITORY_FORMAT_LABELS = {
  DOCKER: s__('ArtifactRegistry|Docker'),
  MAVEN: s__('ArtifactRegistry|Maven'),
  NPM: s__('ArtifactRegistry|npm'),
  OCI: s__('ArtifactRegistry|OCI'),
};

export const REPOSITORY_FORMAT_OPTIONS = Object.entries(REPOSITORY_FORMAT_LABELS).map(
  ([value, text]) => ({ value, text }),
);

export const REPOSITORY_FORMAT_VALUES = Object.keys(REPOSITORY_FORMAT_LABELS);

export const REPOSITORY_FORMAT_DOCKER = 'DOCKER';

export const REPOSITORY_FORMAT_MAVEN = 'MAVEN';

export const REPOSITORY_FORMAT_NPM = 'NPM';

export const REPOSITORY_FORMAT_OCI = 'OCI';

export const REPOSITORY_FORMAT_CONTAINER_FAMILY = [REPOSITORY_FORMAT_DOCKER, REPOSITORY_FORMAT_OCI];

// The unfiltered default carries a sentinel value rather than null, because
// GlCollapsibleListbox reads a null selection as nothing selected and falls back to
// its placeholder. ALL is not an Artifact Registry format, so it shadows no value the
// list endpoint can filter on.
export const REPOSITORY_FORMAT_ALL = 'ALL';

export const REPOSITORY_FORMAT_FILTER_OPTIONS = [
  { value: REPOSITORY_FORMAT_ALL, text: s__('ArtifactRegistry|All formats') },
  ...REPOSITORY_FORMAT_OPTIONS,
];

// A format is absent here until its logo exists, and renders as a letter avatar in the
// meantime. OCI is the one such format: its logo waits on Linux Foundation trademark
// approval, tracked in
// https://gitlab.com/gitlab-com/legal-and-compliance/-/work_items/3607.
export const REPOSITORY_FORMAT_LOGOS = {
  MAVEN: mavenLogoUrl,
  NPM: npmLogoUrl,
  DOCKER: dockerLogoUrl,
};

// The size the list reads the logo at. 16px left the wordmark logos, which fit their
// width rather than their height, too small to read.
export const REPOSITORY_FORMAT_LOGO_SIZE_LIST = 32;

// A page heading carries the largest logo, and is the same size on every route that has
// one.
export const REPOSITORY_FORMAT_LOGO_SIZE_HEADING = 48;

// The listbox lists the formats a line of text at a time, so its logos match that line.
export const REPOSITORY_FORMAT_LOGO_SIZE_LISTBOX = 16;

// The segment a format occupies in a client URL (ADR-009). Not translated: these are
// URL path segments, not labels. Docker and OCI share `container`, because one set of
// OCI Distribution Spec endpoints serves repositories of both formats, so the segment
// names the protocol family rather than the repository's own format.
export const REPOSITORY_FORMAT_PATH_SEGMENTS = {
  DOCKER: 'container',
  MAVEN: 'maven',
  NPM: 'npm',
  OCI: 'container',
};

export const REPOSITORY_KIND_LABELS = {
  HOSTED: s__('ArtifactRegistry|Hosted'),
  VIRTUAL: s__('ArtifactRegistry|Virtual'),
  REMOTE: s__('ArtifactRegistry|Remote'),
};

export const REPOSITORY_KIND_VALUES = Object.keys(REPOSITORY_KIND_LABELS);

export const REPOSITORY_KIND_TOKEN_TYPE = 'kind';

// Type is the only token the Artifact Registry list endpoint backs. The free-text name
// search and the visibility and downloads tokens the design shows have no contract
// behind them, so the bar offers none of them.
export const REPOSITORY_KIND_TOKEN = {
  type: REPOSITORY_KIND_TOKEN_TYPE,
  title: s__('ArtifactRegistry|Type'),
  token: GlFilteredSearchToken,
  unique: true,
  operators: OPERATORS_IS,
  options: Object.entries(REPOSITORY_KIND_LABELS).map(([value, title]) => ({ value, title })),
};

// Closed beta supports private only: both public and internal grant read without a
// role assignment, which breaks closed-by-default, so ADR-021 defers them to GA.
export const REPOSITORY_VISIBILITY_LABELS = {
  PRIVATE: s__('ArtifactRegistry|Private'),
};

export const REPOSITORY_VISIBILITY_ICONS = {
  PRIVATE: 'lock',
};

export const REPOSITORY_VISIBILITY_DESCRIPTIONS = {
  PRIVATE: s__('ArtifactRegistry|Access is limited to members with explicit permissions only.'),
};

export const GRAPHQL_PAGE_SIZE = 20;

// The columns the list endpoint sorts on, keyed by table field. It also sorts on
// artifacts_count, left out because the list renders no such column.
export const REPOSITORY_SORT_COLUMNS = {
  name: 'NAME',
  downloadsCount: 'DOWNLOADS_COUNT',
  sizeBytes: 'SIZE_BYTES',
  lastUpdatedAt: 'LAST_UPDATED_AT',
};

export const REPOSITORY_SORT_VALUES = Object.values(REPOSITORY_SORT_COLUMNS).flatMap((column) => [
  `${column}_ASC`,
  `${column}_DESC`,
]);

export const REPOSITORY_SORT_DEFAULT = 'LAST_UPDATED_AT_DESC';

// Scoped to neither user nor namespace, the way the monolith's other sort keys are, so
// two accounts sharing a browser profile share a sort column.
export const REPOSITORIES_SORT_STORAGE_KEY = 'artifact-registry-repositories-sort';

// Every cell centers vertically, because the rows are as tall as their tallest cell
// and the row actions menu is taller than a line of text.
const CELL_CLASS = '!gl-align-middle';

export const REPOSITORIES_TABLE_FIELDS = [
  { key: 'format', label: s__('ArtifactRegistry|Format'), tdClass: CELL_CLASS },
  { key: 'name', label: s__('ArtifactRegistry|Name'), tdClass: CELL_CLASS, sortable: true },
  { key: 'kind', label: s__('ArtifactRegistry|Type'), tdClass: CELL_CLASS },
  {
    key: 'downloadsCount',
    label: s__('ArtifactRegistry|Downloads'),
    tdClass: CELL_CLASS,
    sortable: true,
  },
  { key: 'sizeBytes', label: s__('ArtifactRegistry|Size'), tdClass: CELL_CLASS, sortable: true },
  {
    key: 'lastUpdatedAt',
    label: s__('ArtifactRegistry|Last updated'),
    tdClass: CELL_CLASS,
    sortable: true,
  },
  {
    key: 'actions',
    // The header stays visible, per the additional-actions guidance in
    // https://design.gitlab.com/components/table#additional-actions, and is aligned with
    // the menu it names, which sits at the end of the row. `thAlignRight` rather than a
    // text-alignment class: GlTable wraps every header in a flex container, which lays
    // its label out as a flex item that `gl-text-right` cannot move.
    label: __('Actions'),
    thAlignRight: true,
    tdClass: `${CELL_CLASS} gl-text-right`,
  },
];

export const ARTIFACTS_TABLE_FIELDS = {
  DOCKER: [{ key: 'name', label: s__('ArtifactRegistry|Image'), tdClass: CELL_CLASS }],
  OCI: [{ key: 'name', label: s__('ArtifactRegistry|Image'), tdClass: CELL_CLASS }],
  MAVEN: [{ key: 'name', label: s__('ArtifactRegistry|Package'), tdClass: CELL_CLASS }],
  NPM: [
    { key: 'name', label: s__('ArtifactRegistry|Package'), tdClass: CELL_CLASS },
    { key: 'versionsCount', label: s__('ArtifactRegistry|Versions'), tdClass: CELL_CLASS },
  ],
};

export const VERSIONS_TABLE_FIELDS = [
  { key: 'version', label: s__('ArtifactRegistry|Version'), tdClass: CELL_CLASS },
  { key: 'createdAt', label: s__('ArtifactRegistry|Published'), tdClass: CELL_CLASS },
];

export const SETUP_SECTION_INSTALL = 'install';

export const SETUP_SECTION_PUBLISH = 'publish';

export const SETUP_TOOL_MAVEN = 'maven';

export const SETUP_TOOL_GRADLE_GROOVY = 'gradle_groovy';

export const SETUP_TOOL_GRADLE_KOTLIN = 'gradle_kotlin';

export const SETUP_TOOL_NPM = 'npm';

export const SETUP_TOOL_YARN = 'yarn';

export const SETUP_TOOL_PNPM = 'pnpm';

export const SETUP_TOOL_DOCKER = 'docker';

export const SETUP_TOOL_PODMAN = 'podman';

// One set of OCI Distribution Spec endpoints serves both formats, so the same clients
// reach either. Shared rather than spelled out twice, so a new container tool cannot be
// added to one format and forgotten on the other.
const CONTAINER_SETUP_TOOLS = [
  { value: SETUP_TOOL_DOCKER, text: s__('ArtifactRegistry|Docker CLI') },
  { value: SETUP_TOOL_PODMAN, text: s__('ArtifactRegistry|Podman') },
];

export const SETUP_TOOLS = {
  DOCKER: CONTAINER_SETUP_TOOLS,
  OCI: CONTAINER_SETUP_TOOLS,
  MAVEN: [
    { value: SETUP_TOOL_MAVEN, text: s__('ArtifactRegistry|Maven') },
    { value: SETUP_TOOL_GRADLE_GROOVY, text: s__('ArtifactRegistry|Gradle (Groovy)') },
    { value: SETUP_TOOL_GRADLE_KOTLIN, text: s__('ArtifactRegistry|Gradle (Kotlin)') },
  ],
  NPM: [
    { value: SETUP_TOOL_NPM, text: s__('ArtifactRegistry|npm') },
    { value: SETUP_TOOL_YARN, text: s__('ArtifactRegistry|yarn') },
    { value: SETUP_TOOL_PNPM, text: s__('ArtifactRegistry|pnpm') },
  ],
};
