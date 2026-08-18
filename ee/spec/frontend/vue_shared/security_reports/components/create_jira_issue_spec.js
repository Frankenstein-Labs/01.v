import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import CreateJiraIssue from 'ee/vue_shared/security_reports/components/create_jira_issue.vue';
import vulnerabilityExternalIssueLinkCreate from 'ee/vue_shared/security_reports/graphql/vulnerability_external_issue_link_create.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { vulnerabilityExternalIssueLinkCreateMockFactory } from './apollo_mocks';

describe('create_jira_issue', () => {
  let wrapper;

  const defaultProps = {
    vulnerabilityId: 1,
  };

  const findButton = () => wrapper.findComponent(GlButton);

  const successHandler = jest
    .fn()
    .mockResolvedValue(vulnerabilityExternalIssueLinkCreateMockFactory());
  const errorHandler = jest.fn().mockResolvedValue(
    vulnerabilityExternalIssueLinkCreateMockFactory({
      errors: ['foo'],
    }),
  );
  const pendingHandler = jest.fn().mockReturnValue(new Promise(() => {}));

  function createMockApolloProvider(handler) {
    Vue.use(VueApollo);
    const requestHandlers = [[vulnerabilityExternalIssueLinkCreate, handler]];
    return createMockApollo(requestHandlers);
  }

  const createComponent = (options = {}) => {
    wrapper = shallowMount(CreateJiraIssue, {
      apolloProvider: options.mockApollo,
      propsData: {
        ...defaultProps,
        ...options.propsData,
      },
      provide: {
        ...options.provide,
      },
    });
  };

  describe('create jira issue button', () => {
    const clickButton = () => {
      findButton().vm.$emit('click');
      return waitForPromises();
    };

    it.each`
      createJiraIssueUrl      | customizeJiraIssueEnabled
      ${''}                   | ${false}
      ${'/create-jira-issue'} | ${false}
      ${''}                   | ${true}
    `(
      'renders create jira issue button when createJiraIssueUrl is $createJiraIssueUrl and customizeJiraIssueEnabled is $customizeJiraIssueEnabled',
      ({ createJiraIssueUrl, customizeJiraIssueEnabled }) => {
        createComponent({ provide: { createJiraIssueUrl, customizeJiraIssueEnabled } });

        // if href is not set it's the create jira issue button
        expect(findButton().props('href')).toBeUndefined();
      },
    );

    it('should render button with correct text and props', () => {
      createComponent();

      expect(findButton().text()).toBe('Create Jira issue');
      expect(findButton().props()).toMatchObject({
        variant: 'confirm',
        category: 'secondary',
      });
    });

    it.each`
      description                | propsData            | expectedSize
      ${'defaults to medium'}    | ${{}}                | ${'medium'}
      ${'forwards a small size'} | ${{ size: 'small' }} | ${'small'}
    `('$description', ({ propsData, expectedSize }) => {
      createComponent({ propsData });

      expect(findButton().props('size')).toBe(expectedSize);
    });

    describe('given a pending response', () => {
      beforeEach(() => {
        const mockApollo = createMockApolloProvider(pendingHandler);
        createComponent({ mockApollo });
      });

      it('renders spinner correctly', async () => {
        const button = findButton();
        expect(button.props('loading')).toBe(false);
        await clickButton();
        expect(button.props('loading')).toBe(true);
      });
    });

    describe('given an error response', () => {
      beforeEach(async () => {
        const mockApollo = createMockApolloProvider(errorHandler);
        createComponent({ mockApollo });
        await clickButton();
      });

      it('show throw createJiraIssueError event with correct message', () => {
        expect(wrapper.emitted('create-jira-issue-error')).toEqual([['foo']]);
      });
    });

    describe('given an successful response', () => {
      beforeEach(async () => {
        const mockApollo = createMockApolloProvider(successHandler);
        createComponent({ mockApollo });
        await clickButton();
      });

      it('should emit mutated event', () => {
        expect(wrapper.emitted('mutated')).not.toBe(undefined);
      });
    });
  });

  describe('customize jira issue button', () => {
    beforeEach(() => {
      createComponent({
        provide: { createJiraIssueUrl: '/create-jira-issue', customizeJiraIssueEnabled: true },
      });
    });

    it('renders customize jira issue button when createJiraIssueUrl is given and customizeJiraIssueEnabled is true', () => {
      // if href is set, it's the customize jira issue button
      expect(findButton().attributes('href')).toBe('/create-jira-issue');
    });

    it('should render button with correct text and props', () => {
      expect(findButton().text()).toBe('Create Jira issue');
      expect(findButton().props()).toMatchObject({
        variant: 'confirm',
        category: 'secondary',
        icon: 'external-link',
        target: '_blank',
      });
    });
  });
});
