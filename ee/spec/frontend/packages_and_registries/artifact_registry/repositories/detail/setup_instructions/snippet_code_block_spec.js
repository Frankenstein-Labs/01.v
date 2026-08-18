import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SnippetCodeBlock from 'ee/packages_and_registries/artifact_registry/repositories/detail/setup_instructions/snippet_code_block.vue';
import CodeBlock from '~/vue_shared/components/code_block.vue';
import SimpleCopyButton from '~/vue_shared/components/simple_copy_button.vue';

describe('ArtifactRegistrySnippetCodeBlock', () => {
  let wrapper;

  const SNIPPET =
    'docker pull artifact-registry.example.com/acme/container/my-repository/image:tag';

  const findSnippet = () => wrapper.findComponent(CodeBlock);
  const findCopyButton = () => wrapper.findComponent(SimpleCopyButton);

  const createComponent = ({ snippet = SNIPPET, copyText = 'Copy command' } = {}) => {
    wrapper = shallowMountExtended(SnippetCodeBlock, { propsData: { snippet, copyText } });
  };

  beforeEach(() => createComponent());

  it('renders the snippet verbatim, so it can be copied and run', () => {
    expect(findSnippet().props('code')).toBe(SNIPPET);
  });

  it('wraps a long command rather than letting it run out of the column', () => {
    expect(findSnippet().classes()).toContain('gl-whitespace-pre-wrap');
  });

  it('carries the default border the design asks for, which CodeBlock leaves off', () => {
    expect(findSnippet().classes()).toEqual(
      expect.arrayContaining(['gl-border-1', 'gl-border-solid', 'gl-border-default']),
    );
  });

  it('copies exactly what it renders', () => {
    expect(findCopyButton().props('text')).toBe(SNIPPET);
  });

  it('names what it copies, which is the button’s only accessible name', () => {
    expect(findCopyButton().props('title')).toBe('Copy command');
  });
});
