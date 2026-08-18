import { GlSprintf, GlCollapsibleListbox, GlIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import SuffixSelector from 'ee/security_orchestration/components/policy_editor/pipeline_execution/suffix_selector.vue';
import {
  SUFFIX_ON_CONFLICT,
  SUFFIX_NEVER,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';

describe('SuffixEditor', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(SuffixSelector, {
      propsData,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findDropDown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findGlIcon = () => wrapper.findComponent(GlIcon);

  it('renders suffix dropdown', () => {
    createComponent();

    expect(wrapper.text()).toBe('Add job name suffix');
    expect(findDropDown().exists()).toBe(true);
    expect(findDropDown().props('selected')).toBe(SUFFIX_ON_CONFLICT);
    expect(findGlIcon().attributes('title')).toBe(
      'Add a numeric suffix to ensure unique job names.',
    );
  });

  it('renders selected suffix', () => {
    createComponent({ suffix: SUFFIX_NEVER });

    expect(findDropDown().props('toggleText')).toBe('Never');
    expect(findDropDown().props('selected')).toBe(SUFFIX_NEVER);
  });

  it('selects suffix strategy', () => {
    createComponent();

    findDropDown().vm.$emit('select', SUFFIX_NEVER);

    expect(wrapper.emitted('update')).toEqual([['never']]);
  });
});
