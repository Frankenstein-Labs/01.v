import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import EmptyState from 'ee/security_orchestration/components/policies/empty_state.vue';

describe('EmptyState component', () => {
  let wrapper;

  const findEmptyFilterState = () => wrapper.findByTestId('empty-filter-state');
  const findEmptyListState = () => wrapper.findByTestId('empty-list-state');

  const createComponent = ({
    disableScanPolicyUpdate = false,
    hasExistingPolicies = false,
    hasPolicyProject = false,
    namespaceType = NAMESPACE_TYPES.PROJECT,
  } = {}) => {
    wrapper = shallowMountExtended(EmptyState, {
      propsData: {
        hasExistingPolicies,
        hasPolicyProject,
      },
      provide: {
        disableScanPolicyUpdate,
        emptyFilterSvgPath: 'path/to/filter/svg',
        emptyListSvgPath: 'path/to/list/svg',
        namespaceType,
        newPolicyPath: 'path/to/new/policy',
      },
      stubs: { GlSprintf },
    });
  };

  it.each`
    title                                        | findComponent           | state    | hasExistingPolicies
    ${'does not display the empty filter state'} | ${findEmptyFilterState} | ${false} | ${false}
    ${'does display the empty list state'}       | ${findEmptyListState}   | ${true}  | ${false}
    ${'does display the empty filter state'}     | ${findEmptyFilterState} | ${true}  | ${true}
    ${'does not display the empty list state'}   | ${findEmptyListState}   | ${false} | ${true}
  `('$title', ({ hasExistingPolicies, findComponent, state }) => {
    createComponent({ hasExistingPolicies });
    expect(findComponent().exists()).toBe(state);
  });

  it('displays the correct empty list state when there is not a policy project', () => {
    createComponent();
    expect(findEmptyListState().text()).toContain(
      'This project is not linked to a security policy project. Create a policy, which also creates and links a security policy project. Alternatively, link this project to an existing security policy project.',
    );
  });

  it('displays the correct empty list state when there is a policy project', () => {
    createComponent({ hasPolicyProject: true });
    expect(findEmptyListState().text()).toContain(
      'This project does not contain any security policies.',
    );
  });

  it.each`
    title                                                   | namespaceType
    ${'does display the correct description for a project'} | ${NAMESPACE_TYPES.PROJECT}
    ${'does display the correct description for a group'}   | ${NAMESPACE_TYPES.GROUP}
  `('$title', ({ namespaceType }) => {
    createComponent({ namespaceType });
    expect(findEmptyListState().text()).toContain(namespaceType);
  });

  it('does display the "New policy" button for non-owners', () => {
    createComponent();
    expect(findEmptyListState().attributes('primarybuttontext')).toBe('New policy');
  });

  it('does not display the "New policy" button for non-owners', () => {
    createComponent({ disableScanPolicyUpdate: true });
    expect(findEmptyListState().attributes('primarybuttontext')).toBe('');
  });
});
