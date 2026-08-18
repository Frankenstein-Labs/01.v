import { GlAlert, GlCollapsibleListbox, GlFormCheckbox, GlFormInput } from '@gitlab/ui';
import { within } from '@testing-library/dom';
import Vue, { nextTick } from 'vue';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import JiraIssueCreationVulnerabilities, {
  i18n,
} from 'ee/integrations/edit/components/jira_issue_creation_vulnerabilities.vue';
import { useIntegrationForm } from '~/integrations/edit/store';

Vue.use(PiniaVuePlugin);

describe('JiraIssueCreationVulnerabilities', () => {
  let store;
  let wrapper;

  const defaultProps = {
    initialIssueTypeId: '10000',
  };

  const TEST_JIRA_ISSUE_TYPES = [
    { id: '1', name: 'issue', description: 'issue' },
    { id: '2', name: 'bug', description: 'bug' },
    { id: '3', name: 'epic', description: 'epic' },
  ];

  const createComponent =
    (mountFn) =>
    ({ isInheriting = false, props = {} } = {}) => {
      const pinia = createTestingPinia({ stubActions: false });
      store = useIntegrationForm();
      Object.assign(store, {
        defaultState: isInheriting ? {} : null,
        override: !isInheriting,
      });

      return mountFn(JiraIssueCreationVulnerabilities, {
        pinia,
        propsData: { ...defaultProps, ...props },
      });
    };

  const createShallowComponent = createComponent(shallowMountExtended);
  const createFullComponent = createComponent(mountExtended);

  const withinComponent = () => within(wrapper.element);
  const findHiddenInput = (name) => wrapper.find(`input[name="service[${name}]"]`);
  const findEnableJiraVulnerabilities = () => wrapper.findAllComponents(GlFormCheckbox).at(0);
  const findIssueTypeSection = () => wrapper.findByTestId('issue-type-section');
  const findIssueTypeListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findIssueTypeLabel = () => wrapper.find('label');
  const findProjectKey = () => wrapper.findByTestId('jira-project-key');
  const findProjectKeyInput = () => findProjectKey().findComponent(GlFormInput);
  const findFetchIssueTypeButton = () =>
    wrapper.findComponentByTestId('jira-issue-types-fetch-retry-button');
  const findCustomizeJiraIssueCheckbox = () => wrapper.findAllComponents(GlFormCheckbox).at(1);
  const findFetchErrorAlert = () => wrapper.findComponent(GlAlert);
  const setEnableJiraVulnerabilitiesChecked = (isChecked) =>
    findEnableJiraVulnerabilities().vm.$emit('input', isChecked);
  const setCustomizeJiraIssueEnabled = (isChecked) =>
    findCustomizeJiraIssueCheckbox().vm.$emit('input', isChecked);

  describe('content', () => {
    beforeEach(() => {
      wrapper = createFullComponent();
    });

    it('contains a heading', () => {
      expect(withinComponent().getByText(i18n.checkbox.label)).not.toBe(null);
    });

    it('contains a more detailed description', () => {
      expect(withinComponent().getByText(i18n.checkbox.description)).not.toBe(null);
    });

    describe('when Jira issue creation is enabled', () => {
      beforeEach(async () => {
        await setEnableJiraVulnerabilitiesChecked(true);
      });

      it('shows a reason why the issue type is needed', () => {
        expect(withinComponent().getByText(i18n.issueTypeSelect.description)).not.toBe(null);
      });
    });
  });

  describe('"Enable Jira issue creation from vulnerabilities" checkbox', () => {
    beforeEach(() => {
      wrapper = createShallowComponent();
    });

    it.each([true, false])(
      'toggles the hidden "vulnerabilities_enabled" input value',
      async (isChecked) => {
        await setEnableJiraVulnerabilitiesChecked(isChecked);

        expect(findHiddenInput('vulnerabilities_enabled').attributes('value')).toBe(`${isChecked}`);
      },
    );

    it.each([true, false])('toggles the Jira issue-type selection section', async (isChecked) => {
      await setEnableJiraVulnerabilitiesChecked(isChecked);
      expect(findIssueTypeSection().exists()).toBe(isChecked);
    });

    describe('when isInheriting = true', () => {
      beforeEach(() => {
        wrapper = createShallowComponent({ isInheriting: true });
      });

      it('disables the checkbox', () => {
        expect(findEnableJiraVulnerabilities().attributes('disabled')).toBeDefined();
      });
    });
  });

  describe('when showFullFeature is off', () => {
    beforeEach(() => {
      wrapper = createShallowComponent({ props: { showFullFeature: false } });
    });

    it('does not show the issue type section', () => {
      expect(findIssueTypeSection().exists()).toBe(false);
    });
  });

  describe('Jira issue type listbox', () => {
    describe('with no Jira issues fetched', () => {
      beforeEach(async () => {
        wrapper = createShallowComponent();
        await setEnableJiraVulnerabilitiesChecked(true);
      });

      it('receives the correct props', () => {
        expect(findIssueTypeListbox().props()).toMatchObject({
          disabled: true,
          loading: false,
          toggleText: i18n.issueTypeSelect.defaultText,
        });
      });

      it('does not contain any listbox items', () => {
        expect(findIssueTypeListbox().props('items')).toHaveLength(0);
      });

      it('sets the correct initial value to a hidden issuetype field', () => {
        expect(findHiddenInput('vulnerabilities_issuetype').attributes('value')).toBe(
          defaultProps.initialIssueTypeId,
        );
      });

      it('renders the label for the issue type listbox', () => {
        expect(findIssueTypeLabel().text()).toBe('Jira issue type');
      });
    });

    describe('with Jira issues fetching in progress', () => {
      beforeEach(async () => {
        wrapper = createShallowComponent();
        store.isLoadingJiraIssueTypes = true;
        await setEnableJiraVulnerabilitiesChecked(true);
      });

      it('receives the correct props', () => {
        expect(findIssueTypeListbox().props()).toMatchObject({
          disabled: true,
          loading: true,
        });
      });
    });

    describe('with Jira issues fetched', () => {
      beforeEach(async () => {
        wrapper = createShallowComponent({ props: { projectKey: 'TES' } });
        store.jiraIssueTypes = TEST_JIRA_ISSUE_TYPES;
        await setEnableJiraVulnerabilitiesChecked(true);
      });

      it('receives the correct props', () => {
        expect(findIssueTypeListbox().props()).toMatchObject({
          disabled: false,
          loading: false,
        });
      });

      it('sets the correct initial value to a hidden issuetype field', () => {
        expect(findHiddenInput('vulnerabilities_issuetype').attributes('value')).toBe(
          defaultProps.initialIssueTypeId,
        );
      });

      it('contains a listbox item for each issue type', () => {
        expect(findIssueTypeListbox().props('items')).toHaveLength(TEST_JIRA_ISSUE_TYPES.length);
      });

      it("doesn't set the initial item if it doesn't exist in the listbox", () => {
        expect(findIssueTypeListbox().props('selected')).toBe(null);
      });

      it('selects the correct item if it exists in the listbox', async () => {
        const defaultIssueType = { id: defaultProps.initialIssueTypeId, name: 'default' };
        store.jiraIssueTypes = [...TEST_JIRA_ISSUE_TYPES, defaultIssueType];
        await nextTick();
        expect(findIssueTypeListbox().props('selected')).toBe(defaultIssueType.id);
        expect(findIssueTypeListbox().props('toggleText')).toBe(defaultIssueType.name);
      });

      it.each(TEST_JIRA_ISSUE_TYPES)(
        'shows the selected issue name and updates the hidden input',
        async (issue) => {
          findIssueTypeListbox().vm.$emit('select', issue.id);
          await nextTick();
          expect(findHiddenInput('vulnerabilities_issuetype').attributes('value')).toBe(issue.id);
          expect(findIssueTypeListbox().props('toggleText')).toBe(issue.name);
        },
      );
    });

    describe('with Jira issue fetch failure', () => {
      beforeEach(async () => {
        wrapper = createShallowComponent();
        store.loadingJiraIssueTypesErrorMessage = 'something went wrong';
        await setEnableJiraVulnerabilitiesChecked(true);
      });

      it('shows an error message', () => {
        expect(findFetchErrorAlert().exists()).toBe(true);
      });
    });
  });

  describe('fetch Jira issue types button', () => {
    beforeEach(async () => {
      wrapper = createShallowComponent({ props: { projectKey: null } });
      await setEnableJiraVulnerabilitiesChecked(true);
    });

    it('has a help text', () => {
      expect(findFetchIssueTypeButton().attributes('title')).toBe(i18n.fetchIssueTypesButtonLabel);
    });

    it('emits "fetch-issues-clicked" when clicked', async () => {
      expect(wrapper.emitted('request-jira-issue-types')).toBe(undefined);
      await findFetchIssueTypeButton().vm.$emit('click');
      expect(wrapper.emitted('request-jira-issue-types')).toHaveLength(1);
    });
  });

  describe('Jira project key input', () => {
    beforeEach(() => {
      wrapper = createShallowComponent({
        props: {
          initialIsEnabled: true,
        },
      });
    });

    it('renders "Jira project key" input', () => {
      expect(findProjectKey().attributes('label')).toBe('Jira project key');
      expect(findProjectKeyInput().attributes('required')).toBe('true');
    });

    describe('when "Jira project key" is empty', () => {
      it('shows a warning message telling the user to enter a valid project key', () => {
        expect(wrapper.text()).toContain('Enter a Jira project key to generate issue types.');
      });
    });

    describe('when "Jira project key" is not empty, then is changed after fetching issue types', () => {
      beforeEach(() => {
        wrapper = createShallowComponent({
          props: {
            initialIsEnabled: true,
            initialProjectKey: 'INITIAL',
          },
        });
        findFetchIssueTypeButton().vm.$emit('click');

        findProjectKeyInput().vm.$emit('input', 'CHANGED');
      });

      it('shows a warning message telling the user to refetch the issues list', () => {
        expect(wrapper.text()).toContain('Fetch issue types again for the new project key.');
      });
    });
  });

  describe('Customize Jira issue checkbox', () => {
    it.each([true, false])(
      'sets the hidden "customize_jira_issue_enabled" input value to: "%s"',
      async (isChecked) => {
        wrapper = createShallowComponent();
        await setEnableJiraVulnerabilitiesChecked(true);
        await setCustomizeJiraIssueEnabled(isChecked);
        expect(findHiddenInput('customize_jira_issue_enabled').attributes('value')).toBe(
          `${isChecked}`,
        );
      },
    );

    it('renders a label and description', async () => {
      wrapper = createFullComponent();
      await setEnableJiraVulnerabilitiesChecked(true);
      expect(findCustomizeJiraIssueCheckbox().text()).toMatchInterpolatedText(
        'Customize Jira issues Navigate to Jira issue before issue is created.',
      );
    });
  });
});
