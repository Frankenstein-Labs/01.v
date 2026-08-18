import { GlDrawer } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import {
  SETUP_SECTION_INSTALL,
  SETUP_SECTION_PUBLISH,
} from 'ee/packages_and_registries/artifact_registry/constants';
import SetupDrawer from 'ee/packages_and_registries/artifact_registry/repositories/detail/setup_instructions/setup_drawer.vue';
import SetupSnippets from 'ee/packages_and_registries/artifact_registry/repositories/detail/setup_instructions/setup_snippets.vue';
import ToolSelector from 'ee/packages_and_registries/artifact_registry/repositories/detail/setup_instructions/tool_selector.vue';
import { CLIENT_BASE_URL, SLUG } from '../../../mock_data';

jest.mock('~/lib/utils/dom_utils', () => ({
  getContentWrapperHeight: () => '123',
}));

describe('ArtifactRegistrySetupDrawer', () => {
  let wrapper;

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findTitle = () => wrapper.find('h2');
  const findTabLinks = () => wrapper.findAll('[role="tab"]').wrappers.map((tab) => tab.text());
  const findSelector = () => wrapper.findComponent(ToolSelector);
  const findSnippets = () => wrapper.findAllComponents(SetupSnippets);
  const MountingPortalStub = {
    name: 'MountingPortalStub',
    template: '<div><slot /></div>',
  };

  const createComponent = ({ format = 'MAVEN', open = true } = {}) => {
    wrapper = mountExtended(SetupDrawer, {
      propsData: { name: 'my-repository', format, open },
      provide: { slug: SLUG, clientBaseUrl: CLIENT_BASE_URL },
      stubs: { MountingPortal: MountingPortalStub },
    });
  };

  describe('the drawer it renders', () => {
    beforeEach(() => createComponent());

    it('wires the drawer the way the layout requires', () => {
      expect(findDrawer().props()).toMatchObject({
        open: true,
        headerHeight: '123',
        headerSticky: true,
        zIndex: 252,
      });
    });

    it('names itself, because a drawer carries no accessible name of its own', () => {
      expect(findTitle().text()).toBe('Setup instructions');
      expect(findDrawer().attributes('aria-labelledby')).toBe(findTitle().attributes('id'));
    });

    it('closes when the drawer asks to be closed', () => {
      findDrawer().vm.$emit('close');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });

  describe('the tabs', () => {
    beforeEach(() => createComponent());

    it('offers Install before Publish', () => {
      expect(findTabLinks()).toEqual(['Install', 'Publish']);
    });

    it('keeps the tablist to tabs, so the tool selector is not an invalid child of it', () => {
      expect(wrapper.find('[role="tablist"]').findComponent(ToolSelector).exists()).toBe(false);
      expect(findSelector().exists()).toBe(true);
    });

    it('gives each tab the section it names, for this repository', () => {
      expect(findSnippets().wrappers.map((s) => s.props())).toEqual([
        expect.objectContaining({
          name: 'my-repository',
          format: 'MAVEN',
          section: SETUP_SECTION_INSTALL,
        }),
        expect.objectContaining({
          name: 'my-repository',
          format: 'MAVEN',
          section: SETUP_SECTION_PUBLISH,
        }),
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

    it('applies a chosen tool to both tabs at once', async () => {
      createComponent({ format: 'NPM' });

      findSelector().vm.$emit('select', 'pnpm');
      await nextTick();

      expect(findSnippets().wrappers.map((s) => s.props('tool'))).toEqual(['pnpm', 'pnpm']);
    });

    it('falls back rather than keeping a tool the new format cannot offer', async () => {
      createComponent({ format: 'DOCKER' });

      findSelector().vm.$emit('select', 'podman');
      await nextTick();
      await wrapper.setProps({ format: 'MAVEN' });

      expect(findSelector().props('selected')).toBe('maven');
    });

    it('starts again from the default each time the drawer opens', async () => {
      createComponent({ format: 'NPM' });

      findSelector().vm.$emit('select', 'yarn');
      await nextTick();

      await wrapper.setProps({ open: false });
      await wrapper.setProps({ open: true });

      expect(findSelector().props('selected')).toBe('npm');
    });
  });
});
