import { GlButton, GlCard, GlSprintf, GlLink } from '@gitlab/ui';
import NewFrameworkSuccess from 'ee/compliance_dashboard/components/frameworks_report/wizard/new_framework_success.vue';
import {
  ROUTE_EDIT_FRAMEWORK,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
} from 'ee/compliance_dashboard/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('NewFrameworkSuccess', () => {
  let wrapper;
  const groupSecurityPoliciesPath = '/-/security/policies';
  const $router = {
    push: jest.fn(),
  };

  const findTitle = () => wrapper.find('h1');
  const findIllustration = () => wrapper.find('img');
  const findCtas = () => wrapper.findAllComponents(GlButton);
  const findPoliciesCard = () => wrapper.findByTestId('policies-card');
  const findProjectsCard = () => wrapper.findByTestId('projects-card');

  const createComponent = (provideData = {}) => {
    return shallowMountExtended(NewFrameworkSuccess, {
      provide: {
        groupSecurityPoliciesPath,
        ...provideData,
      },
      mocks: {
        $route: {
          query: { id: '123' },
        },
        $router,
      },
      stubs: {
        GlSprintf,
        GlCard,
      },
    });
  };

  beforeEach(() => {
    wrapper = createComponent();
  });
  it('renders alt for the illustration', () => {
    expect(findIllustration().attributes('alt')).toBe('All todos done.');
  });

  it('displays the correct title', () => {
    expect(findTitle().text()).toBe('Compliance framework created!');
  });

  describe('CTAs', () => {
    it('renders Back to compliance center first', () => {
      expect(findCtas().at(0).text()).toBe('Back to compliance center');
    });

    it('navigates to compliance center when first CTA is clicked', () => {
      findCtas().at(0).vm.$emit('click');
      expect($router.push).toHaveBeenCalledWith({ name: ROUTE_FRAMEWORKS, query: { id: '123' } });
    });

    it('renders Edit framework second', () => {
      expect(findCtas().at(1).text()).toBe('Edit framework');
    });

    it('navigates to Edit form when second CTA is clicked', () => {
      findCtas().at(1).vm.$emit('click');
      expect($router.push).toHaveBeenCalledWith({
        name: ROUTE_EDIT_FRAMEWORK,
        params: { id: '123' },
      });
    });
  });

  it('renders two gl-card components', () => {
    expect(wrapper.findAllComponents(GlCard)).toHaveLength(2);
  });

  describe('policies card', () => {
    it('renders correct header', () => {
      expect(findPoliciesCard().find('h3').text()).toBe('Scope policies');
    });

    it('renders the correct link for security policies', () => {
      const policyLink = findPoliciesCard().findComponent(GlLink);
      expect(policyLink.attributes('href')).toBe('/-/security/policies');
    });
  });

  describe('projects card', () => {
    it('renders correct header', () => {
      expect(findProjectsCard().find('h3').text()).toBe('Apply to projects');
    });

    it('navigates to projects report when projects link is clicked', () => {
      const link = findProjectsCard().findComponent(GlLink);
      link.vm.$emit('click');
      expect($router.push).toHaveBeenCalledWith({ name: ROUTE_PROJECTS });
    });
  });
});
