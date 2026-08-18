import { GlCollapsibleListbox } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ToolSelector from 'ee/packages_and_registries/artifact_registry/repositories/detail/setup_instructions/tool_selector.vue';

describe('ArtifactRegistrySetupToolSelector', () => {
  let wrapper;

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findToolLabels = () =>
    findListbox()
      .props('items')
      .map(({ text }) => text);

  const createComponent = ({ format = 'MAVEN', selected = 'maven' } = {}) => {
    wrapper = mountExtended(ToolSelector, { propsData: { format, selected } });
  };

  describe('the tools a format offers', () => {
    it.each([
      ['DOCKER', ['Docker CLI', 'Podman']],
      ['OCI', ['Docker CLI', 'Podman']],
      ['MAVEN', ['Maven', 'Gradle (Groovy)', 'Gradle (Kotlin)']],
      ['NPM', ['npm', 'yarn', 'pnpm']],
    ])('gives a %s repository exactly %j', (format, tools) => {
      createComponent({ format });

      expect(findToolLabels()).toEqual(tools);
    });

    it('renders nothing for a format it carries no tools for', () => {
      createComponent({ format: 'CONAN' });

      expect(findListbox().exists()).toBe(false);
    });
  });

  it('shows the tool the caller holds as selected', () => {
    createComponent({ format: 'NPM', selected: 'pnpm' });

    expect(findListbox().props('selected')).toBe('pnpm');
  });

  it.each([
    ['MAVEN', 'gradle_kotlin', 'Gradle (Kotlin)'],
    ['NPM', 'yarn', 'yarn'],
    ['DOCKER', 'podman', 'Podman'],
  ])('names the selected %s tool on the toggle, not a placeholder', (format, selected, text) => {
    createComponent({ format, selected });

    expect(findListbox().find('button').text()).toBe(text);
  });

  it('hands the chosen tool back, so the caller owns the selection', () => {
    createComponent();

    findListbox().vm.$emit('select', 'gradle_kotlin');

    expect(wrapper.emitted('select')).toEqual([['gradle_kotlin']]);
  });

  it('is named by a label of its own, because the toggle only shows the tool', () => {
    createComponent();

    const labelId = findListbox().props('toggleAriaLabelledBy');

    expect(wrapper.find(`#${labelId}`).text()).toBe('Build tool');
  });
});
