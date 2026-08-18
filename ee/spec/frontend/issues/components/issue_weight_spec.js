import { shallowMount } from '@vue/test-utils';
import IssueWeight from 'ee_component/issues/components/issue_weight.vue';
import WorkItemAttribute from '~/vue_shared/components/work_item_attribute.vue';

function mountIssueWeight(propsData) {
  return shallowMount(IssueWeight, {
    propsData,
  });
}

describe('IssueWeight', () => {
  let wrapper;
  const findWorkItemAttribute = () => wrapper.findComponent(WorkItemAttribute);

  describe('weight text', () => {
    it('shows 0 when weight is 0', () => {
      wrapper = mountIssueWeight({
        weight: 0,
      });

      expect(findWorkItemAttribute().props('title')).toBe('0');
    });

    it('shows 5 when weight is 5', () => {
      wrapper = mountIssueWeight({
        weight: 5,
      });

      expect(findWorkItemAttribute().props('title')).toBe('5');
    });
  });

  it('renders a button', () => {
    wrapper = mountIssueWeight({
      weight: 2,
    });

    expect(findWorkItemAttribute().props('wrapperComponent')).toBe('button');
  });
});
