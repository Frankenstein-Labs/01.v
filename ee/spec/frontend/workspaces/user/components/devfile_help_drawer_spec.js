import { GlButton, GlSprintf, GlDrawer } from '@gitlab/ui';
import DevfileHelpDrawer from 'ee/workspaces/user/components/devfile_help_drawer.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import Markdown from '~/vue_shared/components/markdown/non_gfm_markdown.vue';

describe('workspaces/user/components/devfile_help_drawer', () => {
  let wrapper;
  const drawerZIndex = 99;

  const buildWrapper = () => {
    wrapper = shallowMountExtended(DevfileHelpDrawer, {
      propsData: {
        drawerZIndex,
      },
      stubs: {
        GlSprintf,
        GlButton,
        GlDrawer,
      },
      provide: {
        defaultDevfile: 'mock-devfile-value',
      },
    });
  };

  const findSprintfComponent = () => wrapper.findComponent(GlSprintf);
  const findOpenDrawerButton = () => wrapper.findComponent(GlButton);
  const findDrawerComponent = () => wrapper.findComponent(GlDrawer);
  const findMarkdownComponent = () => wrapper.findComponent(Markdown);

  beforeEach(() => {
    buildWrapper();
  });

  it('renders GlSprintf', () => {
    const sprintf = findSprintfComponent();

    expect(sprintf.exists()).toBe(true);
  });

  it('renders the GlButton inside GlSprintf slot', () => {
    const button = findOpenDrawerButton();

    expect(button.exists()).toBe(true);
    expect(button.text()).toBe('Gitlab default devfile');
  });

  it('opens drawer when clicking the link', async () => {
    const button = findOpenDrawerButton();
    await button.vm.$emit('click');

    expect(findDrawerComponent().props('open')).toBe(true);
  });

  it('closes drawer when close button is clicked', async () => {
    const button = findOpenDrawerButton();
    await button.vm.$emit('click');

    const drawer = findDrawerComponent();
    await drawer.vm.$emit('close');

    expect(findDrawerComponent().props('open')).toBe(false);
  });

  it('renders the correct drawer texts', async () => {
    const drawer = findDrawerComponent();

    await findOpenDrawerButton().vm.$emit('click');

    expect(wrapper.findByTestId('drawer-title').text()).toContain('GitLab devfile');

    expect(drawer.text()).toContain(
      'A devfile is a file that defines a development environment by specifying the necessary tools, languages, runtimes, and other components for a GitLab project.',
    );

    expect(drawer.text()).toContain(
      'When no devfile is provided, the GitLab default devfile will be used.',
    );

    expect(drawer.text()).toContain(
      'Workspaces have built-in support for devfiles. The default location is .devfile.yaml, but you can also use a custom location. The devfile is used to automatically configure the development environment with the defined specifications.',
    );

    const markdownTitle = wrapper.findByTestId('secondary-title');
    expect(markdownTitle.exists()).toBe(true);
    expect(markdownTitle.text()).toBe('GitLab default devfile contents');
  });

  it('renders markdown', async () => {
    await findOpenDrawerButton().vm.$emit('click');

    const markdown = findMarkdownComponent();

    expect(markdown.exists()).toBe(true);
    expect(markdown.props('markdown')).toBe('```yaml\nmock-devfile-value\n```');
  });
});
