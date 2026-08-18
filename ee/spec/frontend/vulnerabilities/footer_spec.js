import { GlLoadingIcon } from '@gitlab/ui';
import Visibility from 'visibilityjs';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import Api from 'ee/api';
import vulnerabilityDiscussionsQuery from 'ee/security_dashboard/graphql/queries/vulnerability_discussions.query.graphql';
import MergeRequestNote from 'ee/vue_shared/security_reports/components/merge_request_note.vue';
import SolutionCard from 'ee/vue_shared/security_reports/components/solution_card.vue';
import VulnerabilityFooter from 'ee/vulnerabilities/components/footer.vue';
import GenericReportSection from 'ee/vulnerabilities/components/generic_report/report_section.vue';
import HistoryEntry from 'ee/vulnerabilities/components/history_entry.vue';
import RelatedIssues from 'ee/vulnerabilities/components/related_issues.vue';
import RelatedJiraIssues from 'ee/vulnerabilities/components/related_jira_issues.vue';
import StatusDescription from 'ee/vulnerabilities/components/status_description.vue';
import SecurityPolicyBypassDescription from 'ee/vulnerabilities/components/security_policy_bypass_description.vue';
import { VULNERABILITY_STATES } from 'ee/vulnerabilities/constants';
import { normalizeGraphQLNote } from 'ee/vulnerabilities/helpers';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { addTypenamesToDiscussion, generateNote } from './mock_data';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('Vulnerability Footer', () => {
  let wrapper;

  const vulnerability = {
    id: 1,
    notesUrl: '/notes',
    project: {
      fullPath: '/root/security-reports',
      fullName: 'Administrator / Security Reports',
    },
    canModifyRelatedIssues: true,
    relatedIssuesHelpPath: 'help/path',
    pipeline: {},
    mergeRequestLinks: [],
    representationInformation: {
      resolvedInCommitShaLink: 'https://gitlab.com/gitlab-org/gitlab/-/commit/0123456789',
      resolvedInCommitSha: '0123456789',
    },
    resolvedOnDefaultBranch: false,
  };

  let discussion1;
  let discussion2;

  const discussionsHandler = ({
    discussions: nodes,
    errors = [],
    success = true,
    handler = jest.fn(),
  }) =>
    handler[success ? 'mockResolvedValueOnce' : 'mockRejectedValueOnce']({
      data: {
        errors,
        vulnerability: {
          id: `gid://gitlab/Vulnerability/${vulnerability.id}`,
          discussions: {
            nodes,
          },
        },
      },
    });

  const createWrapper = ({ properties, queryHandler, mountOptions } = {}) => {
    wrapper = shallowMountExtended(VulnerabilityFooter, {
      propsData: { vulnerability: { ...vulnerability, ...properties } },
      apolloProvider: createMockApollo([[vulnerabilityDiscussionsQuery, queryHandler]]),
      ...mountOptions,
    });
  };

  const findDiscussions = () => wrapper.findAllComponents(HistoryEntry);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findMergeRequestNote = () => wrapper.findComponent(MergeRequestNote);
  const findRelatedIssues = () => wrapper.findComponent(RelatedIssues);
  const findRelatedJiraIssues = () => wrapper.findComponent(RelatedJiraIssues);
  const findSecurityPolicyBypassDescription = () =>
    wrapper.findComponent(SecurityPolicyBypassDescription);
  const findAllSecurityPolicyBypassDescriptions = () =>
    wrapper.findAllComponents(SecurityPolicyBypassDescription);

  beforeEach(() => {
    discussion1 = {
      id: 'gid://gitlab/Discussion/7b4aa2d000ec81ba374a29b3ca3ee4c5f274f9ab',
      replyId: 'gid://gitlab/Discussion/7b4aa2d000ec81ba374a29b3ca3ee4c5f274f9ab',
      notes: {
        nodes: [generateNote({ id: 100 })],
      },
    };

    discussion2 = {
      id: 'gid://gitlab/Discussion/0656f86109dc755c99c288c54d154b9705aaa796',
      replyId: 'gid://gitlab/Discussion/0656f86109dc755c99c288c54d154b9705aaa796',
      notes: {
        nodes: [generateNote({ id: 200 })],
      },
    };
  });

  describe('discussions', () => {
    const createWrapperAndFetchDiscussions = async ({ discussions, errors, success }) => {
      createWrapper({ queryHandler: discussionsHandler({ discussions, errors, success }) });
      await waitForPromises();
    };

    const refetchDiscussions = async () => {
      findDiscussions().at(0).vm.$emit('comment-updated');
      await waitForPromises();
    };

    it('displays a loading spinner while fetching discussions', async () => {
      createWrapper({ queryHandler: discussionsHandler({ discussions: [] }) });
      expect(findDiscussions().exists()).toBe(false);
      expect(findLoadingIcon().exists()).toBe(true);
      await waitForPromises();
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('fetches discussions and notes on mount', async () => {
      await createWrapperAndFetchDiscussions({
        discussions: [addTypenamesToDiscussion(discussion1), addTypenamesToDiscussion(discussion2)],
      });

      expect(findDiscussions().at(0).props()).toMatchObject({
        discussion: {
          ...addTypenamesToDiscussion(discussion1),
          notes: [normalizeGraphQLNote(discussion1.notes.nodes[0])],
        },
      });

      expect(findDiscussions().at(1).props()).toStrictEqual({
        discussion: {
          ...addTypenamesToDiscussion(discussion2),
          notes: [normalizeGraphQLNote(discussion2.notes.nodes[0])],
        },
        borderless: false,
      });
    });

    it.each`
      description                       | updateVulnerabilityState
      ${'should fetch discussions'}     | ${true}
      ${'should not fetch discussions'} | ${false}
    `(
      `$description when the passed-in vulnerability's state is "$updateVulnerabilityState"`,
      async ({ updateVulnerabilityState }) => {
        const queryHandler = discussionsHandler({ discussions: [] });
        createWrapper({ queryHandler });
        await waitForPromises();

        expect(queryHandler).toHaveBeenCalledTimes(1);

        await wrapper.setProps({
          vulnerability: {
            ...vulnerability,
            state: updateVulnerabilityState ? 'newState' : vulnerability.state,
          },
        });

        const expectedQueryCalls = updateVulnerabilityState ? 2 : 1;
        expect(queryHandler).toHaveBeenCalledTimes(expectedQueryCalls);
      },
    );

    it('shows an error the discussions could not be retrieved', async () => {
      await createWrapperAndFetchDiscussions({
        errors: [{ message: 'Something went wrong' }],
        success: false,
      });
      expect(createAlert).toHaveBeenCalledWith({
        message:
          'Something went wrong while trying to retrieve the vulnerability history. Please try again later.',
      });
    });

    it('polls the server every 10 seconds for new discussions and attaches a listener to visibility-js', async () => {
      const setIntervalSpy = jest.spyOn(window, 'setInterval');
      const visibilityChangeSpy = jest.spyOn(Visibility, 'change');
      createWrapper({ queryHandler: discussionsHandler({ discussions: [] }) });
      expect(setIntervalSpy).not.toHaveBeenCalled();
      expect(visibilityChangeSpy).not.toHaveBeenCalled();
      await waitForPromises();
      expect(setIntervalSpy).toHaveBeenCalledWith(wrapper.vm.fetchDiscussions, 10000);
      expect(visibilityChangeSpy).toHaveBeenCalled();
    });

    it('removes the poll and visibility listener when unmounted', async () => {
      const clearIntervalSpy = jest.spyOn(window, 'clearInterval');
      const visibilityUnbindSpy = jest.spyOn(Visibility, 'unbind');
      await createWrapperAndFetchDiscussions({ discussions: [] });
      wrapper.destroy();
      expect(clearIntervalSpy).toHaveBeenCalled();
      expect(visibilityUnbindSpy).toHaveBeenCalled();
    });

    it('does not remove the listener when the visibility changes', async () => {
      const clearIntervalSpy = jest.spyOn(window, 'clearInterval');
      const visibilityUnbindSpy = jest.spyOn(Visibility, 'unbind');
      const visibilityHiddenSpy = jest
        .spyOn(Visibility, 'hidden')
        .mockImplementationOnce(() => false) // This is called in startPolling
        .mockImplementationOnce(() => true); // This is called in visibilityChangeListener
      const visibilityChangeSpy = jest
        .spyOn(Visibility, 'change')
        .mockImplementation((callback) => callback());
      await createWrapperAndFetchDiscussions({ discussions: [] });
      expect(visibilityHiddenSpy).toHaveBeenCalled();
      expect(visibilityChangeSpy).toHaveBeenCalled();
      expect(clearIntervalSpy).toHaveBeenCalled();
      expect(visibilityUnbindSpy).not.toHaveBeenCalled();
    });

    it('emits the vulnerability-state-change event when the system note is new', async () => {
      const eventName = 'vulnerability-state-change';
      const queryHandler = discussionsHandler({
        discussions: [addTypenamesToDiscussion(discussion1)],
      }); // first call
      discussionsHandler({
        discussions: [addTypenamesToDiscussion(discussion1)],
        handler: queryHandler,
      }); // second call is the same
      discussionsHandler({
        discussions: [addTypenamesToDiscussion(discussion1), addTypenamesToDiscussion(discussion2)],
        handler: queryHandler,
      }); // for the third call we change the number of discussions

      createWrapper({
        queryHandler,
      });

      // Wait that the initial call has been made
      await waitForPromises();

      // At this stage the handler should not be called because it's the first call (so page load).
      expect(wrapper.emitted(eventName)).toBeUndefined();

      // Fetch again with same data
      await refetchDiscussions();

      // There should be no new discussions so the event should be emitted once
      expect(wrapper.emitted(eventName)).toBeUndefined();

      // Fetch again with different data
      await refetchDiscussions();

      // The event should be emitted once as there is a new discussion
      expect(wrapper.emitted(eventName)).toHaveLength(1);
    });
  });

  describe('solution card', () => {
    const findSolutionCard = () => wrapper.findComponent(SolutionCard);

    it.each`
      solutionHtml       | solution           | remediations                      | expectedHtml       | expectedText
      ${'solution HTML'} | ${null}            | ${[]}                             | ${'solution HTML'} | ${null}
      ${null}            | ${'solution'}      | ${[]}                             | ${null}            | ${'solution'}
      ${null}            | ${null}            | ${[{ summary: 'summary' }]}       | ${null}            | ${'summary'}
      ${'solution HTML'} | ${'solution'}      | ${[{ summary: 'summary' }]}       | ${'solution HTML'} | ${'solution'}
      ${null}            | ${'solution'}      | ${[{ summary: 'summary' }]}       | ${null}            | ${'solution'}
      ${'<em>test</em>'} | ${null}            | ${[]}                             | ${'<em>test</em>'} | ${null}
      ${null}            | ${'<em>test</em>'} | ${[]}                             | ${null}            | ${'<em>test</em>'}
      ${null}            | ${null}            | ${[{ summary: '<em>test</em>' }]} | ${null}            | ${'<em>test</em>'}
    `(
      `passes solutionHtml=$expectedHtml and solutionText=$expectedText to solution card`,
      ({ solutionHtml, solution, remediations, expectedHtml, expectedText }) => {
        createWrapper({ properties: { solutionHtml, solution, remediations } });

        expect(findSolutionCard().props('solutionHtml')).toBe(expectedHtml);
        expect(findSolutionCard().props('solutionText')).toBe(expectedText);
      },
    );

    it('does not show solution card when there is no solution', () => {
      createWrapper();
      expect(findSolutionCard().exists()).toBe(false);
    });

    describe('when vulnerability is malicious', () => {
      it('hides solution card', () => {
        createWrapper({
          properties: { solution: 'some solution', malware: true },
          mountOptions: {
            provide: { glFeatures: { maliciousPackageDetection: true } },
          },
        });

        expect(wrapper.findComponent(SolutionCard).exists()).toBe(false);
      });

      it('shows solution card when feature flag is disabled', () => {
        createWrapper({
          properties: { solution: 'some solution', malware: true },
          mountOptions: {
            provide: { glFeatures: { maliciousPackageDetection: false } },
          },
        });

        expect(wrapper.findComponent(SolutionCard).props('solutionText')).toBe('some solution');
      });
    });
  });

  describe('merge request note', () => {
    it('does not show merge request note when a merge request does not exist for the vulnerability', () => {
      createWrapper();
      expect(findMergeRequestNote().exists()).toBe(false);
    });

    it('shows merge request note when a merge request exists for the vulnerability', () => {
      // The object itself does not matter, we just want to make sure it's passed to the issue note.
      const mergeRequestLinks = [{}];

      createWrapper({ properties: { mergeRequestLinks } });
      expect(findMergeRequestNote().exists()).toBe(true);
      expect(findMergeRequestNote().props('feedback')).toBe(mergeRequestLinks.at(-1));
    });
  });

  describe('related issues', () => {
    it('has the correct props', () => {
      const endpoint = Api.buildUrl(Api.vulnerabilityIssueLinksPath).replace(
        ':id',
        vulnerability.id,
      );

      createWrapper();

      expect(findRelatedIssues().exists()).toBe(true);
      expect(findRelatedIssues().props()).toMatchObject({
        endpoint,
        canModifyRelatedIssues: vulnerability.canModifyRelatedIssues,
        projectPath: vulnerability.project.fullPath,
        helpPath: vulnerability.relatedIssuesHelpPath,
      });
    });
  });

  describe('related jira issues', () => {
    describe.each`
      createJiraIssueUrl | shouldShowRelatedJiraIssues
      ${'http://foo'}    | ${true}
      ${''}              | ${false}
    `(
      'with "createJiraIssueUrl" set to "$createJiraIssueUrl"',
      ({ createJiraIssueUrl, shouldShowRelatedJiraIssues }) => {
        beforeEach(() => {
          createWrapper({
            mountOptions: {
              provide: {
                createJiraIssueUrl,
              },
            },
          });
        });

        it(`${
          shouldShowRelatedJiraIssues ? 'should' : 'should not'
        } show related Jira issues`, () => {
          expect(findRelatedJiraIssues().exists()).toBe(shouldShowRelatedJiraIssues);
        });
      },
    );
  });

  describe('detection note', () => {
    const detectionNote = () => wrapper.findByTestId('detection-note');
    const statusDescription = () => wrapper.findComponent(StatusDescription);
    const vulnerabilityStates = Object.keys(VULNERABILITY_STATES);

    it.each(vulnerabilityStates)(
      `shows detection note when vulnerability state is '%s'`,
      (state) => {
        createWrapper({ properties: { state } });

        expect(detectionNote().exists()).toBe(true);
        expect(statusDescription().props('vulnerability')).toEqual({
          state: 'detected',
          pipeline: vulnerability.pipeline,
          scanner: vulnerability.scanner,
          detectedAt: vulnerability.detectedAt,
        });
      },
    );

    describe('when the pipeline is null (vulnerability has been created manually)', () => {
      it('should not show the status description by default', () => {
        createWrapper({ properties: { pipeline: null } });
        expect(statusDescription().exists()).toBe(false);
      });

      it('should not show the status description when the vulnerability is resolved on the default branch and there is no representation information', () => {
        createWrapper({
          properties: {
            pipeline: null,
            resolvedOnDefaultBranch: true,
            representationInformation: null,
          },
        });
        expect(statusDescription().exists()).toBe(false);
      });

      it('should show the status description when the vulnerability is resolved on the default branch and there is representation information', () => {
        createWrapper({
          properties: {
            pipeline: null,
            resolvedOnDefaultBranch: true,
            representationInformation: vulnerability.representationInformation,
          },
        });
        expect(statusDescription().exists()).toBe(true);
      });
    });

    describe('when the vulnerability is resolved on the default branch and there is representation information', () => {
      it('should pass the correct props to the detection note', () => {
        createWrapper({
          properties: {
            resolvedOnDefaultBranch: true,
            representationInformation: vulnerability.representationInformation,
          },
        });

        expect(statusDescription().props('vulnerability')).toMatchObject({
          resolvedOnDefaultBranch: true,
          representationInformation: vulnerability.representationInformation,
        });
      });
    });

    it.each`
      representationInformation                  | resolvedOnDefaultBranch | shouldIncludeRepresentationInfo
      ${vulnerability.representationInformation} | ${true}                 | ${true}
      ${vulnerability.representationInformation} | ${false}                | ${false}
      ${null}                                    | ${true}                 | ${false}
      ${null}                                    | ${false}                | ${false}
    `(
      'shows representation information: "$shouldIncludeRepresentationInfo" when resolvedOnDefaultBranch is "$resolvedOnDefaultBranch" and representationInformation is "$representationInformation"',
      ({ resolvedOnDefaultBranch, representationInformation, shouldIncludeRepresentationInfo }) => {
        createWrapper({
          properties: {
            resolvedOnDefaultBranch,
            representationInformation,
          },
        });

        expect(Boolean(statusDescription().props('vulnerability').representationInformation)).toBe(
          shouldIncludeRepresentationInfo,
        );
      },
    );
  });

  describe('generic report', () => {
    const mockDetails = { foo: { type: 'bar' } };

    const genericReportSection = () => wrapper.findComponent(GenericReportSection);

    describe('when a vulnerability contains a details property', () => {
      beforeEach(() => {
        createWrapper({ properties: { details: mockDetails } });
      });

      it('renders the report section', () => {
        expect(genericReportSection().exists()).toBe(true);
      });

      it('passes the correct props to the report section', () => {
        expect(genericReportSection().props()).toMatchObject({
          details: mockDetails,
        });
      });
    });

    describe('when a vulnerability does not contain a details property', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('does not render the report section', () => {
        expect(genericReportSection().exists()).toBe(false);
      });
    });
  });

  describe('security policy bypass', () => {
    it('does not render the policy violation note when there are no policy bypasses', () => {
      createWrapper({
        properties: { policyDismissals: [] },
      });
      expect(findSecurityPolicyBypassDescription().exists()).toBe(false);
    });

    it('renders the policy violation note when there are policy bypasses', () => {
      createWrapper({
        properties: { policyDismissals: [{ id: 1 }] },
      });
      expect(findSecurityPolicyBypassDescription().exists()).toBe(true);
    });

    it('renders the security policy dismissal description correctly', () => {
      createWrapper({
        properties: { policyDismissals: [{ id: 1 }, { id: 2 }] },
      });
      expect(findAllSecurityPolicyBypassDescriptions()).toHaveLength(2);
      expect(findAllSecurityPolicyBypassDescriptions().at(0).props('bypass')).toEqual({
        id: 1,
      });
    });
  });
});
