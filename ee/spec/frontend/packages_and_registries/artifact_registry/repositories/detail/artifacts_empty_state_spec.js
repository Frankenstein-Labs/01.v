import { GlEmptyState } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ArtifactsEmptyState from 'ee/packages_and_registries/artifact_registry/repositories/detail/artifacts_empty_state.vue';
import SnippetCodeBlock from 'ee/packages_and_registries/artifact_registry/repositories/detail/setup_instructions/snippet_code_block.vue';
import ToolSelector from 'ee/packages_and_registries/artifact_registry/repositories/detail/setup_instructions/tool_selector.vue';
import { CLIENT_BASE_URL, SLUG } from '../../mock_data';

describe('ArtifactRegistryArtifactsEmptyState', () => {
  let wrapper;

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findSetup = () => wrapper.findByTestId('empty-state-setup');
  const findSelector = () => wrapper.findComponent(ToolSelector);
  const findSteps = () => wrapper.findAllByTestId('empty-state-step');
  const findBlocks = () => wrapper.findAllComponents(SnippetCodeBlock);
  const findSnippets = () => findBlocks().wrappers.map((b) => b.props('snippet'));

  const createComponent = ({ format = 'MAVEN', provide = {} } = {}) => {
    wrapper = mountExtended(ArtifactsEmptyState, {
      propsData: { name: 'my-repository', format },
      provide: { slug: SLUG, clientBaseUrl: CLIENT_BASE_URL, ...provide },
    });
  };

  describe('the heading and support text', () => {
    it.each([
      ['MAVEN', 'packages', 'package'],
      ['NPM', 'packages', 'package'],
      ['DOCKER', 'images', 'image'],
      ['OCI', 'images', 'image'],
    ])('names what a %s repository holds', (format, plural, singular) => {
      createComponent({ format });

      expect(findEmptyState().props('title')).toBe(`There are no ${plural} in this repository yet`);
      expect(findEmptyState().props('description')).toBe(
        `Publish your first ${singular} to get started.`,
      );
    });

    it('renders the illustration', () => {
      createComponent();

      expect(findEmptyState().props('svgPath')).toContain('empty-package');
    });

    it('renders no documentation link', () => {
      createComponent();

      expect(wrapper.findAll('a')).toHaveLength(0);
    });
  });

  describe('the setup steps', () => {
    beforeEach(() => createComponent());

    it('renders one numbered list under a single heading', () => {
      expect(findSetup().find('ol').exists()).toBe(true);
      expect(
        findSetup()
          .findAll('h3')
          .wrappers.map((h) => h.text()),
      ).toEqual(['CLI commands']);
    });

    it('sets the repository up first and publishes last, the order the steps are performed in', () => {
      expect(findSteps().wrappers.map((s) => s.find('p').text())).toEqual([
        "If you haven't already, add the configuration below to your pom.xml file:",
        'Authenticate with a token in your settings.xml file:',
        'Add this to your pom.xml file:',
        'Publish command:',
      ]);
    });

    it('keeps every snippet inside the step it belongs to', () => {
      findSteps().wrappers.forEach((step) => {
        expect(step.findAllComponents(SnippetCodeBlock)).toHaveLength(1);
      });
    });

    it('renders the publish snippets', () => {
      expect(findSnippets()).toContain('mvn deploy');
    });

    it.each([
      ['MAVEN', 4],
      ['NPM', 2],
      ['DOCKER', 2],
      ['OCI', 2],
    ])('gives a %s repository the steps its format needs', (format, steps) => {
      createComponent({ format });

      expect(findSteps()).toHaveLength(steps);
    });
  });

  describe('the snippets', () => {
    it('composes them from this repository’s own client URL', () => {
      createComponent();

      expect(findSnippets().join('\n')).toContain(
        'https://artifact-registry.example.com/acme/maven/my-repository',
      );
    });

    it.each(['MAVEN', 'NPM', 'DOCKER', 'OCI'])(
      'leaves a %s repository a token placeholder and never a credential',
      (format) => {
        createComponent({ format });

        // eslint-disable-next-line no-template-curly-in-string
        expect(findSnippets().join('\n')).toContain('${GITLAB_TOKEN}');
      },
    );

    it('names what each copy button copies', () => {
      createComponent({ format: 'DOCKER' });

      expect(findBlocks().wrappers.map((b) => b.props('copyText'))).toEqual([
        'Copy the sign-in command',
        'Copy the push command',
      ]);
    });
  });

  describe('the tool selector', () => {
    it.each([
      ['MAVEN', 'maven'],
      ['NPM', 'npm'],
      ['DOCKER', 'docker'],
      ['OCI', 'docker'],
    ])('starts a %s repository on its first tool', (format, tool) => {
      createComponent({ format });

      expect(findSelector().props()).toMatchObject({ format, selected: tool });
    });

    it('swaps the steps when another tool is chosen', async () => {
      createComponent({ format: 'NPM' });

      expect(findSnippets()).toContain('npm publish');

      findSelector().vm.$emit('select', 'pnpm');
      await nextTick();

      expect(findSnippets()).toContain('pnpm publish');
    });

    it('falls back rather than keeping a tool the new format cannot offer', async () => {
      createComponent({ format: 'DOCKER' });

      findSelector().vm.$emit('select', 'podman');
      await nextTick();
      await wrapper.setProps({ format: 'MAVEN' });

      expect(findSelector().props('selected')).toBe('maven');
    });
  });

  describe('when the instance configures no Artifact Registry origin', () => {
    beforeEach(() => createComponent({ provide: { clientBaseUrl: '' } }));

    it('still shows the empty state', () => {
      expect(findEmptyState().props('title')).toBe('There are no packages in this repository yet');
    });

    it('renders no setup steps', () => {
      expect(findSetup().exists()).toBe(false);
      expect(findSteps()).toHaveLength(0);
    });
  });
});
