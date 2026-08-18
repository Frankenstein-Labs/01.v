import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EditorLayoutCollapseHeader from 'ee/security_orchestration/components/policy_editor/editor_layout_collapse_header.vue';

describe('EditorLayoutCollapseHeader', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(EditorLayoutCollapseHeader, {
      propsData,
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findHeader = () => wrapper.findByTestId('header');
  const findResetButton = () => wrapper.findComponentByTestId('reset-button');

  it('renders header with collapse button on left side', () => {
    createComponent({
      header: 'header',
    });

    expect(findHeader().text()).toBe('header');
    expect(findButton().props('icon')).toBe('chevron-double-lg-left');
    expect(findButton().props('category')).toBe('tertiary');
  });

  it('renders header with collapse button on right side', () => {
    createComponent({
      header: 'header',
      isRight: true,
    });

    expect(findHeader().text()).toBe('header');
    expect(findButton().props('icon')).toBe('chevron-double-lg-right');
    expect(findButton().props('category')).toBe('tertiary');
  });

  it('renders collapsed state', () => {
    createComponent({
      header: 'header',
      collapsed: true,
    });

    expect(findHeader().exists()).toBe(false);
    expect(findButton().props('icon')).toBe('chevron-double-lg-right');
  });

  it('emits toggle header event', () => {
    createComponent({
      header: 'header',
    });

    findButton().vm.$emit('click');

    expect(wrapper.emitted('toggle')).toEqual([[true]]);
  });

  it('renders reset button', () => {
    createComponent({
      header: 'header',
      hasResetButton: true,
    });

    expect(findResetButton().exists()).toBe(true);
    expect(findResetButton().props('icon')).toBe('redo');

    findResetButton().vm.$emit('click');

    expect(wrapper.emitted('reset-size')).toHaveLength(1);
  });
});
