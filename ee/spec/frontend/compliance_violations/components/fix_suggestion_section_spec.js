import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FixSuggestionSection from 'ee/compliance_violations/components/fix_suggestion_section.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { statusesInfo } from 'ee/compliance_dashboard/components/standards_adherence_report/components/details_drawer/statuses_info';

describe('FixSuggestionSection', () => {
  let wrapper;

  const mockControlId = 'minimum_approvals_required_2';
  const mockProjectPath = 'https://localhost:3000/project/path';

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(FixSuggestionSection, {
      propsData: {
        controlId: mockControlId,
        projectPath: mockProjectPath,
        ...props,
      },
      stubs: {
        CrudComponent,
      },
    });
  };

  const findViolationSection = () => wrapper.findComponent(CrudComponent);
  const findDescription = (index) => wrapper.findByTestId(`fix-suggestion-description-${index}`);
  const findLearnMoreLink = (index) => wrapper.findByTestId(`fix-suggestion-learn-more-${index}`);
  const findProjectSettingsLink = (index) =>
    wrapper.findByTestId(`fix-suggestion-project-settings-${index}`);
  const findCreateIssueLink = (index) =>
    wrapper.findByTestId(`fix-suggestion-create-issue-${index}`);

  beforeEach(() => {
    createComponent();
  });

  describe('violation section', () => {
    it('renders violation section', () => {
      expect(findViolationSection().exists()).toBe(true);
    });

    it('renders the correct title', () => {
      const titleElement = wrapper.findByTestId('crud-title');
      expect(titleElement.text()).toBe('Fix suggestion generated for this failed control');
    });

    it('renders correct description', () => {
      const description = findDescription(0);
      expect(description.exists()).toBe(true);
      expect(description.text()).toContain(statusesInfo[mockControlId].fixes[0].description);
    });

    it('renders correct learn more link', () => {
      const learnMoreLink = findLearnMoreLink(0);
      expect(learnMoreLink.exists()).toBe(true);
      expect(learnMoreLink.text()).toBe('Learn more');
      expect(learnMoreLink.attributes('href')).toBe(statusesInfo[mockControlId].fixes[0].link);
    });

    it('renders project settings link', () => {
      const projectSettingsLink = findProjectSettingsLink(0);
      expect(projectSettingsLink.exists()).toBe(true);
      expect(projectSettingsLink.text()).toBe('Go to project settings');
      expect(projectSettingsLink.attributes('href')).toBe(`${mockProjectPath}/edit`);
    });

    it('renders create issue link', () => {
      const createIssueLink = findCreateIssueLink(0);
      expect(createIssueLink.exists()).toBe(true);
      expect(createIssueLink.text()).toBe('Create issue');
      expect(createIssueLink.attributes('href')).toBe(`${mockProjectPath}/-/issues/new`);
    });
  });
});
