import { GlPopover, GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import PolicyPopover from 'ee/security_orchestration/components/policy_popover.vue';

describe('PolicyPopover', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMount(PolicyPopover, {
      propsData: {
        title: 'title',
        content: 'Test content %{linkStart}Learn more%{linkEnd}.',
        href: 'href',
        target: 'test-target',
        ...propsData,
      },
      stubs: {
        GlSprintf,
        HelpIcon,
      },
    });
  };

  const findGlPopover = () => wrapper.findComponent(GlPopover);
  const findLink = () => wrapper.findComponent(GlLink);
  const findIcon = () => wrapper.findComponent(HelpIcon);

  it('should render popover with default trigger', () => {
    createComponent();

    expect(findGlPopover().props('title')).toBe('title');
    expect(findGlPopover().props('target')).toBe('test-target');
    expect(findGlPopover().props('showCloseButton')).toBe(true);
    expect(findLink().attributes('href')).toBe('href');
    expect(findIcon().attributes('name')).toBe('question-o');
  });

  it('can hide popover', () => {
    createComponent({
      propsData: {
        showPopover: false,
      },
    });

    expect(findGlPopover().exists()).toBe(false);
  });

  it('can hide popover close button', () => {
    createComponent({
      propsData: {
        showCloseButton: false,
      },
    });

    expect(findGlPopover().props('showCloseButton')).toBe(false);
  });

  it('hides link when href is not provided', () => {
    createComponent({
      propsData: {
        href: undefined,
      },
    });

    expect(findLink().exists()).toBe(false);
  });

  it('does not render link if it is not provided in template', () => {
    createComponent({
      propsData: {
        content: 'Test content. Learn more.',
      },
    });

    expect(findLink().exists()).toBe(false);
  });
});
