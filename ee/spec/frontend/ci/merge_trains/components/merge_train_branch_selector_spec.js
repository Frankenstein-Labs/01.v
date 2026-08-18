import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MergeTrainBranchSelector from 'ee/ci/merge_trains/components/merge_train_branch_selector.vue';
import RefSelector from '~/vue_shared/components/ref/components/ref_selector.vue';

describe('MergeTrainBranchFilter', () => {
  let wrapper;

  const defaultProps = {
    selectedBranch: 'master',
  };

  const createComponent = (props = defaultProps) => {
    wrapper = shallowMountExtended(MergeTrainBranchSelector, {
      provide: {
        projectId: '1',
      },
      propsData: {
        ...props,
      },
    });
  };

  const findRefSelector = () => wrapper.findComponent(RefSelector);

  it('renders ref selector and text', () => {
    createComponent();

    expect(findRefSelector().exists()).toBe(true);
    expect(wrapper.text()).toContain('Filter by target branch');
  });

  it('sets default ref selector value and project id', () => {
    createComponent();

    expect(findRefSelector().props('value')).toBe(defaultProps.selectedBranch);
    expect(findRefSelector().props('projectId')).toBe('1');
  });

  it('emits branch-changed event with selected branch', () => {
    createComponent();

    findRefSelector().vm.$emit('input', 'dev');

    expect(wrapper.emitted()).toEqual({ 'branch-changed': [['dev']] });
  });
});
