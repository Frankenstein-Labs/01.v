import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import {
  SETUP_SECTION_INSTALL,
  SETUP_SECTION_PUBLISH,
} from 'ee/packages_and_registries/artifact_registry/constants';
import SetupSnippets from 'ee/packages_and_registries/artifact_registry/repositories/detail/setup_instructions/setup_snippets.vue';
import SnippetCodeBlock from 'ee/packages_and_registries/artifact_registry/repositories/detail/setup_instructions/snippet_code_block.vue';
import { CLIENT_BASE_URL, SLUG } from '../../../mock_data';

describe('ArtifactRegistrySetupSnippets', () => {
  let wrapper;

  const findSections = () => wrapper.findAllByTestId('setup-section');
  const findHeadings = () => wrapper.findAll('h3').wrappers.map((h) => h.text());
  const findBlocks = () => wrapper.findAllComponents(SnippetCodeBlock);
  const findSnippets = () => findBlocks().wrappers.map((b) => b.props('snippet'));

  const createComponent = ({
    format = 'MAVEN',
    tool = 'maven',
    section = SETUP_SECTION_INSTALL,
    provide = {},
  } = {}) => {
    wrapper = mountExtended(SetupSnippets, {
      propsData: { name: 'my-repository', format, tool, section },
      provide: { slug: SLUG, clientBaseUrl: CLIENT_BASE_URL, ...provide },
    });
  };

  describe('the structure it renders', () => {
    beforeEach(() => createComponent());

    it('renders the tab content and the setup section it always carries', () => {
      expect(findSections()).toHaveLength(2);
    });

    it('names only the setup section, because the tab already names the content above it', () => {
      expect(findHeadings()).toEqual(['Repository setup']);
    });

    it('pairs every snippet with the prose that introduces it', () => {
      expect(wrapper.findAll('p')).toHaveLength(findBlocks().length);
    });

    it('marks a filename in the prose as code rather than as prose', () => {
      expect(wrapper.findAll('code').wrappers.map((c) => c.text())).toContain('pom.xml');
    });
  });

  describe('the snippets', () => {
    it('composes them from this repository’s own client URL', () => {
      createComponent({ section: SETUP_SECTION_PUBLISH });

      expect(findSnippets().join('\n')).toContain(
        'https://artifact-registry.example.com/acme/maven/my-repository',
      );
    });

    it('names what each copy button copies, because the button shows only an icon', () => {
      createComponent();

      expect(findBlocks().wrappers.map((b) => b.props('copyText'))).toEqual([
        'Copy the dependency declaration',
        'Copy the install command',
        'Copy the repository configuration',
        'Copy the authentication configuration',
      ]);
    });

    it('names every copy button in a view distinctly, so they can be told apart', () => {
      createComponent();
      const names = findBlocks().wrappers.map((b) => b.props('copyText'));

      expect(new Set(names).size).toBe(names.length);
    });

    it('swaps the snippets when the tool changes', async () => {
      createComponent({ section: SETUP_SECTION_PUBLISH });
      const before = findSnippets();

      await wrapper.setProps({ tool: 'gradle_kotlin' });

      expect(findSnippets()).not.toEqual(before);
      expect(findSnippets().join()).toContain('HttpHeaderCredentials::class');
    });

    it('swaps the snippets when the section changes', async () => {
      createComponent();

      expect(findSnippets()).toContain('mvn install');

      await wrapper.setProps({ section: SETUP_SECTION_PUBLISH });
      await nextTick();

      expect(findSnippets()).toContain('mvn deploy');
    });
  });

  describe('when the instance configures no Artifact Registry origin', () => {
    it('renders no guidance at all, rather than commands with a hole in them', () => {
      createComponent({ provide: { clientBaseUrl: '' } });

      expect(findSections()).toHaveLength(0);
      expect(findBlocks()).toHaveLength(0);
    });
  });
});
