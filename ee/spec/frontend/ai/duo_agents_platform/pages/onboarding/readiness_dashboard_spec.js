import { mountExtended } from 'helpers/vue_test_utils_helper';
import ReadinessDashboard from 'ee/ai/duo_agents_platform/pages/onboarding/readiness_dashboard.vue';
import ReadinessBanner from 'ee/ai/duo_agents_platform/pages/onboarding/components/readiness_banner.vue';
import InitializerSection from 'ee/ai/duo_agents_platform/pages/onboarding/components/initializer_section.vue';
import {
  PROJECT_STATE_READY,
  PROJECT_STATE_ENVIRONMENT_PROBLEM,
  PROJECT_STATE_NOT_ENABLED,
} from 'ee/ai/duo_agents_platform/pages/onboarding/constants';

const INITIALIZERS = [
  { event_type: 'init_project_context' },
  { event_type: 'init_execution_env' },
  { event_type: 'improve_ci' },
  { event_type: 'init_codeowners' },
  { event_type: 'init_chat_rules' },
  { event_type: 'init_mr_review_instructions' },
];

describe('ReadinessDashboard', () => {
  let wrapper;

  const createComponent = ({
    adminProject = true,
    dapAvailable = true,
    environmentHealthy = true,
  } = {}) => {
    window.gon = {
      ...window.gon,
      onboarding_capabilities: { can_admin_project: adminProject },
      onboarding_readiness: {
        dap_available: dapAvailable,
        environment_healthy: environmentHealthy,
        group_settings_path: '/groups/acme/-/settings/gitlab_duo',
      },
      onboarding_initializers: INITIALIZERS,
      onboarding_setup_path: '/setup',
    };

    wrapper = mountExtended(ReadinessDashboard, {
      stubs: { InitializerSection: true },
      mocks: { $router: { resolve: jest.fn(() => ({ href: '/x' })) } },
    });
  };

  const findTitle = () => wrapper.findByTestId('page-heading').text();
  const findDescription = () => wrapper.findByTestId('page-heading-description').text();
  const findBanner = () => wrapper.findComponent(ReadinessBanner);
  const findCustomizeSection = () => wrapper.findComponent(InitializerSection);

  describe('header', () => {
    it('shows the "getting ready" title and intro when the platform is not enabled', () => {
      createComponent({ dapAvailable: false });

      expect(findTitle()).toContain('GitLab Duo Agent Platform');
      expect(findDescription()).toContain("isn't enabled for this project yet");
    });

    it('shows the "get this project ready" title and intro otherwise', () => {
      createComponent();

      expect(findTitle()).toContain('Get this project ready for GitLab Duo Agent Platform');
      expect(findDescription()).toContain('Set up what your project needs');
    });
  });

  describe('banner', () => {
    it.each`
      scenario                 | props                            | expectedState
      ${'ready'}               | ${{}}                            | ${PROJECT_STATE_READY}
      ${'environment problem'} | ${{ environmentHealthy: false }} | ${PROJECT_STATE_ENVIRONMENT_PROBLEM}
      ${'not enabled'}         | ${{ dapAvailable: false }}       | ${PROJECT_STATE_NOT_ENABLED}
    `('passes the $scenario state to the banner', ({ props, expectedState }) => {
      createComponent(props);

      expect(findBanner().props('state')).toBe(expectedState);
    });
  });

  describe('Customize agents section', () => {
    it('shows it to a maintainer when ready, with the customize initializers only', () => {
      createComponent({ adminProject: true });

      expect(findCustomizeSection().exists()).toBe(true);
      expect(findCustomizeSection().props('initializers')).toEqual([
        { event_type: 'init_project_context' },
        { event_type: 'init_codeowners' },
        { event_type: 'init_chat_rules' },
        { event_type: 'init_mr_review_instructions' },
      ]);
    });

    it('hides it from a developer', () => {
      createComponent({ adminProject: false });

      expect(findCustomizeSection().exists()).toBe(false);
    });

    it('hides it when the platform is not enabled', () => {
      createComponent({ adminProject: true, dapAvailable: false });

      expect(findCustomizeSection().exists()).toBe(false);
    });
  });
});
