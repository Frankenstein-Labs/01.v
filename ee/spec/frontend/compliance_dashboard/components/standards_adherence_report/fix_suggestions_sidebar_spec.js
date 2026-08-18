import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FixSuggestionsSidebar from 'ee/compliance_dashboard/components/standards_adherence_report/fix_suggestions_sidebar.vue';
import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';
import { DOCS_URL } from '~/constants';

describe('FixSuggestionsSidebar component', () => {
  let wrapper;

  const findRequirementSectionTitle = () => wrapper.findByTestId('sidebar-requirement-title');
  const findRequirementSectionContent = () => wrapper.findByTestId('sidebar-requirement-content');
  const findFailureSectionReasonTitle = () => wrapper.findByTestId('sidebar-failure-title');
  const findFailureSectionReasonContent = () => wrapper.findByTestId('sidebar-failure-content');
  const findSuccessSectionReasonContent = () => wrapper.findByTestId('sidebar-success-content');
  const findHowToFixSection = () => wrapper.findByTestId('sidebar-how-to-fix');
  const findFixTitle = () => wrapper.findAllByTestId('sidebar-fix-title');
  const findFixDescription = () => wrapper.findAllByTestId('sidebar-fix-description');
  const findFixBtn = () => wrapper.findAllByTestId('sidebar-fix-settings-button');
  const findLearnMoreBtn = () => wrapper.findAllByTestId('sidebar-fix-settings-learn-more-button');
  const findFrameworksTitle = () => wrapper.findByTestId('sidebar-frameworks-title');
  const findFrameworksContent = () => wrapper.findByTestId('sidebar-frameworks-content');
  const findFrameworksBadges = () => wrapper.findAllComponents(FrameworkBadge);

  const complianceFrameworks = {
    nodes: [
      {
        id: 1,
        name: 'Framework 1',
        color: '#fff',
      },
    ],
  };

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(FixSuggestionsSidebar, {
      propsData: {
        showDrawer: true,
        groupPath: 'example-group',
        ...propsData,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('default behavior', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          adherence: {
            checkName: '',
            status: 'FAIL',
            project: {
              id: 'gid://gitlab/Project/21',
              name: 'example project',
              complianceFrameworks,
            },
          },
        },
      });
    });

    describe('for drawer body content', () => {
      it('renders the `requirement` title', () => {
        expect(findRequirementSectionTitle().text()).toBe('Requirement');
      });

      it('renders the `failure reason` title', () => {
        expect(findFailureSectionReasonTitle().text()).toBe('Failure reason');
      });

      it('renders the `how to fix` title and description', () => {
        expect(findHowToFixSection().text()).toContain('How to fix');
        expect(findHowToFixSection().text()).toContain(
          'The following features help satisfy this requirement',
        );
      });

      it('renders the info about project`s compliance frameworks', () => {
        expect(findFrameworksTitle().text()).toBe('All attached frameworks');
        expect(findFrameworksContent().text()).toMatchInterpolatedText(
          'Other compliance frameworks applied to example project',
        );
        expect(findFrameworksBadges()).toHaveLength(complianceFrameworks.nodes.length);
      });
    });
  });

  describe('content for each check type related to MRs', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          adherence: {
            checkName: 'PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR',
            status: 'FAIL',
            project: {
              id: 'gid://gitlab/Project/21',
              name: 'example project',
              webUrl: 'example.com/groups/example-group/example-project',
              complianceFrameworks,
            },
          },
        },
      });
    });

    describe('for failed checks', () => {
      describe.each`
        checkName                                         | expectedRequirement                                                                                    | expectedFailureReason                                                                     | expectedLearnMoreDocsLink                                                                                                    | expectedFixTitle                  | expectedFixDescription                                                                             | expectedProjectSettingsButtonText | expectedProjectSettingsPath
        ${'PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR'}     | ${'Have a valid rule that prevents author-approved merge requests from being merged'}                  | ${'No rule is configured to prevent author approved merge requests.'}                     | ${`${DOCS_URL}/user/compliance/compliance_center/compliance_standards_adherence_dashboard/#prevent-authors-as-approvers`}    | ${'Merge request approval rules'} | ${"Update approval settings in the project's merge request settings to satisfy this requirement."} | ${'Manage rules'}                 | ${'-/settings/merge_requests'}
        ${'PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS'} | ${"Have a valid rule that prevents users from approving merge requests that they've added commits to"} | ${'No rule is configured to prevent merge requests approved by committers.'}              | ${`${DOCS_URL}/user/compliance/compliance_center/compliance_standards_adherence_dashboard/#prevent-committers-as-approvers`} | ${'Merge request approval rules'} | ${"Update approval settings in the project's merge request settings to satisfy this requirement."} | ${'Manage rules'}                 | ${'-/settings/merge_requests'}
        ${'AT_LEAST_TWO_APPROVALS'}                       | ${'Have a valid rule that prevents merge requests with fewer than two approvals from being merged'}    | ${'No rule is configured to require two approvals.'}                                      | ${`${DOCS_URL}/user/compliance/compliance_center/compliance_standards_adherence_dashboard/#at-least-two-approvals`}          | ${'Merge request approval rules'} | ${"Update approval settings in the project's merge request settings to satisfy this requirement."} | ${'Manage rules'}                 | ${'-/settings/merge_requests'}
        ${'SAST'}                                         | ${'Have SAST scanner configured in pipeline configuration'}                                            | ${'SAST scanner is not configured in the pipeline configuration for the default branch.'} | ${`${DOCS_URL}/user/compliance/compliance_center/compliance_standards_adherence_dashboard/#sast-scanner-artifact`}           | ${'Enable SAST scanner'}          | ${"Enable SAST scanner in the project's security configuration to satisfy this requirement."}      | ${'Manage configuration'}         | ${'-/security/configuration'}
        ${'DAST'}                                         | ${'Have DAST scanner configured in pipeline configuration'}                                            | ${'DAST scanner is not configured in the pipeline configuration for the default branch.'} | ${`${DOCS_URL}/user/compliance/compliance_center/compliance_standards_adherence_dashboard/#dast-scanner-artifact`}           | ${'Enable DAST scanner'}          | ${"Enable DAST scanner in the project's security configuration to satisfy this requirement."}      | ${'Manage configuration'}         | ${'-/security/configuration'}
      `(
        'when check is $checkName',
        ({
          checkName,
          expectedRequirement,
          expectedFailureReason,
          expectedLearnMoreDocsLink,
          expectedFixTitle,
          expectedFixDescription,
          expectedProjectSettingsButtonText,
          expectedProjectSettingsPath,
        }) => {
          beforeEach(() => {
            createComponent({
              propsData: {
                adherence: {
                  checkName,
                  status: 'FAIL',
                  project: {
                    id: 'gid://gitlab/Project/21',
                    name: 'example project',
                    complianceFrameworks,
                  },
                },
              },
            });
          });

          it('renders the requirement', () => {
            expect(findRequirementSectionContent().text()).toBe(expectedRequirement);
          });

          it('renders the failure reason', () => {
            expect(findFailureSectionReasonContent().text()).toBe(expectedFailureReason);
          });

          describe('for the `how to fix` section', () => {
            it('has the details', () => {
              expect(findFixTitle().at(0).text()).toContain(expectedFixTitle);

              expect(findFixDescription().at(0).text()).toContain(expectedFixDescription);
            });

            it('has the `manage rules` button', () => {
              expect(findFixBtn().at(0).text()).toBe(expectedProjectSettingsButtonText);

              expect(findFixBtn().at(0).attributes('href')).toBe(expectedProjectSettingsPath);
            });

            it('renders the `learn more` button with the correct href', () => {
              expect(findLearnMoreBtn().at(0).attributes('href')).toBe(expectedLearnMoreDocsLink);
            });
          });
        },
      );
    });

    describe('for passed checks', () => {
      describe.each`
        checkName                                         | expectedRequirement                                                                                    | expectedSuccessReason
        ${'PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR'}     | ${'Have a valid rule that prevents author-approved merge requests from being merged'}                  | ${'A rule is configured to prevent author approved merge requests.'}
        ${'PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS'} | ${"Have a valid rule that prevents users from approving merge requests that they've added commits to"} | ${'A rule is configured to prevent merge requests approved by committers.'}
        ${'AT_LEAST_TWO_APPROVALS'}                       | ${'Have a valid rule that prevents merge requests with fewer than two approvals from being merged'}    | ${'A rule is configured to require two approvals.'}
        ${'SAST'}                                         | ${'Have SAST scanner configured in pipeline configuration'}                                            | ${'SAST scanner is configured in the pipeline configuration for the default branch.'}
        ${'DAST'}                                         | ${'Have DAST scanner configured in pipeline configuration'}                                            | ${'DAST scanner is configured in the pipeline configuration for the default branch.'}
      `('when check is $checkName', ({ checkName, expectedRequirement, expectedSuccessReason }) => {
        beforeEach(() => {
          createComponent({
            propsData: {
              adherence: {
                checkName,
                status: 'PASS',
                project: {
                  id: 'gid://gitlab/Project/21',
                  name: 'example project',
                  complianceFrameworks,
                },
              },
            },
          });
        });

        it('renders the requirement', () => {
          expect(findRequirementSectionContent().text()).toBe(expectedRequirement);
        });

        it('renders the success reason', () => {
          expect(findSuccessSectionReasonContent().text()).toBe(expectedSuccessReason);
        });
      });
    });
  });
});
