import { GlAlert } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import SectionAlert from 'ee/security_orchestration/components/policy_editor/scope/section_alert.vue';
import {
  ALL_PROJECTS_IN_LINKED_GROUPS,
  ALL_PROJECTS_IN_GROUP,
  PROJECTS_WITH_FRAMEWORK,
  SPECIFIC_PROJECTS,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';

describe('SectionAlert', () => {
  let wrapper;

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMount(SectionAlert, {
      propsData,
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);

  it('renders empty wrapper by default', () => {
    createComponent();
    expect(findAlert().exists()).toBe(false);
  });

  it('does not render alert when component is not dirty', () => {
    createComponent({
      propsData: {
        projectEmpty: true,
        complianceFrameworksEmpty: true,
      },
    });

    expect(findAlert().exists()).toBe(false);
  });

  it('does not render alert when component without exceptions', () => {
    createComponent({
      propsData: {
        isDirty: true,
        projectEmpty: true,
        complianceFrameworksEmpty: true,
        projectScopeType: ALL_PROJECTS_IN_GROUP,
        isProjectsWithoutExceptions: true,
      },
    });

    expect(findAlert().exists()).toBe(false);
  });

  it('renders alert when component is dirty', () => {
    createComponent({
      propsData: {
        projectEmpty: true,
        complianceFrameworksEmpty: true,
        isDirty: true,
      },
    });

    expect(findAlert().exists()).toBe(true);
  });

  it.each`
    projectScopeType                 | expectedMessage
    ${ALL_PROJECTS_IN_GROUP}         | ${'You must select one or more projects to be excluded from this policy.'}
    ${SPECIFIC_PROJECTS}             | ${'You must select one or more projects to which this policy should apply.'}
    ${PROJECTS_WITH_FRAMEWORK}       | ${'You must select one or more compliance frameworks to which this policy should apply.'}
    ${ALL_PROJECTS_IN_LINKED_GROUPS} | ${'You must select one or more groups from this policy.'}
  `('renders correct error message', ({ projectScopeType, expectedMessage }) => {
    createComponent({
      propsData: {
        groupsEmpty: true,
        projectEmpty: true,
        complianceFrameworksEmpty: true,
        isDirty: true,
        projectScopeType,
      },
    });

    expect(findAlert().text()).toBe(expectedMessage);
  });
});
