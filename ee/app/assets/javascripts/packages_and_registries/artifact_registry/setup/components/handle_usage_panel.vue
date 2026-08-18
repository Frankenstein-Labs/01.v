<script>
import { GlButton, GlCollapse } from '@gitlab/ui';
import { artifactRegistryRepositoriesOrganizationPath } from 'ee/lib/utils/path_helpers/organizations';
import { s__, sprintf } from '~/locale';
import CodeBlock from '~/vue_shared/components/code_block.vue';
import {
  REGISTRY_HANDLE_PLACEHOLDER,
  REPOSITORY_FORMAT_DOCKER,
  REPOSITORY_FORMAT_MAVEN,
  REPOSITORY_FORMAT_NPM,
} from '../../constants';
import { buildRepositoryClientUrl, withoutScheme } from '../../utils';

const PANEL_ID = 'artifact-registry-handle-usage';

const EXAMPLE_REPOSITORY_NAME = 'my-repo';
const EXAMPLE_DOCS_REPOSITORY_NAME = 'shared-libs';
const EXAMPLE_IMAGE_REFERENCE = 'my-image:latest';

const NPM_EXAMPLE_PREFIX = '@scope:registry=';
const CI_EXAMPLE_PREFIX = 'publish:\n  script:\n    - docker push ';
const DOCKERFILE_EXAMPLE_PREFIX = 'FROM ';

export default {
  name: 'HandleUsagePanel',
  i18n: {
    toggle: s__('ArtifactRegistry|Where the registry handle appears'),
    intro: s__('ArtifactRegistry|The registry handle will appear in the following areas:'),
    ui: s__('ArtifactRegistry|GitLab UI'),
    uiUrl: s__('ArtifactRegistry|URL:'),
    clients: s__('ArtifactRegistry|Client configuration files'),
    npm: s__('ArtifactRegistry|npm (.npmrc):'),
    maven: s__('ArtifactRegistry|Maven (settings.xml):'),
    ci: s__('ArtifactRegistry|CI/CD pipelines (.gitlab-ci.yml)'),
    dockerfile: s__('ArtifactRegistry|Dockerfiles'),
    docs: s__('ArtifactRegistry|Team documentation / READMEs:'),
    docsExample: s__('ArtifactRegistry|Our internal packages are hosted at %{url}'),
  },
  components: {
    CodeBlock,
    GlButton,
    GlCollapse,
  },
  inject: ['organizationPath', 'clientBaseUrl'],
  props: {
    handle: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      expanded: false,
    };
  },
  computed: {
    // Bound as a string because a boolean `false` is dropped from the DOM rather than
    // rendered, which would leave the toggle reporting no state at all.
    ariaExpandedAttr() {
      return this.expanded ? 'true' : 'false';
    },
    displayHandle() {
      return this.handle || REGISTRY_HANDLE_PLACEHOLDER;
    },
    uiUrlExample() {
      return artifactRegistryRepositoriesOrganizationPath(
        this.organizationPath,
        this.displayHandle,
      );
    },
    npmExample() {
      const url = this.exampleRepositoryUrl(REPOSITORY_FORMAT_NPM, EXAMPLE_REPOSITORY_NAME);

      return url && `${NPM_EXAMPLE_PREFIX}${url}`;
    },
    mavenExample() {
      const url = this.exampleRepositoryUrl(REPOSITORY_FORMAT_MAVEN, EXAMPLE_REPOSITORY_NAME);

      return url && `<url>${url}</url>`;
    },
    imageReferenceExample() {
      const url = this.exampleRepositoryUrl(REPOSITORY_FORMAT_DOCKER, EXAMPLE_REPOSITORY_NAME);

      return url && `${withoutScheme(url)}/${EXAMPLE_IMAGE_REFERENCE}`;
    },
    ciExample() {
      return this.imageReferenceExample && `${CI_EXAMPLE_PREFIX}${this.imageReferenceExample}`;
    },
    dockerfileExample() {
      return (
        this.imageReferenceExample && `${DOCKERFILE_EXAMPLE_PREFIX}${this.imageReferenceExample}`
      );
    },
    docsExample() {
      const url = this.exampleRepositoryUrl(REPOSITORY_FORMAT_NPM, EXAMPLE_DOCS_REPOSITORY_NAME);

      return url && sprintf(this.$options.i18n.docsExample, { url: withoutScheme(url) }, false);
    },
    areas() {
      const { i18n } = this.$options;

      return [
        {
          term: i18n.ui,
          examples: [{ id: 'ui-url', label: i18n.uiUrl, code: this.uiUrlExample }],
        },
        {
          term: i18n.clients,
          examples: [
            { id: 'npm', label: i18n.npm, code: this.npmExample },
            { id: 'maven', label: i18n.maven, code: this.mavenExample },
          ],
        },
        { term: i18n.ci, examples: [{ id: 'ci', code: this.ciExample }] },
        { term: i18n.dockerfile, examples: [{ id: 'dockerfile', code: this.dockerfileExample }] },
        { term: i18n.docs, examples: [{ id: 'docs', code: this.docsExample }] },
      ];
    },
  },
  methods: {
    exampleRepositoryUrl(format, name) {
      return buildRepositoryClientUrl({
        clientBaseUrl: this.clientBaseUrl,
        slug: this.displayHandle,
        format,
        name,
      });
    },
  },
  panelId: PANEL_ID,
};
</script>

<template>
  <div
    class="gl-mb-5 gl-flex gl-flex-col gl-gap-3 gl-rounded-base gl-border-1 gl-border-solid gl-border-default gl-bg-default gl-p-4"
  >
    <gl-button
      block
      variant="link"
      :icon="expanded ? 'chevron-down' : 'chevron-right'"
      button-text-classes="gl-grow gl-text-left gl-font-bold gl-text-default !gl-whitespace-normal"
      :aria-expanded="ariaExpandedAttr"
      :aria-controls="$options.panelId"
      data-testid="handle-usage-toggle"
      @click="expanded = !expanded"
    >
      {{ $options.i18n.toggle }}
    </gl-button>

    <gl-collapse :id="$options.panelId" :visible="expanded">
      <div class="gl-flex gl-flex-col gl-gap-5 gl-px-6">
        <p class="gl-mb-0 gl-text-subtle">{{ $options.i18n.intro }}</p>

        <dl class="gl-m-0 gl-flex gl-flex-col gl-gap-5">
          <div v-for="area in areas" :key="area.term" class="gl-flex gl-flex-col gl-gap-2">
            <dt class="gl-font-bold">{{ area.term }}</dt>
            <dd
              v-for="example in area.examples"
              :key="example.id"
              class="gl-m-0 gl-flex gl-flex-col gl-gap-2"
            >
              <span v-if="example.label" class="gl-text-subtle">{{ example.label }}</span>
              <code-block
                v-if="example.code"
                class="gl-border-1 gl-border-solid gl-border-subtle !gl-bg-subtle gl-p-3"
                :code="example.code"
                :data-testid="`handle-usage-${example.id}`"
              />
            </dd>
          </div>
        </dl>
      </div>
    </gl-collapse>
  </div>
</template>
