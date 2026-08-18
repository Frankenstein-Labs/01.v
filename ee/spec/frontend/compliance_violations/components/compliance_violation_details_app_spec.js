import { GlAlert, GlLoadingIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ComplianceViolationDetailsApp from 'ee/compliance_violations/components/compliance_violation_details_app.vue';
import AuditEvent from 'ee/compliance_violations/components/audit_event.vue';
import ViolationSection from 'ee/compliance_violations/components/violation_section.vue';
import SystemNote from '~/work_items/components/notes/system_note.vue';
import ComplianceViolationDiscussion from 'ee/compliance_violations/components/compliance_violation_discussion.vue';
import FixSuggestionSection from 'ee/compliance_violations/components/fix_suggestion_section.vue';
import RelatedIssues from 'ee/compliance_violations/components/related_issues.vue';
import CreateCommentForm from 'ee/compliance_violations/components/create_comment_form.vue';
import { ComplianceViolationStatusDropdown } from 'ee/vue_shared/compliance';
import complianceViolationQuery from 'ee/compliance_violations/graphql/compliance_violation.query.graphql';
import updateProjectComplianceViolation from 'ee/compliance_violations/graphql/mutations/update_project_compliance_violation.mutation.graphql';
import complianceViolationNoteCreatedSubscription from 'ee/compliance_violations/graphql/subscriptions/compliance_violation_note_created.subscription.graphql';
import complianceViolationNoteUpdatedSubscription from 'ee/compliance_violations/graphql/subscriptions/compliance_violation_note_updated.subscription.graphql';
import complianceViolationNoteDeletedSubscription from 'ee/compliance_violations/graphql/subscriptions/compliance_violation_note_deleted.subscription.graphql';
import {
  violationId,
  complianceCenterPath,
  mockComplianceViolation,
  mockComplianceViolationData,
  mockUpdateResponseData,
  mockGraphQlError,
  mockDataWithoutAuditEvent,
  mockDataWithoutNotes,
  mockDataWithNullNotes,
  mockDataWithOnlyNonSystemNotes,
} from './mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('ComplianceViolationDetailsApp', () => {
  let wrapper;
  let mockApollo;
  let queryHandler;
  let mutationHandler;

  const neverResolvingPromise = () => new Promise(() => {});

  const createComponent = ({
    props = {},
    mockQueryHandler = jest.fn().mockResolvedValue(mockComplianceViolationData),
    mockMutationHandler = jest.fn().mockResolvedValue(mockUpdateResponseData),
    mockNoteCreatedHandler = jest.fn().mockImplementation(neverResolvingPromise),
    mockNoteUpdatedHandler = jest.fn().mockImplementation(neverResolvingPromise),
    mockNoteDeletedHandler = jest.fn().mockImplementation(neverResolvingPromise),
  } = {}) => {
    queryHandler = mockQueryHandler;
    mutationHandler = mockMutationHandler;

    mockApollo = createMockApollo([
      [complianceViolationQuery, queryHandler],
      [updateProjectComplianceViolation, mutationHandler],
      [complianceViolationNoteCreatedSubscription, mockNoteCreatedHandler],
      [complianceViolationNoteUpdatedSubscription, mockNoteUpdatedHandler],
      [complianceViolationNoteDeletedSubscription, mockNoteDeletedHandler],
    ]);

    wrapper = shallowMountExtended(ComplianceViolationDetailsApp, {
      apolloProvider: mockApollo,
      propsData: {
        violationId,
        complianceCenterPath,
        ...props,
      },
    });
  };

  const findLoadingStatus = () =>
    wrapper.findByTestId('compliance-violation-details-loading-status');
  const findStatusDropdown = () => wrapper.findComponent(ComplianceViolationStatusDropdown);
  const findViolationDetails = () => wrapper.findByTestId('compliance-violation-details');
  const findAuditEvent = () => wrapper.findComponent(AuditEvent);
  const findViolationSection = () => wrapper.findComponent(ViolationSection);
  const findFixSuggestionSection = () => wrapper.findComponent(FixSuggestionSection);
  const findRelatedIssues = () => wrapper.findComponent(RelatedIssues);
  const findErrorMessage = () => wrapper.findComponent(GlAlert);
  const findSystemNotes = () => wrapper.findAllComponents(SystemNote);
  const findDiscussions = () => wrapper.findAllComponents(ComplianceViolationDiscussion);
  const findActivitySection = () => wrapper.find('.issuable-discussion');
  const findActivityHeader = () => wrapper.find('.issuable-discussion h2');
  const findCommentForm = () => wrapper.findComponent(CreateCommentForm);

  beforeEach(() => {
    jest.clearAllMocks();
  });

  afterEach(() => {
    wrapper?.destroy();
  });

  describe('when the query fails', () => {
    beforeEach(async () => {
      createComponent({ mockQueryHandler: mockGraphQlError });
      await waitForPromises();
    });

    it('renders the error message', () => {
      expect(findErrorMessage().exists()).toBe(true);
      expect(findErrorMessage().text()).toBe(
        'Failed to load the compliance violation. Refresh the page and try again.',
      );
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });

  describe('when loading', () => {
    beforeEach(() => {
      // Create a query handler that never resolves to keep the component in loading state
      const loadingQueryHandler = jest.fn().mockImplementation(() => new Promise(() => {}));
      createComponent({ mockQueryHandler: loadingQueryHandler });
    });

    it('shows loading icon', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
      expect(findLoadingStatus().exists()).toBe(true);
    });

    it('does not show violation details', () => {
      expect(findViolationDetails().exists()).toBe(false);
    });
  });

  describe('when loaded with violation data', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      await nextTick();
    });

    it('does not show loading icon', () => {
      expect(findLoadingStatus().exists()).toBe(false);
    });

    it('shows violation details', () => {
      expect(findViolationDetails().exists()).toBe(true);
    });

    it('displays the correct title', () => {
      const title = wrapper.findByTestId('compliance-violation-title');
      expect(title.text()).toBe(`Details of violation-${violationId}`);
    });

    it('renders the status dropdown with correct props', () => {
      const dropdown = findStatusDropdown();
      expect(dropdown.exists()).toBe(true);
      expect(dropdown.props()).toMatchObject({
        value: 'in_review',
        loading: false,
      });
    });

    it('displays the project with link', () => {
      const { project } = mockComplianceViolation;
      const projectLink = wrapper.findByTestId('compliance-violation-location-link');
      expect(projectLink.exists()).toBe(true);
      expect(projectLink.text()).toBe(project.nameWithNamespace);
      expect(projectLink.attributes('href')).toBe(project.webUrl);
    });

    it('renders the violation section', () => {
      const violationSectionComponent = findViolationSection();
      expect(violationSectionComponent.exists()).toBe(true);
      expect(violationSectionComponent.props('control')).toEqual(
        mockComplianceViolation.complianceControl,
      );
      expect(violationSectionComponent.props('complianceCenterPath')).toBe(complianceCenterPath);
    });

    it('renders the fix suggestion section', () => {
      const fixSuggestionSectionComponent = findFixSuggestionSection();
      expect(fixSuggestionSectionComponent.exists()).toBe(true);
      expect(fixSuggestionSectionComponent.props('controlId')).toBe(
        mockComplianceViolation.complianceControl.name,
      );
      expect(fixSuggestionSectionComponent.props('projectPath')).toBe(
        mockComplianceViolation.project.webUrl,
      );
    });

    it('renders the related issues section', () => {
      const relatedIssuesComponent = findRelatedIssues();
      expect(relatedIssuesComponent.exists()).toBe(true);
      expect(relatedIssuesComponent.props('issues')).toEqual(mockComplianceViolation.issues.nodes);
    });

    describe('when violation has an audit event', () => {
      it('renders the audit event component with correct props', () => {
        const auditEventComponent = findAuditEvent();
        expect(auditEventComponent.exists()).toBe(true);
        expect(auditEventComponent.props('auditEvent')).toEqual(mockComplianceViolation.auditEvent);
      });
    });

    describe('when violation does not have an audit event', () => {
      it('does not render the audit event component', async () => {
        createComponent({
          mockQueryHandler: jest.fn().mockResolvedValue(mockDataWithoutAuditEvent),
        });
        await waitForPromises();
        await nextTick();

        const auditEventComponent = findAuditEvent();
        expect(auditEventComponent.exists()).toBe(false);
      });
    });
  });

  describe('notes section', () => {
    describe('when violation has notes', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
        await nextTick();
      });

      it('renders the activity section', () => {
        expect(findActivitySection().exists()).toBe(true);
      });

      it('displays the activity header', () => {
        expect(findActivityHeader().text()).toBe('Activity');
      });

      it('renders both system notes and discussions', () => {
        const systemNotes = findSystemNotes();
        const discussions = findDiscussions();

        expect(systemNotes).toHaveLength(1);
        expect(discussions).toHaveLength(1);
      });

      it('renders system notes with correct props', () => {
        const systemNotes = findSystemNotes();
        const systemNotesData = mockComplianceViolation.discussions.nodes
          .filter((discussion) => discussion.notes.nodes[0].system)
          .map((discussion) => discussion.notes.nodes[0]);

        systemNotes.wrappers.forEach((noteWrapper, index) => {
          expect(noteWrapper.props('note')).toEqual(systemNotesData[index]);
        });
      });

      it('renders discussions with correct props', () => {
        const discussions = findDiscussions();
        const discussionData = mockComplianceViolation.discussions.nodes.filter(
          (discussion) => !discussion.notes.nodes[0].system,
        );

        discussions.wrappers.forEach((discussionWrapper, index) => {
          expect(discussionWrapper.props('discussion')).toEqual(discussionData[index]);
          expect(discussionWrapper.props('violationId')).toBe(
            `gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/${violationId}`,
          );
        });
      });

      it('renders notes in a timeline list', () => {
        const timeline = wrapper.find('.timeline.main-notes-list.notes');
        expect(timeline.exists()).toBe(true);
      });
    });

    describe('when violation has only non-system notes', () => {
      beforeEach(async () => {
        createComponent({
          mockQueryHandler: jest.fn().mockResolvedValue(mockDataWithOnlyNonSystemNotes),
        });
        await waitForPromises();
        await nextTick();
      });

      it('renders the activity section when there are discussion notes', () => {
        expect(findActivitySection().exists()).toBe(true);
      });

      it('does not render any system notes', () => {
        expect(findSystemNotes()).toHaveLength(0);
      });

      it('renders discussions', () => {
        expect(findDiscussions()).toHaveLength(2);
      });
    });

    describe('when violation has no notes', () => {
      beforeEach(async () => {
        createComponent({
          mockQueryHandler: jest.fn().mockResolvedValue(mockDataWithoutNotes),
        });
        await waitForPromises();
        await nextTick();
      });

      it('does not render the activity section', () => {
        expect(findActivitySection().exists()).toBe(false);
      });

      it('does not render any system notes', () => {
        expect(findSystemNotes()).toHaveLength(0);
      });
    });

    describe('when violation notes is null', () => {
      beforeEach(async () => {
        createComponent({
          mockQueryHandler: jest.fn().mockResolvedValue(mockDataWithNullNotes),
        });
        await waitForPromises();
        await nextTick();
      });

      it('does not render the activity section', () => {
        expect(findActivitySection().exists()).toBe(false);
      });
    });
  });

  describe('status update', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      await nextTick();
    });

    it('calls mutation when status is changed', async () => {
      findStatusDropdown().vm.$emit('change', 'resolved');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          id: `gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/${violationId}`,
          status: 'RESOLVED',
        },
      });
    });

    it('sets loading state during status update', async () => {
      const dropdown = findStatusDropdown();
      dropdown.vm.$emit('change', 'resolved');
      await nextTick();

      expect(dropdown.props('loading')).toBe(true);

      await waitForPromises();

      expect(dropdown.props('loading')).toBe(false);
    });

    describe('error handling', () => {
      beforeEach(async () => {
        createComponent({
          mockMutationHandler: jest.fn().mockRejectedValue(new Error('Mutation error')),
        });

        const mockToast = { show: jest.fn() };
        wrapper.vm.$toast = mockToast;

        await waitForPromises();
        await nextTick();
      });

      it('shows error toast when mutation fails', async () => {
        findStatusDropdown().vm.$emit('change', 'resolved');
        await waitForPromises();

        expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
          'Failed to update compliance violation status. Please try again later.',
          { variant: 'danger' },
        );
      });

      it('resets loading state even when mutation fails', async () => {
        const dropdown = findStatusDropdown();

        dropdown.vm.$emit('change', 'resolved');

        await nextTick();
        expect(dropdown.props('loading')).toBe(true);

        await waitForPromises();
        expect(dropdown.props('loading')).toBe(false);
      });
    });
  });

  describe('comment form', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      await nextTick();
    });

    it('renders the comment form with correct props', () => {
      const commentForm = findCommentForm();
      expect(commentForm.exists()).toBe(true);
    });

    it('shows error toast when comment form emits error event', async () => {
      const mockToast = { show: jest.fn() };
      wrapper.vm.$toast = mockToast;

      const errorMessage = 'Failed to submit comment';
      const commentForm = findCommentForm();

      commentForm.vm.$emit('error', errorMessage);
      await nextTick();

      expect(mockToast.show).toHaveBeenCalledWith(errorMessage, {
        variant: 'danger',
      });
    });

    it('shows error toast when discussion emits error event', async () => {
      const mockToast = { show: jest.fn() };
      wrapper.vm.$toast = mockToast;

      const errorMessage = 'Failed to perform action';
      const discussion = findDiscussions().at(0);

      discussion.vm.$emit('error', errorMessage);
      await nextTick();

      expect(mockToast.show).toHaveBeenCalledWith(errorMessage, {
        variant: 'danger',
      });
    });
  });
});
